import 'package:flutter_test/flutter_test.dart';
import 'package:safestand/models/models.dart';
import 'package:safestand/services/photo_evidence_service.dart';
import 'package:safestand/services/pin_parser.dart';
import 'package:safestand/services/remote_check_service.dart';
import 'package:safestand/services/risk_scorer.dart';

void main() {
  group('PinParser', () {
    test('parses raw coordinates', () {
      expect(PinParser.parse('-17.9123, 30.9876'), (-17.9123, 30.9876));
      expect(PinParser.parse(' -17.9123 30.9876 '), (-17.9123, 30.9876));
    });

    test('parses Google Maps links', () {
      expect(PinParser.parse('https://www.google.com/maps?q=-17.9123,30.9876'),
          (-17.9123, 30.9876));
      expect(
          PinParser.parse('https://www.google.com/maps/@-17.9123,30.9876,17z'),
          (-17.9123, 30.9876));
      expect(PinParser.parse('geo:-17.9123,30.9876'), (-17.9123, 30.9876));
    });

    test('parses comma-decimal coordinates (common phone locales)', () {
      expect(PinParser.parse('-17,908532, 30,810459'),
          (-17.908532, 30.810459));
      expect(PinParser.parse('-17,795 31,010'), (-17.795, 31.010));
    });

    test('rejects junk and out-of-range values', () {
      expect(PinParser.parse('Glen View'), isNull);
      expect(PinParser.parse(''), isNull);
      expect(PinParser.parse('-95.0, 30.0'), isNull);
    });

    test('detects short links', () {
      expect(PinParser.isShortLink('https://maps.app.goo.gl/abc'), isTrue);
      expect(PinParser.isShortLink('-17.9, 30.9'), isFalse);
    });
  });

  group('pin scoring', () {
    final glenView = GazetteerPlace(
        name: 'Glen View', city: 'Harare', lat: -17.905, lon: 30.985, radiusKm: 4);

    RemoteCheckService remote() => RemoteCheckService(
          scorer: RiskScorer(
            areas: [],
            rules: [],
            verdictBands: [
              {'band': 'green', 'min_score': 0, 'max_score': 24},
              {'band': 'amber', 'min_score': 25, 'max_score': 49},
              {'band': 'red', 'min_score': 50, 'max_score': 100},
            ],
            nextSteps: [],
          ),
        );

    test('pin far from claimed area raises risk', () {
      final v = remote().evaluate(
        claimedArea: 'Glen View',
        photoResults: [],
        pinLat: -17.600, // Domboshava-ish, ~37 km away
        pinLon: 31.130,
        claimedPlace: glenView,
      );
      expect(v.band, isNot(RiskBand.green));
      expect(v.reasons.any((r) => r.label.contains('outside the claimed')),
          isTrue);
    });

    test('pin inside claimed area adds only a zero-weight note', () {
      final v = remote().evaluate(
        claimedArea: 'Glen View',
        photoResults: [],
        pinLat: -17.906,
        pinLon: 30.986,
        claimedPlace: glenView,
      );
      expect(v.score, 0);
      final note =
          v.reasons.firstWhere((r) => r.label.contains('inside the claimed'));
      expect(note.weight, 0);
    });

    test('photo taken far from the pinned stand raises risk', () {
      final service = PhotoEvidenceService();
      final photo = service.check(
        evidence: PhotoEvidence(path: 'x.jpg', lat: -17.870, lon: 30.870),
        claimedArea: 'Glen View',
        places: [glenView],
      );
      final v = remote().evaluate(
        claimedArea: 'Glen View',
        photoResults: [photo],
        pinLat: -17.906,
        pinLon: 30.986,
        claimedPlace: glenView,
      );
      expect(
          v.reasons.any((r) => r.label.contains('not taken at the pinned')),
          isTrue);
      expect(v.score,
          greaterThanOrEqualTo(RemoteCheckService.photoFarFromPinPoints));
    });

    test('photo at the pinned location adds only a zero-weight note', () {
      final service = PhotoEvidenceService();
      final photo = service.check(
        evidence: PhotoEvidence(path: 'x.jpg', lat: -17.9062, lon: 30.9862),
        claimedArea: 'Glen View',
        places: [glenView],
      );
      final v = remote().evaluate(
        claimedArea: 'Glen View',
        photoResults: [photo],
        pinLat: -17.906,
        pinLon: 30.986,
        claimedPlace: glenView,
      );
      final note = v.reasons
          .firstWhere((r) => r.label.contains('taken at the pinned'));
      expect(note.weight, 0);
    });
  });
}
