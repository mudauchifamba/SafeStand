import 'dart:convert';
import 'dart:io';
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
  final String wetlandSigns; // none | possible | strong
  final bool available; // false when no key / offline / call failed
  final String? error;

  LandContext({
    required this.landClass,
    required this.confidence,
    required this.description,
    this.wetlandSigns = 'none',
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

/// AI judgment on the seller's photos themselves — deliberately BLIND: the
/// model never sees the satellite imagery or the pin, so its testimony about
/// the photos is independent. The app (not a model) then cross-examines this
/// against the separate satellite reading. Metadata can be stripped in
/// transit; pixels cannot.
class PhotoContentAnalysis {
  final String photosShow; // plain-language: what the photos depict
  final LandClass terrainClass; // terrain visible in the photos
  final String authenticity; // ok | suspicious | strong_concerns
  final String authenticityReasons;
  final bool available;
  final String? error;

  PhotoContentAnalysis({
    required this.photosShow,
    required this.terrainClass,
    required this.authenticity,
    required this.authenticityReasons,
    this.available = true,
    this.error,
  });

  factory PhotoContentAnalysis.unavailable(String why) => PhotoContentAnalysis(
        photosShow: '',
        terrainClass: LandClass.unknown,
        authenticity: 'ok',
        authenticityReasons: '',
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
      'You are looking at satellite/aerial imagery of ONE location in '
      'Zimbabwe, being checked by someone deciding whether to buy a '
      'residential stand there. Image 1 is a close-up (~150 m across); '
      'Image 2 is the same centre point zoomed out (~1.2 km across) for '
      'context. Classify the DOMINANT land cover at the CENTRE of Image 1 '
      'into exactly one of: built_up_dense, built_up_scattered, bare_land, '
      'vegetation, water_or_wetland. '
      'IMPORTANT: reservoir and lake water in Zimbabwe is often GREEN from '
      'algae, not blue. A smooth, uniform, texture-less green or dark '
      'surface with no tree crowns, no roads and no shadows is almost '
      'certainly WATER - check Image 2 for a shoreline to confirm. '
      'ALSO check for SEASONAL WETLAND (vlei) indicators - in Harare these '
      'are grassy areas that look dry and buildable but flood seasonally '
      'and get houses demolished. Indicators: visible water, marsh or reed '
      'texture (strong); a dark meandering drainage channel; an undeveloped '
      'green/grass corridor cutting through otherwise built-up land; land '
      'noticeably darker or greener than its surroundings (possible). '
      'Reply ONLY with compact JSON: '
      '{"class":"<one of the above>","confidence":"high|medium|low",'
      '"wetland_signs":"none|possible|strong",'
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
      // 1. Fetch a close-up tile plus a zoomed-out tile of the same point —
      // the wide view gives the model shoreline/settlement context that a
      // single uniform close-up (e.g. green algae-rich water) lacks.
      final closeResp =
          await _client.get(Uri.parse(tileUrl(lat, lon, zoom))).timeout(
                const Duration(seconds: 20),
              );
      if (closeResp.statusCode != 200 || closeResp.bodyBytes.isEmpty) {
        return LandContext.unavailable('tile_fetch_failed');
      }
      final wideResp = await _client
          .get(Uri.parse(tileUrl(lat, lon, zoom - 3)))
          .timeout(const Duration(seconds: 20));
      final mime = closeResp.headers['content-type'] ?? 'image/jpeg';
      final b64Close = base64Encode(closeResp.bodyBytes);
      final b64Wide = wideResp.statusCode == 200 && wideResp.bodyBytes.isNotEmpty
          ? base64Encode(wideResp.bodyBytes)
          : null;

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
                'image_url': {'url': 'data:$mime;base64,$b64Close'}
              },
              if (b64Wide != null)
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:$mime;base64,$b64Wide'}
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

  static const _photoPrompt =
      'You are helping someone abroad decide whether a land deal in Zimbabwe '
      'is real. The seller\'s claim: "{claim}". '
      'The {n} image(s) are photos the seller sent, claiming they show the '
      'stand being sold. Judge three things from the photos ALONE. '
      '(1) What do they actually show - one short sentence. '
      '(2) The DOMINANT terrain/setting visible: built_up_dense, '
      'built_up_scattered, bare_land, vegetation, water_or_wetland - or '
      'unknown if no outdoor terrain is visible. '
      '(3) Authenticity: signs of recycled or fake photos - phone/app UI '
      'bars (screenshots), watermarks or listing-site logos, architectural '
      'renders, terrain or architecture implausible for Zimbabwe. '
      'Reply ONLY with compact JSON: '
      '{"photos_show":"one short sentence",'
      '"terrain_class":"<one of the above or unknown>",'
      '"authenticity":"ok|suspicious|strong_concerns",'
      '"authenticity_reasons":"short sentence, empty if ok"}.';

  /// Analyse up to 3 seller photos BLIND — no satellite imagery attached,
  /// so this testimony is independent of the satellite reading and the app
  /// can cross-examine the two afterwards.
  Future<PhotoContentAnalysis> analyzePhotos({
    required List<String> photoPaths,
    required String claim,
  }) async {
    if (!Config.hasGroqKey) {
      return PhotoContentAnalysis.unavailable('no_api_key');
    }
    if (photoPaths.isEmpty) {
      return PhotoContentAnalysis.unavailable('no_photos');
    }

    try {
      final images = <Map<String, dynamic>>[];
      final paths = photoPaths.take(3).toList();
      for (final p in paths) {
        final bytes = await File(p).readAsBytes();
        images.add({
          'type': 'image_url',
          'image_url': {'url': 'data:image/jpeg;base64,${base64Encode(bytes)}'}
        });
      }

      final prompt = _photoPrompt
          .replaceAll('{claim}', claim)
          .replaceAll('{n}', '${paths.length}');

      final url =
          Uri.parse('https://api.groq.com/openai/v1/chat/completions');
      final body = jsonEncode({
        'model': Config.groqVisionModel,
        'temperature': 0.0,
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': prompt},
              ...images,
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
          .timeout(const Duration(seconds: 60));

      if (resp.statusCode != 200) {
        return PhotoContentAnalysis.unavailable(
            'api_error_${resp.statusCode}: ${_apiErrorReason(resp.body)}');
      }

      final text = _extractText(jsonDecode(resp.body) as Map<String, dynamic>);
      if (text == null) return PhotoContentAnalysis.unavailable('empty_response');

      final match = RegExp(r'\{.*\}', dotAll: true).firstMatch(text);
      if (match == null) return PhotoContentAnalysis.unavailable('unparseable');
      final j = jsonDecode(match.group(0)!) as Map<String, dynamic>;

      String pick(String key, Set<String> allowed, String fallback) {
        final v = (j[key]?.toString() ?? '').toLowerCase().trim();
        return allowed.contains(v) ? v : fallback;
      }

      return PhotoContentAnalysis(
        photosShow: j['photos_show']?.toString() ?? '',
        terrainClass: _classFrom(j['terrain_class']?.toString() ?? ''),
        authenticity: pick('authenticity',
            {'ok', 'suspicious', 'strong_concerns'}, 'ok'),
        authenticityReasons: j['authenticity_reasons']?.toString() ?? '',
      );
    } catch (e) {
      return PhotoContentAnalysis.unavailable('exception');
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
      final signs = (j['wetland_signs']?.toString() ?? 'none').toLowerCase();
      return LandContext(
        landClass: _classFrom(j['class']?.toString() ?? ''),
        confidence: (j['confidence']?.toString() ?? 'low').toLowerCase(),
        description: j['description']?.toString() ?? '',
        wetlandSigns: const {'possible', 'strong'}.contains(signs)
            ? signs
            : 'none',
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
