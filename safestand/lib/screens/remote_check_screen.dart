import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../config.dart';
import '../services/land_context_service.dart';
import '../services/photo_evidence_service.dart';
import '../services/pin_parser.dart';
import '../services/remote_check_service.dart';
import '../services/risk_scorer.dart';
import '../services/wetland_service.dart';
import '../widgets/ai_scan_overlay.dart';
import '../widgets/satellite_view.dart';
import 'result_screen.dart';

/// The unified "check a stand" flow. Works with as little as an area name
/// (documented-cases lookup) and gets stronger with every input added:
/// seller's pin (satellite view, wetland layer, geometry cross-checks) and
/// seller's photos (EXIF forensics + AI content/consistency analysis).
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
  final _standController = TextEditingController();

  final _landService = LandContextService();

  List<GazetteerPlace> _places = [];
  List<Wetland> _wetlands = [];
  final List<PhotoEvidence> _photos = [];
  bool _busy = false;
  bool _analyzing = false;
  LandContext? _land;
  String? _landTargetKey; // coordinates the current _land result is for
  PhotoContentAnalysis? _photoContent;
  int _photoContentCount = 0; // photos covered by the current analysis

  @override
  void initState() {
    super.initState();
    _photoService.loadGazetteer().then((p) {
      if (mounted) setState(() => _places = p);
    });
    WetlandService().load().then((w) {
      if (mounted) setState(() => _wetlands = w);
    });
  }

  @override
  void dispose() {
    _areaController.dispose();
    _sellerController.dispose();
    _pinController.dispose();
    _standController.dispose();
    super.dispose();
  }

  (double, double)? get _pin => PinParser.parse(_pinController.text);

  /// Offline wetland-layer check for the seller's pin (pin only — the
  /// suburb centre is too coarse to accuse of being a wetland).
  WetlandHit? get _wetlandHit {
    final pin = _pin;
    if (pin == null || _wetlands.isEmpty) return null;
    return WetlandService.check(pin.$1, pin.$2, _wetlands);
  }

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

  /// Whether _land belongs to the point we would currently analyse (guards
  /// against a stale AI result being applied after the user edits the pin).
  bool get _landIsCurrent {
    final target = _analysisTarget;
    return _land != null &&
        target != null &&
        _landTargetKey == '${target.$1},${target.$2}';
  }

  ScanState get _pinScanState {
    if (_analyzing) return ScanState.scanning;
    if (!_landIsCurrent) return ScanState.idle;
    return _land!.available ? ScanState.success : ScanState.error;
  }

  /// When the buyer typed no area but pasted a pin, derive the suburb from
  /// the gazetteer so the documented-cases check still runs. A derived area
  /// is NOT treated as a seller claim (no pin-vs-area contradiction check).
  GazetteerPlace? get _derivedPlace {
    final pin = _pin;
    if (pin == null) return null;
    GazetteerPlace? best;
    double bestD = double.infinity;
    for (final p in _places) {
      final d = PhotoEvidenceService.distanceKm(pin.$1, pin.$2, p.lat, p.lon);
      if (d <= p.radiusKm + 2 && d < bestD) {
        best = p;
        bestD = d;
      }
    }
    return best;
  }

  /// One button, all online AI: land context at the pin + the seller's
  /// photos judged against the claim and the satellite view.
  Future<void> _runAiAnalysis() async {
    final target = _analysisTarget;
    if (target == null && _photos.isEmpty) return;
    setState(() => _analyzing = true);

    final claim = [
      if (_areaController.text.trim().isNotEmpty)
         'stand in ${_areaController.text.trim()}',
      if (_standController.text.trim().isNotEmpty)
        _standController.text.trim(),
      if (_sellerController.text.trim().isNotEmpty)
        'sold by ${_sellerController.text.trim()}',
    ].join(', ');

    final landFuture = target != null
        ? _landService.analyze(target.$1, target.$2)
        : Future<LandContext?>.value(null);
    // Blind by design: the photo model never sees the satellite or pin.
    final photosFuture = _photos.isNotEmpty
        ? _landService.analyzePhotos(
            photoPaths: _photos.map((p) => p.path).toList(),
            claim: claim.isEmpty ? 'a residential stand' : claim,
          )
        : Future<PhotoContentAnalysis?>.value(null);

    final results = await Future.wait<Object?>([landFuture, photosFuture]);
    if (!mounted) return;
    setState(() {
      _analyzing = false;
      _land = results[0] as LandContext?;
      _landTargetKey =
          target != null ? '${target.$1},${target.$2}' : null;
      _photoContent = results[1] as PhotoContentAnalysis?;
      _photoContentCount = _photos.length;
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
    var area = _areaController.text.trim();
    final pin = _pin;
    final typedArea = area.isNotEmpty;

    if (!typedArea && pin == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enter the area the seller claims, or paste the '
              'seller\'s location pin.')));
      return;
    }
    // Pin only: derive the suburb so the documented-cases check still runs.
    if (!typedArea && _derivedPlace != null) {
      area = _derivedPlace!.name;
    }

    final results = _photos
        .map((ev) => _photoService.check(
              evidence: ev,
              claimedArea: area,
              places: _places,
            ))
        .toList();

    final verdict = RemoteCheckService(scorer: widget.scorer).evaluate(
      claimedArea: area,
      seller: _sellerController.text,
      photoResults: results,
      pinLat: pin?.$1,
      pinLon: pin?.$2,
      // A derived area is not a seller claim — only cross-check the pin
      // against the area when the buyer actually typed a claim.
      claimedPlace: typedArea ? _claimedPlace : null,
      landContext: _landIsCurrent ? _land : null,
      wetlandHit: _wetlandHit,
      photoContent:
          _photoContentCount == _photos.length ? _photoContent : null,
    );

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ResultScreen(
        verdict: verdict,
        area: typedArea ? area : (area.isEmpty ? null : 'near $area'),
        standNumber: _standController.text.trim(),
      ),
    ));
  }

  String _landErrorMessage(String? error) {
    final e = error ?? '';
    if (e.contains('429')) {
      return 'AI analysis was rate-limited (error 429 — quota exceeded), '
          'not an internet problem. Wait a moment and try again. '
          'Details: $e';
    }
    if (e.contains('401') || e.contains('403')) {
      return 'AI analysis was refused for authentication (error $e). Check '
          'the API key.';
    }
    if (e.contains('tile_fetch_failed')) {
      return 'Could not download the satellite image for this spot. Check '
          'your connection and try again.';
    }
    if (e.contains('no_api_key')) {
      return 'No AI key is configured in this build.';
    }
    return 'AI analysis could not be completed ($e). Please try again.';
  }

  Widget _buildLandAiSection(BuildContext context) {
    if (!Config.hasGroqKey) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'AI land analysis is not configured in this build. The offline '
          'checks above still work. (Add a Groq API key to enable an AI '
          'reading of the satellite image.)',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    final land = _land;
    final risky = land != null &&
        land.available &&
        (land.landClass == LandClass.waterOrWetland ||
            land.landClass == LandClass.builtUpDense);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: _analyzing
                ? null
                : LinearGradient(colors: [
                    kAiAccent.withValues(alpha: 0.16),
                    kAiAccent.withValues(alpha: 0.04),
                  ]),
          ),
          child: OutlinedButton.icon(
            onPressed: _analyzing ? null : _runAiAnalysis,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: kAiAccent.withValues(alpha: 0.7)),
              foregroundColor: kAiAccent,
            ),
            icon: _analyzing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(kAiAccent)),
                  )
                : const Icon(Icons.auto_awesome_outlined),
            label: Text(_analyzing
                ? 'Running AI analysis…'
                : (land == null && _photoContent == null)
                    ? (_photos.isEmpty
                        ? 'Analyse this location with AI'
                        : 'Analyse location + photos with AI')
                    : 'Re-analyse with AI'),
          ),
        ),
        if (land != null) ...[
          const SizedBox(height: 12),
          if (!land.available)
            Text(
              _landErrorMessage(land.error),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            )
          else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: risky
                    ? Theme.of(context).colorScheme.errorContainer
                    : kAiAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: risky
                        ? Colors.transparent
                        : kAiAccent.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome,
                          size: 18, color: risky ? null : kAiAccent),
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
        if (_photoContent != null) ...[
          const SizedBox(height: 12),
          _buildPhotoContentCard(context, _photoContent!),
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

  Widget _buildPhotoContentCard(BuildContext context, PhotoContentAnalysis p) {
    if (!p.available) {
      return Text(
        'AI photo check could not be completed (${p.error}).',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    }
    final bad = p.authenticity != 'ok';
    final headline = p.authenticity == 'strong_concerns'
        ? 'Photos show strong signs of being fake or recycled'
        : p.authenticity == 'suspicious'
            ? 'Photos look suspicious'
            : p.terrainClass != LandClass.unknown
                ? 'Photos show: ${p.terrainClass.label.toLowerCase()}'
                : 'Photos analysed';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bad
            ? Theme.of(context).colorScheme.errorContainer
            : kAiAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color:
                bad ? Colors.transparent : kAiAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.image_search_outlined,
                  size: 18, color: bad ? null : kAiAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text('AI photo check: $headline',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text([
            if (p.photosShow.isNotEmpty) p.photosShow,
            if (p.authenticityReasons.isNotEmpty) p.authenticityReasons,
            'Compared against the satellite reading when you tap '
                '"Check this deal".',
          ].join(' ')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final place = _claimedPlace;

    return Scaffold(
      appBar: AppBar(title: const Text('Check a stand')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Enter what the seller told you — every detail you add unlocks '
              'a stronger check. The area alone checks documented fraud '
              'patterns; the seller\'s pin adds satellite and wetland checks; '
              'their photos get verified by AI.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _areaController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Claimed area / suburb',
                hintText: 'e.g. Glen View, Harare',
                prefixIcon: Icon(Icons.location_city_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _sellerController,
              decoration: const InputDecoration(
                labelText: 'Seller / cooperative name (optional)',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _standController,
              decoration: const InputDecoration(
                labelText: 'Stand number (optional)',
                hintText: 'e.g. Stand 1234',
                prefixIcon: Icon(Icons.tag_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pinController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Seller\'s location pin (optional)',
                hintText: '-17.9123, 30.9876 or a Google Maps link',
                prefixIcon: const Icon(Icons.pin_drop_outlined),
                helperText: PinParser.isShortLink(_pinController.text)
                    ? 'Short links can\'t be read here — open it in Maps, '
                        'copy the coordinates, and paste them instead.'
                    : 'Ask the seller to share the stand\'s location pin on '
                        'WhatsApp, then paste it here.',
                helperMaxLines: 3,
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
                scanState: _pinScanState,
                caption: 'This is the exact spot the seller pinned as your '
                    'stand. Does it match what they described — vacant land, '
                    'or something else?',
              ),
              if (_wetlandHit != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _wetlandHit!.inside
                        ? Theme.of(context).colorScheme.errorContainer
                        : Theme.of(context)
                            .colorScheme
                            .tertiaryContainer
                            .withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.water_drop_outlined,
                          size: 20,
                          color: _wetlandHit!.inside
                              ? Theme.of(context).colorScheme.error
                              : null),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _wetlandHit!.inside
                              ? 'This pin falls inside a documented wetland: '
                                  '${_wetlandHit!.wetland.name} '
                                  '(${_wetlandHit!.wetland.designation}). '
                                  'Stands on wetlands face demolition. '
                                  'Verify with EMA before paying anything.'
                              : 'This pin is at the edge of a documented '
                                  'wetland: ${_wetlandHit!.wetland.name}. '
                                  'Ask EMA about the wetland status of this '
                                  'exact stand.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
            if (_analysisTarget != null || _photos.isNotEmpty) ...[
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
