// train_model.dart — no-Python retraining path for SafeStand.
//
// Replicates ml/train.py's pipeline exactly (TF-IDF ngram(1,2), min_df=2,
// sublinear tf, smooth idf, L2 norm -> logistic regression, balanced class
// weights, C=1.0) so the exported model_export.json stays byte-compatible in
// SCHEMA with the sklearn export the app already consumes.
//
// It also owns the STAMP-CONCEPT augmentation: genuine rows gain official
// date-stamp phrases (office + date + file reference); fraudulent rows gain
// imitation-stamp phrases (no date / no reference / misspellings) or nothing.
// This mirrors ml/generate_synthetic.py's stamp pools.
//
// Usage (from safestand/):  dart run tool/train_model.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

// ---------------------------------------------------------------------------
// CSV (RFC 4180)
// ---------------------------------------------------------------------------

List<List<String>> parseCsv(String input) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < input.length; i++) {
    final c = input[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < input.length && input[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(c);
      }
    } else if (c == '"') {
      inQuotes = true;
    } else if (c == ',') {
      row.add(field.toString());
      field.clear();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < input.length && input[i + 1] == '\n') i++;
      row.add(field.toString());
      field.clear();
      if (row.any((f) => f.isNotEmpty)) rows.add(row);
      row = <String>[];
    } else {
      field.write(c);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    if (row.any((f) => f.isNotEmpty)) rows.add(row);
  }
  return rows;
}

String csvField(String s) =>
    (s.contains(',') || s.contains('"') || s.contains('\n'))
        ? '"${s.replaceAll('"', '""')}"'
        : s;

// ---------------------------------------------------------------------------
// Stamp-concept augmentation (mirrors generate_synthetic.py pools)
// ---------------------------------------------------------------------------

const genuineStamp = [
  'official date stamp: City of Harare Housing and Community Services {d} ref CH/HD/{n}',
  'bears the official date stamp of the Registrar of Deeds Harare dated {d} ref DT {n}',
  'common seal of the council affixed {d} ref NTC/HD/{n}',
  'official date stamp {d} council file CH/HOU/{n} appears on the letter',
  'town clerk official date stamp dated {d} with file reference CH/{n}',
];
const fraudStamp = [
  'rubber stamp reads APPROVED with no date and no reference',
  'stamp reads OFICIAL STAMP of the cooperative, no council stamp',
  'bright red APPROVED stamp only, no file reference or date',
  'orange RESERVED stamp reading PAY TODAY',
  "chairman's personal stamp affixed, no official council stamp or date",
  'cooperative stamp without date, reference or issuing office',
];
const months = ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'];

/// Deterministic augmentation so re-runs are reproducible.
String? stampSentence(String label, int rowIndex) {
  final rng = math.Random(7000 + rowIndex);
  if (label == 'genuine') {
    if (rng.nextDouble() >= 0.6) return null;
    final d = '${(rng.nextInt(28) + 1).toString().padLeft(2, '0')} '
        '${months[rng.nextInt(12)]} ${2024 + rng.nextInt(3)}';
    final n = 40 + rng.nextInt(9960);
    return genuineStamp[rng.nextInt(genuineStamp.length)]
        .replaceAll('{d}', d)
        .replaceAll('{n}', '$n');
  } else {
    if (rng.nextDouble() >= 0.35) return null;
    return fraudStamp[rng.nextInt(fraudStamp.length)];
  }
}

// ---------------------------------------------------------------------------
// TF-IDF (sklearn-equivalent: lowercase, \b\w\w+\b, ngram(1,2), min_df=2,
// sublinear tf, smooth idf, L2 norm)
// ---------------------------------------------------------------------------

final _token = RegExp(r'\b\w\w+\b', unicode: true);

List<String> terms(String text) {
  final toks =
      _token.allMatches(text.toLowerCase()).map((m) => m.group(0)!).toList();
  final out = <String>[...toks];
  for (var i = 0; i + 1 < toks.length; i++) {
    out.add('${toks[i]} ${toks[i + 1]}');
  }
  return out;
}

class Vectorizer {
  late final Map<String, int> vocabulary;
  late final List<double> idf;

  void fit(List<String> docs) {
    final df = <String, int>{};
    for (final d in docs) {
      for (final t in terms(d).toSet()) {
        df[t] = (df[t] ?? 0) + 1;
      }
    }
    final kept = df.entries.where((e) => e.value >= 2).map((e) => e.key).toList()
      ..sort();
    vocabulary = {for (var i = 0; i < kept.length; i++) kept[i]: i};
    final n = docs.length;
    idf = [
      for (final t in kept) math.log((1 + n) / (1 + df[t]!)) + 1.0,
    ];
  }

  Map<int, double> transform(String doc) {
    final counts = <int, int>{};
    for (final t in terms(doc)) {
      final idx = vocabulary[t];
      if (idx != null) counts[idx] = (counts[idx] ?? 0) + 1;
    }
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
}

// ---------------------------------------------------------------------------
// Logistic regression (sklearn objective: 0.5*||w||^2 + C * sum s_i * logloss,
// intercept unregularised, class_weight='balanced', C=1). Optimised with Adam.
// classes sorted alphabetically: [fraudulent, genuine]; sigmoid = P(genuine).
// ---------------------------------------------------------------------------

class TrainedModel {
  final List<double> coef;
  final double intercept;
  TrainedModel(this.coef, this.intercept);
}

TrainedModel trainLogReg(
    List<Map<int, double>> X, List<int> yGenuine, int dim) {
  const c = 1.0;
  final n = X.length;
  final nGenuine = yGenuine.where((y) => y == 1).length;
  final nFraud = n - nGenuine;
  final wGenuine = n / (2.0 * nGenuine);
  final wFraud = n / (2.0 * nFraud);

  final w = List<double>.filled(dim, 0);
  var b = 0.0;
  // Adam state
  final mW = List<double>.filled(dim, 0);
  final vW = List<double>.filled(dim, 0);
  var mB = 0.0, vB = 0.0;
  const lr = 0.1, beta1 = 0.9, beta2 = 0.999, eps = 1e-8;

  double lastLoss = double.infinity;
  for (var step = 1; step <= 5000; step++) {
    final gW = List<double>.filled(dim, 0);
    var gB = 0.0;
    var loss = 0.0;

    for (var i = 0; i < n; i++) {
      var z = b;
      X[i].forEach((idx, x) => z += w[idx] * x);
      final p = 1 / (1 + math.exp(-z));
      final t = yGenuine[i].toDouble();
      final s = yGenuine[i] == 1 ? wGenuine : wFraud;
      final err = c * s * (p - t);
      X[i].forEach((idx, x) => gW[idx] += err * x);
      gB += err;
      final pc = p.clamp(1e-12, 1 - 1e-12);
      loss -= c * s * (t * math.log(pc) + (1 - t) * math.log(1 - pc));
    }
    for (var j = 0; j < dim; j++) {
      gW[j] += w[j]; // L2 on weights only
      loss += 0.5 * w[j] * w[j];
    }

    // Adam update
    final b1t = 1 - math.pow(beta1, step);
    final b2t = 1 - math.pow(beta2, step);
    for (var j = 0; j < dim; j++) {
      mW[j] = beta1 * mW[j] + (1 - beta1) * gW[j];
      vW[j] = beta2 * vW[j] + (1 - beta2) * gW[j] * gW[j];
      w[j] -= lr * (mW[j] / b1t) / (math.sqrt(vW[j] / b2t) + eps);
    }
    mB = beta1 * mB + (1 - beta1) * gB;
    vB = beta2 * vB + (1 - beta2) * gB * gB;
    b -= lr * (mB / b1t) / (math.sqrt(vB / b2t) + eps);

    if (step % 500 == 0) {
      stdout.writeln('  step $step  loss ${loss.toStringAsFixed(4)}');
      if ((lastLoss - loss).abs() < 1e-6) break;
      lastLoss = loss;
    }
  }
  return TrainedModel(w, b);
}

// ---------------------------------------------------------------------------

void main() {
  final trainFile = File('ml/data/synthetic_training.csv');
  final evalFile = File('ml/data/real_eval.csv');

  // 1. Load training CSV.
  final rows = parseCsv(trainFile.readAsStringSync());
  final header = rows.first;
  final textCol = header.indexOf('text');
  final labelCol = header.indexOf('label');

  // 2. Stamp augmentation (idempotent: skip if stamp phrases already present).
  final alreadyAugmented =
      rows.skip(1).any((r) => r[textCol].contains('official date stamp'));
  if (alreadyAugmented) {
    stdout.writeln('Training CSV already stamp-augmented; leaving as is.');
  } else {
    var added = 0;
    for (var i = 1; i < rows.length; i++) {
      final s = stampSentence(rows[i][labelCol], i);
      if (s != null) {
        final t = rows[i][textCol];
        rows[i][textCol] =
            t.endsWith('.') ? '${t.substring(0, t.length - 1)}. $s.' : '$t. $s.';
        added++;
      }
    }
    trainFile.writeAsStringSync(
        rows.map((r) => r.map(csvField).join(',')).join('\n'));
    stdout.writeln('Stamp-augmented $added of ${rows.length - 1} rows.');
  }

  final texts = [for (final r in rows.skip(1)) r[textCol]];
  final labels = [for (final r in rows.skip(1)) r[labelCol]];

  // 3. Vectorise + train.
  final vec = Vectorizer()..fit(texts);
  stdout.writeln('Vocabulary: ${vec.vocabulary.length} terms. Training...');
  final X = [for (final t in texts) vec.transform(t)];
  final y = [for (final l in labels) l == 'genuine' ? 1 : 0];
  final model = trainLogReg(X, y, vec.vocabulary.length);

  // 4. Held-out evaluation on the sacred real specimens.
  final evalRows = parseCsv(evalFile.readAsStringSync());
  final eh = evalRows.first;
  final etc = eh.indexOf('text');
  final elc = eh.indexOf('label');
  var correct = 0, total = 0;
  stdout.writeln('\n== HELD-OUT EVAL (the honest metric) ==');
  for (final r in evalRows.skip(1)) {
    var z = model.intercept;
    vec.transform(r[etc]).forEach((idx, x) => z += model.coef[idx] * x);
    final pGenuine = 1 / (1 + math.exp(-z));
    final pred = pGenuine >= 0.5 ? 'genuine' : 'fraudulent';
    final ok = pred == r[elc];
    total++;
    if (ok) correct++;
    stdout.writeln('  ${ok ? "OK " : "XX "} true=${r[elc].padRight(11)} '
        'pred=${pred.padRight(11)} pGenuine=${pGenuine.toStringAsFixed(3)}  '
        '${r[etc].substring(0, math.min(44, r[etc].length))}...');
  }
  stdout.writeln('Out-of-distribution accuracy: $correct/$total');
  if (correct != total) {
    stdout.writeln('FAILED: held-out accuracy dropped. NOT exporting.');
    exit(1);
  }

  // 5. Export (same schema the app + tests consume).
  final export = {
    'classes': ['fraudulent', 'genuine'],
    'vocabulary': vec.vocabulary,
    'idf': vec.idf,
    'coef': model.coef,
    'intercept': model.intercept,
    'ngram_range': [1, 2],
    'sublinear_tf': true,
    'note': 'Inference = tf-idf transform + dot(coef, x) + intercept -> '
        'sigmoid. No ML runtime needed on device. Trained by '
        'tool/train_model.dart (stamp-concept augmented data).',
  };
  final json = jsonEncode(export);
  File('ml/models/model_export.json').writeAsStringSync(json);
  File('assets/ml/model_export.json').writeAsStringSync(json);

  final report = {
    'train_file': 'ml/data/synthetic_training.csv',
    'eval_file': 'ml/data/real_eval.csv',
    'model': 'tfidf (dart trainer)',
    'train_rows': texts.length,
    'train_label_balance': {
      'fraudulent': labels.where((l) => l == 'fraudulent').length,
      'genuine': labels.where((l) => l == 'genuine').length,
    },
    'stamp_concept_augmented': true,
    'held_out_accuracy': correct / total,
    'held_out_correct': correct,
    'held_out_total': total,
  };
  File('ml/eval_report.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
  stdout.writeln('\nExported ml/models/model_export.json, '
      'assets/ml/model_export.json and ml/eval_report.json');
}
