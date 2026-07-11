import 'package:flutter_test/flutter_test.dart';
import 'package:safestand/models/models.dart';
import 'package:safestand/services/photo_evidence_service.dart';
import 'package:safestand/services/remote_check_service.dart';
import 'package:safestand/services/risk_scorer.dart';

void main() {
  final places = [
    GazetteerPlace(
        name: 'Glen View', city: 'Harare', lat: -17.905, lon: 30.985, radiusKm: 4),
    GazetteerPlace(
        name: 'Whitecliff', city: 'Harare', lat: -17.870, lon: 30.870, radiusKm: 4),
  ];

  final service = PhotoEvidenceService();

  RiskScorer emptyScorer() => RiskScorer(
        areas: [
          HighRiskArea(
            area: 'Whitecliff',
            city: 'Harare',
            pattern: 'test pattern',
            riskWeight: 0.9,
            source: 'test source',
          ),
        ],
        rules: [],
        verdictBands: [
          {'band': 'green', 'min_score': 0, 'max_score': 24},
          {'band': 'amber', 'min_score': 25, 'max_score': 49},
          {'band': 'red', 'min_score': 50, 'max_score': 100},
        ],
        nextSteps: ['verify at the deeds registry'],
      );

  RemoteCheckService remote() => RemoteCheckService(scorer: emptyScorer());

  group('haversine distance', () {
    test('zero for identical points', () {
      expect(PhotoEvidenceService.distanceKm(-17.9, 30.9, -17.9, 30.9),
          closeTo(0, 0.001));
    });

    test('Glen View to Whitecliff is roughly 13 km', () {
      final d = PhotoEvidenceService.distanceKm(
          -17.905, 30.985, -17.870, 30.870);
      expect(d, inInclusiveRange(11, 15));
    });
  });

  group('gazetteer matching', () {
    test('matches case-insensitively and within longer strings', () {
      expect(service.matchPlace('glen view', places)?.name, 'Glen View');
      expect(service.matchPlace('Glen View, Harare', places)?.name, 'Glen View');
    });

    test('unknown area returns null', () {
      expect(service.matchPlace('Bulawayo North', places), isNull);
    });
  });

  group('photo check findings', () {
    test('photo inside claimed area matches', () {
      final r = service.check(
        evidence: PhotoEvidence(path: 'x.jpg', lat: -17.906, lon: 30.986),
        claimedArea: 'Glen View',
        places: places,
      );
      expect(r.finding, GpsFinding.matches);
      expect(r.distanceKm, lessThan(4));
    });

    test('photo far from claimed area mismatches', () {
      // Photo taken ~40 km away (Domboshava-ish) while claiming Glen View.
      final r = service.check(
        evidence: PhotoEvidence(path: 'x.jpg', lat: -17.600, lon: 31.130),
        claimedArea: 'Glen View',
        places: places,
      );
      expect(r.finding, GpsFinding.mismatch);
      expect(r.distanceKm, greaterThan(30));
    });

    test('no GPS is neutral, never a mismatch', () {
      final r = service.check(
        evidence: PhotoEvidence(path: 'x.jpg'),
        claimedArea: 'Glen View',
        places: places,
      );
      expect(r.finding, GpsFinding.noGps);
    });

    test('stale photo age is computed from EXIF timestamp', () {
      final r = service.check(
        evidence: PhotoEvidence(
            path: 'x.jpg',
            lat: -17.906,
            lon: 30.986,
            takenAt: DateTime(2019, 5, 1)),
        claimedArea: 'Glen View',
        places: places,
        now: DateTime(2026, 7, 11),
      );
      expect(r.photoAgeDays, greaterThan(2000));
    });
  });

  group('remote verdict', () {
    test('GPS mismatch alone pushes the verdict to amber or worse', () {
      final v = remote().evaluate(
        claimedArea: 'Glen View',
        photoResults: [
          service.check(
            evidence: PhotoEvidence(path: 'x.jpg', lat: -17.600, lon: 31.130),
            claimedArea: 'Glen View',
            places: places,
          ),
        ],
      );
      expect(v.band, isNot(RiskBand.green));
      expect(v.reasons.any((r) => r.label.contains('contradicts')), isTrue);
    });

    test('GPS match never lowers risk below the area-based score', () {
      final scorer = emptyScorer();
      final baseline = scorer.score(area: 'Whitecliff').score;

      final v = RemoteCheckService(scorer: scorer).evaluate(
        claimedArea: 'Whitecliff',
        photoResults: [
          service.check(
            evidence: PhotoEvidence(path: 'x.jpg', lat: -17.871, lon: 30.871),
            claimedArea: 'Whitecliff',
            places: [places[1]],
          ),
        ],
      );
      expect(v.score, greaterThanOrEqualTo(baseline));
      // and the match reason carries zero weight
      final match =
          v.reasons.firstWhere((r) => r.label.contains('matches'));
      expect(match.weight, 0);
    });

    test('missing GPS adds an explanatory note without changing the score',
        () {
      final v = remote().evaluate(
        claimedArea: 'Glen View',
        photoResults: [
          service.check(
            evidence: PhotoEvidence(path: 'x.jpg'),
            claimedArea: 'Glen View',
            places: places,
          ),
        ],
      );
      expect(v.score, 0);
      expect(v.band, RiskBand.green);
      expect(v.reasons.any((r) => r.label.contains('no location data')),
          isTrue);
    });

    test('old photo adds points and a reason', () {
      final r = service.check(
        evidence: PhotoEvidence(
            path: 'x.jpg',
            lat: -17.906,
            lon: 30.986,
            takenAt: DateTime(2019, 5, 1)),
        claimedArea: 'Glen View',
        places: places,
        now: DateTime(2026, 7, 11),
      );
      final v = remote().evaluate(claimedArea: 'Glen View', photoResults: [r]);
      expect(v.score, RemoteCheckService.stalePhotoPoints);
      expect(v.reasons.any((x) => x.label == 'Photo is old'), isTrue);
    });
  });
}
