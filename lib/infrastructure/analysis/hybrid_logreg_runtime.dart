import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;

import '../../domain/models/saca_models.dart';
import '../../domain/services/diagnosis_classifier.dart';

class HybridLogRegDiagnosisClassifier implements DiagnosisClassifier {
  HybridLogRegDiagnosisClassifier({
    this.bundleAsset = 'assets/models/saca-hybrid-logreg-v1/bundle.json',
  });

  final String bundleAsset;
  Future<_HybridLogRegBundle>? _bundleFuture;

  @override
  Future<DiagnosisPrediction> predict(AnalysisRequest request) async {
    final bundle = await _bundle();
    final features = bundle.vectorize(request);
    final probabilities = bundle.predictProbabilities(features);
    final ranked = <ConditionPrediction>[
      for (var index = 0; index < probabilities.length; index++)
        ConditionPrediction(
          label: bundle.classes[index],
          rank: index + 1,
          confidence: probabilities[index],
        ),
    ]..sort((a, b) => (b.confidence ?? 0).compareTo(a.confidence ?? 0));
    final top = ranked.take(3).toList();
    return DiagnosisPrediction(
      label: top.first.label,
      confidence: top.first.confidence,
      ranked: <ConditionPrediction>[
        for (var index = 0; index < top.length; index++)
          ConditionPrediction(
            label: top[index].label,
            rank: index + 1,
            confidence: top[index].confidence,
          ),
      ],
    );
  }

  Future<_HybridLogRegBundle> _bundle() {
    return _bundleFuture ??= _HybridLogRegBundle.load(bundleAsset);
  }
}

class _HybridLogRegBundle {
  _HybridLogRegBundle({
    required this.vocabulary,
    required this.vocabularyIndex,
    required this.idf,
    required this.symptomColumns,
    required this.severityCategories,
    required this.indicatorColumns,
    required this.classes,
    required this.coefficients,
    required this.intercepts,
    required this.gurindjiEntries,
  });

  final List<String> vocabulary;
  final Map<String, int> vocabularyIndex;
  final List<double> idf;
  final List<String> symptomColumns;
  final List<String> severityCategories;
  final List<String> indicatorColumns;
  final List<String> classes;
  final List<List<double>> coefficients;
  final List<double> intercepts;
  final List<_GurindjiEntry> gurindjiEntries;

  static Future<_HybridLogRegBundle> load(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final vocabulary = List<String>.from(json['tfidf']['vocabulary'] as List);
    return _HybridLogRegBundle(
      vocabulary: vocabulary,
      vocabularyIndex: {
        for (var index = 0; index < vocabulary.length; index++)
          vocabulary[index]: index,
      },
      idf: _doubleList(json['tfidf']['idf'] as List),
      symptomColumns: List<String>.from(json['symptom_columns'] as List),
      severityCategories:
          List<String>.from(json['severity_categories'] as List),
      indicatorColumns: List<String>.from(json['indicator_columns'] as List),
      classes: List<String>.from(json['classes'] as List),
      coefficients: [
        for (final row in json['coef'] as List) _doubleList(row as List),
      ],
      intercepts: _doubleList(json['intercept'] as List),
      gurindjiEntries: [
        for (final entry in json['gurindji_entries'] as List)
          _GurindjiEntry.fromJson(Map<String, dynamic>.from(entry as Map)),
      ],
    );
  }

  List<double> vectorize(AnalysisRequest request) {
    final normalized = _normalizeGurindjiIfNeeded(request);
    final text = [
      normalized,
      ...request.selectedSymptomIds.map(_symptomIdText),
      ...request.selectedBodyAreaIds,
    ].where((value) => value.trim().isNotEmpty).join(' ');
    final tfidf = _tfidf(text);
    final symptoms = _symptoms(request, normalized);
    final severity = _severity(request);
    final indicators = _indicators(request);
    return <double>[...tfidf, ...symptoms, ...severity, ...indicators];
  }

  List<double> predictProbabilities(List<double> features) {
    final scores = <double>[
      for (var classIndex = 0; classIndex < classes.length; classIndex++)
        _dot(coefficients[classIndex], features) + intercepts[classIndex],
    ];
    final maxScore = scores.reduce(math.max);
    final expScores = [for (final score in scores) math.exp(score - maxScore)];
    final total = expScores.fold<double>(0, (sum, value) => sum + value);
    return [for (final value in expScores) value / total];
  }

  List<double> _tfidf(String text) {
    final counts = <int, int>{};
    for (final token in _tokens(text)) {
      final index = vocabularyIndex[token];
      if (index == null) continue;
      counts[index] = (counts[index] ?? 0) + 1;
    }
    final vector = List<double>.filled(vocabulary.length, 0);
    var norm = 0.0;
    for (final entry in counts.entries) {
      final value = entry.value * idf[entry.key];
      vector[entry.key] = value;
      norm += value * value;
    }
    if (norm == 0) return vector;
    final scale = math.sqrt(norm);
    return [for (final value in vector) value / scale];
  }

  List<double> _symptoms(AnalysisRequest request, String normalizedText) {
    final active = <String>{
      for (final id in request.selectedSymptomIds) _symptomIdText(id),
      ..._inferredSymptoms(normalizedText),
    };
    return [
      for (final column in symptomColumns)
        active.any((value) => value == column || column.contains(value))
            ? 1.0
            : 0.0,
    ];
  }

  List<double> _severity(AnalysisRequest request) {
    final value = int.tryParse(request.answers['severity'] ?? '');
    final severity = value == null
        ? 'unknown'
        : value >= 8
            ? 'severe'
            : value >= 5
                ? 'moderate'
                : 'mild';
    return [
      for (final category in severityCategories)
        category == severity ? 1.0 : 0.0
    ];
  }

  List<double> _indicators(AnalysisRequest request) {
    return [
      request.answers.containsKey('severity') ? 1.0 : 0.0,
      request.selectedSymptomIds.isNotEmpty ? 1.0 : 0.0,
      request.inputMethod == InputMethod.text ||
              request.inputMethod == InputMethod.voice
          ? 1.0
          : 0.0,
      0.0,
    ];
  }

  String _normalizeGurindjiIfNeeded(AnalysisRequest request) {
    final base = request.combinedInput;
    if (request.language != SacaLanguage.gurindji) return base;
    final normalized = _normalizeText(base);
    final appended = <String>[];
    for (final entry in gurindjiEntries) {
      if (entry.canonicalText.isEmpty) continue;
      if (RegExp('(?<!\\w)${RegExp.escape(entry.gurindjiNorm)}(?!\\w)')
          .hasMatch(normalized)) {
        appended.add(entry.canonicalText);
      }
    }
    return <String>{base, ...appended}.join(' ');
  }

  Iterable<String> _inferredSymptoms(String text) sync* {
    final normalized = _normalizeText(text);
    for (final column in symptomColumns) {
      if (RegExp('(?<!\\w)${RegExp.escape(column)}(?!\\w)')
          .hasMatch(normalized)) {
        yield column;
      }
    }
  }

  String _symptomIdText(String id) {
    return switch (id) {
      'sore_throat' => 'sore throat',
      'chest_pain' => 'sharp chest pain',
      'breathing_trouble' => 'shortness of breath',
      'nausea_vomiting' => 'nausea vomiting',
      'stomachache' => 'abdominal pain',
      _ => id.replaceAll('_', ' '),
    };
  }
}

class _GurindjiEntry {
  const _GurindjiEntry({
    required this.gurindjiNorm,
    required this.canonicalText,
  });

  final String gurindjiNorm;
  final String canonicalText;

  factory _GurindjiEntry.fromJson(Map<String, dynamic> json) {
    return _GurindjiEntry(
      gurindjiNorm: json['gurindji_norm'] as String? ?? '',
      canonicalText: json['canonical_text'] as String? ?? '',
    );
  }
}

List<String> _tokens(String text) {
  return RegExp(r'\b\w\w+\b')
      .allMatches(_normalizeText(text))
      .map((match) => match.group(0)!)
      .toList();
}

String _normalizeText(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}

double _dot(List<double> left, List<double> right) {
  var sum = 0.0;
  for (var index = 0; index < left.length; index++) {
    sum += left[index] * right[index];
  }
  return sum;
}

List<double> _doubleList(List<dynamic> values) {
  return [for (final value in values) (value as num).toDouble()];
}
