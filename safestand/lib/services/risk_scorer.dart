import '../models/models.dart';

/// The core reasoning layer of SafeStand.
///
/// It combines two signals into a single 0-100 risk score:
///   1. Area/scheme match against the documented seed dataset.
///   2. Red-flag rules fired against OCR'd document text.
///
/// The logic is intentionally transparent and rule-based rather than a black
/// box: because the output influences whether someone spends their savings,
/// every point of the score is explainable and auditable. An ML classifier can
/// be layered on later once enough real documents are collected through use.
class RiskScorer {
  final List<HighRiskArea> areas;
  final List<RedFlagRule> rules;
  final List<Map<String, dynamic>> verdictBands;
  final List<String> nextSteps;

  RiskScorer({
    required this.areas,
    required this.rules,
    required this.verdictBands,
    required this.nextSteps,
  });

  /// Score a deal.
  ///
  /// [area] and [seller] come from manual entry (may be empty).
  /// [documentText] is the OCR output (may be empty if the user only typed
  /// details and did not scan anything).
  /// [modelFraudProbability] is the trained classifier's P(fraudulent) for
  /// the document, when available. The model then carries most of the
  /// document score and the rules act as the explainability layer.
  RiskVerdict score({
    String area = '',
    String seller = '',
    String documentText = '',
    double? modelFraudProbability,
  }) {
    final reasons = <VerdictReason>[];
    final matchedAreas = <String>[];

    // --- Signal 1: documented area / scheme match -------------------------
    double areaScore = 0; // 0..1
    final needleArea = area.trim().toLowerCase();
    final needleSeller = seller.trim().toLowerCase();

    if (needleArea.isNotEmpty || needleSeller.isNotEmpty) {
      for (final a in areas) {
        final hit = (needleArea.isNotEmpty &&
                a.area.toLowerCase().contains(needleArea)) ||
            (needleArea.isNotEmpty &&
                needleArea.contains(a.area.toLowerCase()));
        if (hit) {
          matchedAreas.add(a.area);
          if (a.riskWeight > areaScore) areaScore = a.riskWeight;
          reasons.add(VerdictReason(
            'Area with documented fraud pattern: ${a.area}',
            '${a.pattern} (Source: ${a.source})',
            3,
          ));
        }
      }
    }

    // --- Signal 2: document red-flag rules --------------------------------
    double flagScore = 0; // 0..1
    if (documentText.trim().isNotEmpty) {
      final lower = documentText.toLowerCase();
      int firedWeight = 0;
      int totalWeight = 0;
      for (final rule in rules) {
        totalWeight += rule.weight;
        if (rule.isTriggered(lower)) {
          firedWeight += rule.weight;
          reasons.add(VerdictReason(rule.label, rule.explanation, rule.weight));
        }
      }
      if (totalWeight > 0) flagScore = firedWeight / totalWeight;
    }

    // --- Signal 3: trained classifier --------------------------------------
    // Model decision + rule-based justification is the responsible-AI
    // pattern here: the model carries the score, the fired rules above give
    // the user auditable reasons.
    if (modelFraudProbability != null && documentText.trim().isNotEmpty) {
      final p = modelFraudProbability.clamp(0.0, 1.0);
      flagScore = 0.6 * p + 0.4 * flagScore;
      reasons.add(VerdictReason(
        'AI document assessment',
        'Our trained model, which learned from documented fraudulent and '
            'genuine land documents, rates this document '
            '${(p * 100).round()}% similar to known fraud patterns. The '
            'flags listed here are the specific wording it and our rules '
            'reacted to.',
        p >= 0.5 ? 3 : 0,
      ));
    }

    // --- Combine ----------------------------------------------------------
    // If we have both signals, weight them; if only one, use it directly.
    double combined;
    final hasArea = matchedAreas.isNotEmpty || needleArea.isNotEmpty || needleSeller.isNotEmpty;
    final hasDoc = documentText.trim().isNotEmpty;

    if (hasArea && hasDoc) {
      combined = 0.45 * areaScore + 0.55 * flagScore;
    } else if (hasDoc) {
      combined = flagScore;
    } else {
      combined = areaScore;
    }

    final score = (combined * 100).round().clamp(0, 100);
    final band = _bandFor(score);

    if (reasons.isEmpty) {
      reasons.add(VerdictReason(
        'No documented red flags found',
        'This does not confirm the deal is legal — it only means our checks '
            'found no known warning signs. Always verify independently before paying.',
        0,
      ));
    }

    // Sort reasons by weight (most important first).
    reasons.sort((a, b) => b.weight.compareTo(a.weight));

    return RiskVerdict(
      band: band,
      score: score,
      reasons: reasons,
      matchedAreas: matchedAreas,
      nextSteps: nextSteps,
    );
  }

  RiskBand _bandFor(int score) {
    for (final b in verdictBands) {
      final min = b['min_score'] as int;
      final max = b['max_score'] as int;
      if (score >= min && score <= max) {
        switch (b['band']) {
          case 'green':
            return RiskBand.green;
          case 'amber':
            return RiskBand.amber;
          case 'red':
            return RiskBand.red;
        }
      }
    }
    return RiskBand.amber;
  }
}
