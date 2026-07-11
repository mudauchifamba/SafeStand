import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/photo_evidence_service.dart';
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

  List<GazetteerPlace> _places = [];
  final List<PhotoEvidence> _photos = [];
  bool _busy = false;

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
    super.dispose();
  }

  GazetteerPlace? get _claimedPlace =>
      _photoService.matchPlace(_areaController.text, _places);

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

    final verdict = RemoteCheckService(scorer: widget.scorer).evaluate(
      claimedArea: area,
      seller: _sellerController.text,
      photoResults: results,
    );

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ResultScreen(verdict: verdict, area: area),
    ));
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
            if (place != null) ...[
              const SizedBox(height: 20),
              Text('Satellite view of ${place.name}',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SatelliteView(
                lat: place.lat,
                lon: place.lon,
                caption:
                    'Centre of ${place.name}, ${place.city} — does what the '
                    'seller describes match what you see?',
              ),
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
