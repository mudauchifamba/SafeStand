import 'package:flutter_test/flutter_test.dart';
import 'package:safestand/models/models.dart';
import 'package:safestand/services/land_context_service.dart';
import 'package:safestand/services/remote_check_service.dart';
import 'package:safestand/services/risk_scorer.dart';
import 'package:safestand/services/wetland_service.dart';

void main() {
  final monavale = Wetland(
    name: 'Monavale Vlei',
    lat: -17.795,
    lon: 31.010,
    radiusKm: 1.2,
    designation: 'Ramsar-listed urban wetland',
    source: 'test source',
  );

  RemoteCheckService remote() => RemoteCheckService(
        scorer: RiskScorer(
          areas: [],
          rules: [],
          verdictBands: const [
            {'band': 'green', 'min_score': 0, 'max_score': 24},
            {'band': 'amber', 'min_score': 25, 'max_score': 49},
            {'band': 'red', 'min_score': 50, 'max_score': 100},
          ],
          nextSteps: const [],
        ),
      );

  group('WetlandService.check', () {
    test('pin at the wetland centre is inside', () {
      final hit = WetlandService.check(-17.795, 31.010, [monavale]);
      expect(hit, isNotNull);
      expect(hit!.inside, isTrue);
    });

    test('pin just outside the boundary is near, not inside', () {
      // ~1.4 km north of centre: outside 1.2 km radius, within 0.5 margin.
      final hit = WetlandService.check(-17.7824, 31.010, [monavale]);
      expect(hit, isNotNull);
      expect(hit!.inside, isFalse);
    });

    test('pin far away returns null', () {
      expect(WetlandService.check(-17.70, 31.20, [monavale]), isNull);
    });
  });

  group('wetland scoring', () {
    test('pin inside a mapped wetland raises risk with a citable reason', () {
      final v = remote().evaluate(
        claimedArea: 'Monavale',
        photoResults: [],
        wetlandHit:
            WetlandHit(wetland: monavale, distanceKm: 0.3, inside: true),
      );
      expect(v.score, RemoteCheckService.mappedWetlandInsidePoints);
      expect(v.band, isNot(RiskBand.green));
      final r = v.reasons
          .firstWhere((x) => x.label.contains('documented wetland'));
      expect(r.explanation, contains('EMA'));
      expect(v.nextSteps.first, contains('Environmental Management Agency'));
    });

    test('pin near a wetland edge adds a smaller flag', () {
      final v = remote().evaluate(
        claimedArea: 'Monavale',
        photoResults: [],
        wetlandHit:
            WetlandHit(wetland: monavale, distanceKm: 1.4, inside: false),
      );
      expect(v.score, RemoteCheckService.mappedWetlandNearPoints);
      expect(v.reasons.any((x) => x.label.contains('edge of a documented')),
          isTrue);
    });

    test('AI vlei indicators score when no mapped wetland covers the spot',
        () {
      final v = remote().evaluate(
        claimedArea: 'Glen View',
        photoResults: [],
        landContext: LandContext(
          landClass: LandClass.vegetation,
          confidence: 'medium',
          description: 'grassy corridor with a drainage line.',
          wetlandSigns: 'strong',
        ),
      );
      expect(v.score, RemoteCheckService.aiWetlandStrongPoints);
      expect(
          v.reasons.any((x) => x.label.contains('vlei')), isTrue);
    });

    test('AI vlei indicators are suppressed when the mapped layer already '
        'flagged the pin (no double counting)', () {
      final v = remote().evaluate(
        claimedArea: 'Monavale',
        photoResults: [],
        wetlandHit:
            WetlandHit(wetland: monavale, distanceKm: 0.3, inside: true),
        landContext: LandContext(
          landClass: LandClass.vegetation,
          confidence: 'medium',
          description: 'grassy area.',
          wetlandSigns: 'strong',
        ),
      );
      expect(v.score, RemoteCheckService.mappedWetlandInsidePoints);
    });

    test('possible signs add only a weak cautionary flag', () {
      final v = remote().evaluate(
        claimedArea: 'Glen View',
        photoResults: [],
        landContext: LandContext(
          landClass: LandClass.bareLand,
          confidence: 'low',
          description: 'open land.',
          wetlandSigns: 'possible',
        ),
      );
      expect(v.score, RemoteCheckService.aiWetlandPossiblePoints);
      expect(v.band, RiskBand.green);
    });
  });
}
