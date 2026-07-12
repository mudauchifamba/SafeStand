import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:safestand/services/fraud_classifier.dart';

/// Minimal RFC-4180 CSV parser (quotes, embedded commas/newlines).
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

void main() {
  final classifier = FraudClassifier.fromJson(jsonDecode(
          File('ml/models/model_export.json').readAsStringSync())
      as Map<String, dynamic>);

  test(
      'Dart port reproduces the Python model: all real held-out specimens '
      'classified correctly', () {
    final rows = parseCsv(File('ml/data/real_eval.csv').readAsStringSync());
    final header = rows.first;
    final textCol = header.indexOf('text');
    final labelCol = header.indexOf('label');

    var correct = 0;
    var total = 0;
    final failures = <String>[];

    for (final row in rows.skip(1)) {
      final text = row[textCol];
      final label = row[labelCol];
      final p = classifier.fraudProbability(text);
      final predicted = p >= 0.5 ? 'fraudulent' : 'genuine';
      total++;
      if (predicted == label) {
        correct++;
      } else {
        failures.add(
            'expected $label got $predicted (p=${p.toStringAsFixed(3)}): '
            '${text.substring(0, 60)}...');
      }
    }

    expect(total, greaterThanOrEqualTo(10));
    expect(failures, isEmpty,
        reason: 'Dart inference disagrees with training labels:\n'
            '${failures.join('\n')}');
    expect(correct, total);
  });

  test('obviously fraudulent text scores high', () {
    final p = classifier.fraudProbability(
        'Offer letter. Pay USD 2000 cash only non-refundable to the '
        'cooperative treasurer. Title deeds will be processed once the area '
        'is regularised by council.');
    expect(p, greaterThan(0.5));
  });

  test('obviously genuine text scores low', () {
    final p = classifier.fraudProbability(
        'City of Harare offer of stand. Council resolution CH/RES/2025 '
        'refers. Held under General Plan, Diagram SG 2018, Surveyor General '
        'Harare. Payable to the council bank account, receipt issued. '
        'Registration verifiable at Registrar of Cooperative Societies.');
    expect(p, lessThan(0.5));
  });

  test('stamp concept: an official dated/referenced stamp reads safer than '
      'an imitation stamp on the same document', () {
    const base = 'Offer of stand 400, 250 sqm. USD 2000 payable. ';
    final pOfficial = classifier.fraudProbability(
        '$base Official date stamp: City of Harare Housing and Community '
        'Services 12 MAR 2026 ref CH/HD/812.');
    final pImitation = classifier.fraudProbability(
        '$base Rubber stamp reads APPROVED with no date and no reference.');
    expect(pOfficial, lessThan(pImitation),
        reason: 'official stamp text should lower fraud probability '
            'relative to an imitation stamp');
    final pMisspelt = classifier.fraudProbability(
        '$base Stamp reads OFICIAL STAMP of the cooperative, no council '
        'stamp.');
    expect(pOfficial, lessThan(pMisspelt));
  });

  test('top contributions are inspectable and non-empty', () {
    final contribs = classifier.topContributions(
        'cash only non-refundable title deeds once the area is regularised');
    expect(contribs, isNotEmpty);
  });
}
