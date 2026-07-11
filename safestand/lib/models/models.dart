// Data models for SafeStand.
//
// Kept deliberately small and dependency-free so the scoring logic stays
// auditable — a judge (or a lawyer) can read exactly how a verdict is reached.

enum RiskBand { green, amber, red }

extension RiskBandLabel on RiskBand {
  String get label {
    switch (this) {
      case RiskBand.green:
        return 'Lower risk';
      case RiskBand.amber:
        return 'Caution';
      case RiskBand.red:
        return 'High risk';
    }
  }
}

/// A documented high-risk area from the seed dataset.
class HighRiskArea {
  final String area;
  final String city;
  final String pattern;
  final double riskWeight;
  final String source;

  HighRiskArea({
    required this.area,
    required this.city,
    required this.pattern,
    required this.riskWeight,
    required this.source,
  });

  factory HighRiskArea.fromJson(Map<String, dynamic> j) => HighRiskArea(
        area: j['area'] as String,
        city: j['city'] as String,
        pattern: j['pattern'] as String,
        riskWeight: (j['risk_weight'] as num).toDouble(),
        source: j['source'] as String,
      );
}

/// A single red-flag rule loaded from red_flag_rules.json.
class RedFlagRule {
  final String id;
  final String label;
  final int weight;
  final String detect; // "presence" or "absence"
  final List<String> keywords; // for presence rules
  final List<String> keywordsPresentMeansOk; // for absence rules
  final String explanation;

  RedFlagRule({
    required this.id,
    required this.label,
    required this.weight,
    required this.detect,
    required this.keywords,
    required this.keywordsPresentMeansOk,
    required this.explanation,
  });

  factory RedFlagRule.fromJson(Map<String, dynamic> j) => RedFlagRule(
        id: j['id'] as String,
        label: j['label'] as String,
        weight: j['weight'] as int,
        detect: j['detect'] as String,
        keywords:
            (j['keywords'] as List?)?.map((e) => e.toString()).toList() ?? [],
        keywordsPresentMeansOk: (j['keywords_present_means_ok'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        explanation: j['explanation'] as String,
      );

  /// Returns true if this rule is "triggered" (i.e. a red flag is present)
  /// against the given lower-cased document text.
  bool isTriggered(String lowerText) {
    if (detect == 'presence') {
      return keywords.any((k) => lowerText.contains(k.toLowerCase()));
    } else {
      // absence: triggered when NONE of the "ok" keywords appear
      final ok =
          keywordsPresentMeansOk.any((k) => lowerText.contains(k.toLowerCase()));
      return !ok;
    }
  }
}

/// A single reason contributing to the final verdict, shown to the user.
class VerdictReason {
  final String label;
  final String explanation;
  final int weight;

  VerdictReason(this.label, this.explanation, this.weight);
}

/// The final result returned to the UI.
class RiskVerdict {
  final RiskBand band;
  final int score; // 0-100
  final List<VerdictReason> reasons;
  final List<String> matchedAreas; // area names matched from the seed dataset
  final List<String> nextSteps;

  RiskVerdict({
    required this.band,
    required this.score,
    required this.reasons,
    required this.matchedAreas,
    required this.nextSteps,
  });
}
