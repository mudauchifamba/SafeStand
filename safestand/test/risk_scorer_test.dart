import 'package:flutter_test/flutter_test.dart';
import 'package:safestand/models/models.dart';
import 'package:safestand/services/risk_scorer.dart';

// Minimal in-code rule set mirroring assets/data/red_flag_rules.json so the
// scorer can be tested without loading assets.
RiskScorer _buildScorer() {
  final rules = [
    RedFlagRule(
      id: 'no_sg_diagram_reference',
      label: 'No Surveyor-General / Diagram number',
      weight: 3,
      detect: 'absence',
      keywords: const [],
      keywordsPresentMeansOk: const ['sg ', 'diagram', 'general plan', 'surveyor-general'],
      explanation: 'No survey Diagram / General Plan number found.',
    ),
    RedFlagRule(
      id: 'regularise_later_language',
      label: "'Title deeds later / once regularised' language",
      weight: 2,
      detect: 'presence',
      keywords: const ['regularis', 'will be processed', 'once the area'],
      keywordsPresentMeansOk: const [],
      explanation: 'Promising title deeds later is a common stalling tactic.',
    ),
    RedFlagRule(
      id: 'cash_only_payment',
      label: 'Cash-only / informal payment',
      weight: 2,
      detect: 'presence',
      keywords: const ['cash only', 'non-refundable'],
      keywordsPresentMeansOk: const [],
      explanation: 'Cash-only, non-refundable demands are a warning sign.',
    ),
    RedFlagRule(
      id: 'no_council_reference',
      label: 'No council file reference',
      weight: 3,
      detect: 'absence',
      keywords: const [],
      keywordsPresentMeansOk: const ['council', 'ch/', 'housing department'],
      explanation: 'No traceable council reference found.',
    ),
  ];

  final bands = [
    {'band': 'green', 'min_score': 0, 'max_score': 24},
    {'band': 'amber', 'min_score': 25, 'max_score': 49},
    {'band': 'red', 'min_score': 50, 'max_score': 100},
  ];

  final areas = [
    HighRiskArea(
      area: 'Whitecliff',
      city: 'Harare',
      pattern: 'Large-scale demolitions after cooperative sales.',
      riskWeight: 0.9,
      source: 'Public news reporting, 2026',
    ),
  ];

  return RiskScorer(
    areas: areas,
    rules: rules,
    verdictBands: bands,
    nextSteps: const ['Deeds Registry', 'Surveyor-General'],
  );
}

void main() {
  final scorer = _buildScorer();

  test('fraudulent offer letter scores RED', () {
    final v = scorer.score(
      documentText:
          'RUVIMBO YETU CO-OPERATIVE offer letter. USD 2000 CASH ONLY '
          'non-refundable. Title deeds once the area is regularised by council.',
    );
    expect(v.band, RiskBand.red);
    expect(v.score, greaterThanOrEqualTo(50));
  });

  test('genuine council letter scores GREEN', () {
    final v = scorer.score(
      documentText:
          'CITY OF HARARE HOUSING DEPARTMENT. Ref CH/RES/044/2025. '
          'Diagram/General Plan No SG 9012/2024, Surveyor-General office.',
    );
    expect(v.band, RiskBand.green);
  });

  test('registered cooperative with proper refs is NOT over-flagged', () {
    final v = scorer.score(
      documentText:
          'GOOD HOPE CO-OPERATIVE. Council planning consent CH/PLAN/2025/077. '
          'Diagram/General Plan No SG 4410/2020.',
    );
    expect(v.band, RiskBand.green);
  });

  test('known high-risk area raises the score', () {
    final v = scorer.score(area: 'Whitecliff');
    expect(v.matchedAreas, contains('Whitecliff'));
    expect(v.score, greaterThan(0));
  });
}
