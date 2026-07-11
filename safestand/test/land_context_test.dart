import 'package:flutter_test/flutter_test.dart';
import 'package:safestand/services/land_context_service.dart';
import 'package:safestand/services/remote_check_service.dart';
import 'package:safestand/services/risk_scorer.dart';

void main() {
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

  LandContext land(LandClass c) => LandContext(
      landClass: c, confidence: 'high', description: 'test description.');

  group('AI land-context scoring', () {
    test('water/wetland raises risk with a high-weight reason', () {
      final v = remote().evaluate(
        claimedArea: 'Glen View',
        photoResults: [],
        landContext: land(LandClass.waterOrWetland),
      );
      expect(v.score, RemoteCheckService.wetlandPoints);
      final r = v.reasons.firstWhere((x) => x.label.contains('wetland'));
      expect(r.weight, greaterThanOrEqualTo(3));
    });

    test('dense built-up adds a moderate flag', () {
      final v = remote().evaluate(
        claimedArea: 'Glen View',
        photoResults: [],
        landContext: land(LandClass.builtUpDense),
      );
      expect(v.score, RemoteCheckService.denseBuiltUpPoints);
      expect(v.reasons.any((x) => x.label.contains('densely built up')),
          isTrue);
    });

    test('bare land is informational and does not change the score', () {
      final v = remote().evaluate(
        claimedArea: 'Glen View',
        photoResults: [],
        landContext: land(LandClass.bareLand),
      );
      expect(v.score, 0);
      final r =
          v.reasons.firstWhere((x) => x.label.startsWith('AI satellite check'));
      expect(r.weight, 0);
    });

    test('unavailable AI result is ignored entirely', () {
      final v = remote().evaluate(
        claimedArea: 'Glen View',
        photoResults: [],
        landContext: LandContext.unavailable('no_api_key'),
      );
      expect(v.score, 0);
      expect(v.reasons.any((x) => x.label.contains('AI satellite')), isFalse);
    });
  });

  group('tile math', () {
    test('produces a valid Esri URL with sane tile indices', () {
      final url = LandContextService.tileUrl(-17.905, 30.985, 17);
      expect(url, contains('/tile/17/'));
      final parts = url.split('/tile/17/')[1].split('/');
      final y = int.parse(parts[0]);
      final x = int.parse(parts[1]);
      const max = 1 << 17;
      expect(x, inInclusiveRange(0, max - 1));
      expect(y, inInclusiveRange(0, max - 1));
    });
  });
}
