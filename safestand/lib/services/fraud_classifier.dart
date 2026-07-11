import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;

/// Pure-Dart port of the trained TF-IDF + logistic regression classifier
/// from ml/ (see ml/models/model_export.json).
///
/// Inference is exactly the sklearn pipeline the model was trained with:
///   1. tokenize (lowercase, \b\w\w+\b), build unigrams + bigrams
///   2. sublinear tf (1 + ln(count)) x exported idf, L2-normalised
///   3. dot(coef, x) + intercept -> sigmoid = P(genuine)
///
/// No ML runtime, no network — a few KB of arithmetic that runs offline,
/// and every term's contribution is inspectable ([topContributions]).
class FraudClassifier {
  final Map<String, int> vocabulary;
  final List<double> idf;
  final List<double> coef;
  final double intercept;

  FraudClassifier({
    required this.vocabulary,
    required this.idf,
    required this.coef,
    required this.intercept,
  });

  factory FraudClassifier.fromJson(Map<String, dynamic> j) {
    return FraudClassifier(
      vocabulary: (j['vocabulary'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v as int)),
      idf: (j['idf'] as List).map((e) => (e as num).toDouble()).toList(),
      coef: (j['coef'] as List).map((e) => (e as num).toDouble()).toList(),
      intercept: (j['intercept'] as num).toDouble(),
    );
  }

  static Future<FraudClassifier> loadFromAssets() async {
    final raw = await rootBundle.loadString('assets/ml/model_export.json');
    return FraudClassifier.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  static final _token = RegExp(r'\b\w\w+\b', unicode: true);

  /// Sparse TF-IDF vector (index -> weight) for a document.
  Map<int, double> _vectorize(String text) {
    final tokens =
        _token.allMatches(text.toLowerCase()).map((m) => m.group(0)!).toList();

    final counts = <int, int>{};
    void add(String term) {
      final idx = vocabulary[term];
      if (idx != null) counts[idx] = (counts[idx] ?? 0) + 1;
    }

    for (var i = 0; i < tokens.length; i++) {
      add(tokens[i]);
      if (i + 1 < tokens.length) add('${tokens[i]} ${tokens[i + 1]}');
    }

    // sublinear tf * idf, then L2 normalise
    final vec = <int, double>{};
    var norm = 0.0;
    counts.forEach((idx, c) {
      final w = (1 + math.log(c)) * idf[idx];
      vec[idx] = w;
      norm += w * w;
    });
    if (norm > 0) {
      norm = math.sqrt(norm);
      vec.updateAll((_, w) => w / norm);
    }
    return vec;
  }

  /// Probability that the document is FRAUDULENT (0..1).
  ///
  /// classes = [fraudulent, genuine]; sigmoid gives P(genuine), so we
  /// return its complement.
  double fraudProbability(String text) {
    final vec = _vectorize(text);
    var z = intercept;
    vec.forEach((idx, w) => z += coef[idx] * w);
    final pGenuine = 1 / (1 + math.exp(-z));
    return 1 - pGenuine;
  }

  /// The vocabulary terms that pushed this document's score hardest, for
  /// the explainability layer. Negative contribution = towards fraudulent.
  List<(String, double)> topContributions(String text, {int n = 5}) {
    final vec = _vectorize(text);
    final inverse = <int, String>{
      for (final e in vocabulary.entries) e.value: e.key
    };
    final contribs = <(String, double)>[
      for (final e in vec.entries) (inverse[e.key]!, coef[e.key] * e.value)
    ]..sort((a, b) => a.$2.abs().compareTo(b.$2.abs()) * -1);
    return contribs.take(n).toList();
  }
}
