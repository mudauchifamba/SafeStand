import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../config.dart';
import '../services/land_context_service.dart';
import '../services/photo_evidence_service.dart';
import '../services/pin_parser.dart';
import '../services/remote_check_service.dart';
import '../services/risk_scorer.dart';
import '../widgets/satellite_view.dart';
import 'result_screen.dart';

/// The diaspora flow: "I'm abroad, the seller sent me photos of my stand —
/// is this deal real?" Checks the seller's photos' embedded location and
/// date against the claimed area, shows satellite imagery of the claimed
/// spot, and scores the claimed area against documented fraud patterns.
class RemoteCheckScreen extends StatefulWidget {
  final RiskScorer scorer;

  const RemoteCheckScreen({super.key, required this.scorer});

  @override
  State<RemoteCheckScreen> createState() => _RemoteCheckScreenState();
}

class _RemoteCheckScreenState extends State<RemoteCheckScreen> {
  final _picker = ImagePicker();
  final _photoService = PhotoEvidenceService();
  final _areaController = TextEditingController();
  final _sellerController = TextEditingController();
  final _pinController = TextEditingController();

  final _landService = LandContextService();

  List<GazetteerPlace> _places = [];
  final List<PhotoEvidence> _photos = [];
  bool _busy = false;
  bool _analyzing = false;
  LandContext? _land;
  String? _landTargetKey; // coordinates the current _land result is for

  @override
  void initState() {
    super.initState();
    _photoService.loadGazetteer().then((p) {
      if (mounted) setState(() => _places = p);
    });
  }

  @override
  void dispose() {
    _areaController.dispose();
    _sellerController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  (double, double)? get _pin => PinParser.parse(_pinController.text);

  GazetteerPlace? get _claimedPlace =>
      _photoService.matchPlace(_areaController.text, _places);

  /// The point the AI should analyse: the seller's pin if given, else the
  /// claimed suburb centre.
  (double, double)? get _analysisTarget {
    final pin = _pin;
    if (pin != null) return pin;
    final place = _claimedPlace;
    if (place != null) return (place.lat, place.lon);
    return null;
  }

  Future<void> _analyzeLand() async {
    final target = _analysisTarget;
    if (target == null) return;
    setState(() => _analyzing = true);
    final result = await _landService.analyze(target.$1, target.$2);
    if (!mounted) return;
    setState(() {
      _analyzing = false;
      _land = result;
      _landTargetKey = '${target.$1},${target.$2}';
    });
  }

  Future<void> _addPhotos() async {
    setState(() => _busy = true);
    try {
      final picked = await _picker.pickMultiImage();
      for (final f in picked) {
        final ev = await _photoService.readPhoto(f.path);
        _photos.add(ev);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _check() {
    final area = _areaController.text.trim();
    if (area.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enter the area the seller claims the stand is in.')));
      return;
    }

    final results = _photos
        .map((ev) => _photoService.check(
              evidence: ev,
              claimedArea: area,
              places: _places,
            ))
        .toList();

    final pin = _pin;
    // Only feed the AI result in if it belongs to the point we're checking.
    final target = _analysisTarget;
    final landIsCurrent = _land != null &&
        target != null &&
        _landTargetKey == '${target.$1},${target.$2}';

    final verdict = RemoteCheckService(scorer: widget.scorer).evaluate(
      claimedArea: area,
      seller: _sellerController.text,
      photoResults: results,
      pinLat: pin?.$1,
      pinLon: pin?.$2,
      claimedPlace: _claimedPlace,
      landContext: landIsCurrent ? _land : null,
    );

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ResultScreen(verdict: verdict, area: area),
    ));
  }

  Widget _buildLandAiSection(BuildContext context) {
    if (!Config.hasGeminiKey) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'AI land analysis is not configured in this build. The offline '
          'checks above still work. (Add a Gemini API key to enable an AI '
          'reading of the satellite image.)',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    final land = _land;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: _analyzing ? null : _analyzeLand,
          icon: _analyzing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.auto_awesome_outlined),
          label: Text(_analyzing
              ? 'Analysing satellite image…'
              : land == null
                  ? 'Analyse this location with AI'
                  : 'Re-analyse with AI'),
        ),
        if (land != null) ...[
          const SizedBox(height: 12),
          if (!land.available)
            Text(
              'AI analysis could not be completed (${land.error}). '
              'Check your internet connection and try again.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            )
          else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: land.landClass == LandClass.waterOrWetland ||
                        land.landClass == LandClass.builtUpDense
                    ? Theme.of(context).colorScheme.errorContainer
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('AI reading: ${land.landClass.label}',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600)),
                      ),
                      Text('(${land.confidence} confidence)',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  if (land.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(land.description),
                  ],
                ],
              ),
            ),
        ],
        const SizedBox(height: 6),
        Text(
          'AI reads free, low-detail satellite imagery — treat it as a second '
          'opinion to compare with what the seller told you, not as proof.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final place = _claimedPlace;

    return Scaffold(
      appBar: AppBar(title: const Text('Check a stand remotely')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Buying from abroad? Enter the area the seller claims, and add '
              'the photos they sent you. We check where and when those photos '
              'were really taken — and show you the claimed spot from '
              'satellite.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _areaController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Claimed area / suburb',
                hintText: 'e.g. Glen View, Harare',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _sellerController,
              decoration: const InputDecoration(
                labelText: 'Seller / cooperative name (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pinController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Seller\'s location pin (optional)',
                hintText: '-17.9123, 30.9876 or a Google Maps link',
                helperText: PinParser.isShortLink(_pinController.text)
                    ? 'Short links can\'t be read here — open it in Maps, '
                        'copy the coordinates, and paste them instead.'
                    : 'Ask the seller to share the stand\'s location pin on '
                        'WhatsApp, then paste it here.',
                helperMaxLines: 3,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _busy ? null : _addPhotos,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(_photos.isEmpty
                  ? 'Add the seller\'s photos'
                  : 'Add more photos (${_photos.length} added)'),
            ),
            if (_busy) ...[
              const SizedBox(height: 12),
              const Center(child: CircularProgressIndicator()),
            ],
            if (_photos.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 90,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final p in _photos)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(File(p.path),
                                  width: 90, height: 90, fit: BoxFit.cover),
                            ),
                            Positioned(
                              right: 2,
                              top: 2,
                              child: Icon(
                                p.hasGps
                                    ? Icons.location_on
                                    : Icons.location_off,
                                size: 18,
                                color: p.hasGps
                                    ? Colors.lightGreenAccent
                                    : Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tip: WhatsApp removes location data from photos sent the '
                'normal way. Ask the seller to send them "as a document" '
                '(attach > Document) so the location survives.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (_pin != null) ...[
              const SizedBox(height: 20),
              Text('Satellite view of the seller\'s pin',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SatelliteView(
                lat: _pin!.$1,
                lon: _pin!.$2,
                zoom: 17,
                caption: 'This is the exact spot the seller pinned as your '
                    'stand. Does it match what they described — vacant land, '
                    'or something else?',
              ),
            ] else if (place != null) ...[
              const SizedBox(height: 20),
              Text('Satellite view of ${place.name}',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SatelliteView(
                lat: place.lat,
                lon: place.lon,
                caption:
                    'General view of ${place.name}, ${place.city} — the '
                    'suburb centre, NOT the specific stand. Paste the '
                    'seller\'s pin above to see the exact spot.',
              ),
            ],
            for (final p in _photos.where((p) => p.hasGps)) ...[
              const SizedBox(height: 20),
              Text('Where a seller photo was really taken',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SatelliteView(
                lat: p.lat!,
                lon: p.lon!,
                zoom: 17,
                caption: 'Location embedded in one of the photos you added. '
                    'It should agree with the pin and the claimed area.',
              ),
            ],
            if (_analysisTarget != null) ...[
              const SizedBox(height: 20),
              _buildLandAiSection(context),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _check,
              icon: const Icon(Icons.shield_outlined),
              label: const Text('Check this deal'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'A location match never proves a deal is safe — photo location '
              'data is easy to fake. Only contradictions raise the alarm.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
