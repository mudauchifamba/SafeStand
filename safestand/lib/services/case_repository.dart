import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/models.dart';
import 'risk_scorer.dart';

/// Loads the bundled seed dataset and red-flag rules, and hands back a fully
/// configured [RiskScorer]. Everything is local/offline.
class CaseRepository {
  Future<RiskScorer> loadScorer() async {
    final casesRaw =
        await rootBundle.loadString('assets/data/known_cases.json');
    final rulesRaw =
        await rootBundle.loadString('assets/data/red_flag_rules.json');

    final casesJson = jsonDecode(casesRaw) as Map<String, dynamic>;
    final rulesJson = jsonDecode(rulesRaw) as Map<String, dynamic>;

    final areas = (casesJson['high_risk_areas'] as List)
        .map((e) => HighRiskArea.fromJson(e as Map<String, dynamic>))
        .toList();

    final rules = (rulesJson['rules'] as List)
        .map((e) => RedFlagRule.fromJson(e as Map<String, dynamic>))
        .toList();

    final bands = (rulesJson['verdict_bands'] as List)
        .map((e) => (e as Map<String, dynamic>))
        .toList();

    final nextSteps = (rulesJson['next_steps'] as List)
        .map((e) => e.toString())
        .toList();

    return RiskScorer(
      areas: areas,
      rules: rules,
      verdictBands: bands,
      nextSteps: nextSteps,
    );
  }
}
