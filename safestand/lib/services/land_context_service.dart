import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../config.dart';

/// Broad land classes we ask the vision model to choose from. Deliberately
/// coarse — free/AI satellite reading is context, not survey-grade truth.
enum LandClass {
  builtUpDense,
  builtUpScattered,
  bareLand,
  vegetation,
  waterOrWetland,
  unknown,
}

extension LandClassLabel on LandClass {
  String get label {
    switch (this) {
      case LandClass.builtUpDense:
        return 'Densely built-up';
      case LandClass.builtUpScattered:
        return 'Scattered structures';
      case LandClass.bareLand:
        return 'Bare / cleared land';
      case LandClass.vegetation:
        return 'Vegetation / bush / fields';
      case LandClass.waterOrWetland:
        return 'Water or wetland';
      case LandClass.unknown:
        return 'Unclear';
    }
  }
}

/// Result of asking the vision model what a location looks like from above.
class LandContext {
  final LandClass landClass;
  final String confidence; // high | medium | low
  final String description; // model's plain-language note
  final bool available; // false when no key / offline / call failed
  final String? error;

  LandContext({
    required this.landClass,
    required this.confidence,
    required this.description,
    this.available = true,
    this.error,
  });

  factory LandContext.unavailable(String why) => LandContext(
        landClass: LandClass.unknown,
        confidence: 'low',
        description: '',
        available: false,
        error: why,
      );
}

/// Sends the satellite tile at a coordinate to a vision LLM (via Groq) and
/// asks it to classify the land. This is the app's one online AI step; it
/// augments — never replaces — the offline checks, and its output is scored
/// conservatively (only water/wetland and dense build-up move the needle).
class LandContextService {
  final http.Client _client;
  LandContextService({http.Client? client}) : _client = client ?? http.Client();

  static const _prompt =
      'You are looking at a satellite/aerial image tile of a location in '
      'Zimbabwe, being checked by someone deciding whether to buy a '
      'residential stand there. Classify the DOMINANT land cover in the '
      'centre of the image into exactly one of: built_up_dense, '
      'built_up_scattered, bare_land, vegetation, water_or_wetland. '
      'Reply ONLY with compact JSON: '
      '{"class":"<one of the above>","confidence":"high|medium|low",'
      '"description":"one short sentence a home-buyer would understand"}.';

  /// Esri World Imagery tile URL for a coordinate at [zoom].
  static String tileUrl(double lat, double lon, int zoom) {
    final n = 1 << zoom;
    final x = ((lon + 180) / 360 * n).floor().clamp(0, n - 1);
    final latRad = lat * math.pi / 180;
    final y =
        ((1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) /
                2 *
                n)
            .floor()
            .clamp(0, n - 1);
    return 'https://server.arcgisonline.com/ArcGIS/rest/services/'
        'World_Imagery/MapServer/tile/$zoom/$y/$x';
  }

  Future<LandContext> analyze(double lat, double lon, {int zoom = 17}) async {
    if (!Config.hasGroqKey) {
      return LandContext.unavailable('no_api_key');
    }

    try {
      // 1. Fetch the satellite tile bytes.
      final tileResp =
          await _client.get(Uri.parse(tileUrl(lat, lon, zoom))).timeout(
                const Duration(seconds: 20),
              );
      if (tileResp.statusCode != 200 || tileResp.bodyBytes.isEmpty) {
        return LandContext.unavailable('tile_fetch_failed');
      }
      final mime = tileResp.headers['content-type'] ?? 'image/jpeg';
      final b64 = base64Encode(tileResp.bodyBytes);

      // 2. Ask the Groq-hosted vision model to classify it. Groq exposes an
      // OpenAI-compatible chat completions endpoint.
      final url =
          Uri.parse('https://api.groq.com/openai/v1/chat/completions');
      final body = jsonEncode({
        'model': Config.groqVisionModel,
        'temperature': 0.0,
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': _prompt},
              {
                'type': 'image_url',
                'image_url': {'url': 'data:$mime;base64,$b64'}
              }
            ]
          }
        ]
      });

      final resp = await _client
          .post(url,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ${Config.groqApiKey}',
              },
              body: body)
          .timeout(const Duration(seconds: 30));

      if (resp.statusCode != 200) {
        return LandContext.unavailable(
            'api_error_${resp.statusCode}: ${_apiErrorReason(resp.body)}');
      }

      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final text = _extractText(json);
      if (text == null) return LandContext.unavailable('empty_response');

      return _parse(text);
    } catch (e) {
      return LandContext.unavailable('exception');
    }
  }

  /// Pulls the human-readable reason out of a Groq/OpenAI-style error
  /// response so the UI can tell the user what actually went wrong instead
  /// of a generic failure.
  String _apiErrorReason(String body) {
    try {
      final j = jsonDecode(body) as Map<String, dynamic>;
      final err = j['error'] as Map<String, dynamic>?;
      final type = err?['type']?.toString();
      final message = err?['message']?.toString();
      return [type, message]
          .where((s) => s != null && s.isNotEmpty)
          .join(' — ');
    } catch (_) {
      final snippet = body.replaceAll('\n', ' ').trim();
      return snippet.length > 160 ? '${snippet.substring(0, 160)}…' : snippet;
    }
  }

  String? _extractText(Map<String, dynamic> json) {
    try {
      final choices = json['choices'] as List?;
      if (choices == null || choices.isEmpty) return null;
      final content = choices.first['message']?['content'];
      if (content is String && content.trim().isNotEmpty) return content;
    } catch (_) {}
    return null;
  }

  LandContext _parse(String modelText) {
    // Model may wrap JSON in ```json fences; grab the first {...} block.
    final match = RegExp(r'\{.*\}', dotAll: true).firstMatch(modelText);
    if (match == null) return LandContext.unavailable('unparseable');
    try {
      final j = jsonDecode(match.group(0)!) as Map<String, dynamic>;
      return LandContext(
        landClass: _classFrom(j['class']?.toString() ?? ''),
        confidence: (j['confidence']?.toString() ?? 'low').toLowerCase(),
        description: j['description']?.toString() ?? '',
      );
    } catch (_) {
      return LandContext.unavailable('unparseable');
    }
  }

  static LandClass _classFrom(String s) {
    switch (s.trim().toLowerCase()) {
      case 'built_up_dense':
        return LandClass.builtUpDense;
      case 'built_up_scattered':
        return LandClass.builtUpScattered;
      case 'bare_land':
        return LandClass.bareLand;
      case 'vegetation':
        return LandClass.vegetation;
      case 'water_or_wetland':
        return LandClass.waterOrWetland;
      default:
        return LandClass.unknown;
    }
  }
}
