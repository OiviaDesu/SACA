import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';

class XgbM2cgenTextFeature {
  const XgbM2cgenTextFeature({
    required this.column,
    required this.ngramRange,
    required this.sublinearTf,
    required this.vocabulary,
    required this.idf,
  });

  factory XgbM2cgenTextFeature.fromJson(Map<String, dynamic> json) {
    return XgbM2cgenTextFeature(
      column: json['column'] as String,
      ngramRange: List<int>.from(json['ngram_range'] as List<dynamic>),
      sublinearTf: json['sublinear_tf'] as bool? ?? false,
      vocabulary: Map<String, int>.from(json['vocabulary'] as Map),
      idf: List<double>.from(
        (json['idf'] as List<dynamic>)
            .map((value) => (value as num).toDouble()),
      ),
    );
  }

  final String column;
  final List<int> ngramRange;
  final bool sublinearTf;
  final Map<String, int> vocabulary;
  final List<double> idf;
}

class XgbM2cgenCategoricalFeature {
  const XgbM2cgenCategoricalFeature({
    required this.name,
    required this.offset,
    required this.categories,
  });

  factory XgbM2cgenCategoricalFeature.fromJson(Map<String, dynamic> json) {
    return XgbM2cgenCategoricalFeature(
      name: json['name'] as String,
      offset: json['offset'] as int,
      categories: List<String>.from(json['categories'] as List<dynamic>),
    );
  }

  final String name;
  final int offset;
  final List<String> categories;
}

class XgbM2cgenNumericFeature {
  const XgbM2cgenNumericFeature({
    required this.name,
    required this.offset,
    required this.fillValue,
  });

  factory XgbM2cgenNumericFeature.fromJson(Map<String, dynamic> json) {
    return XgbM2cgenNumericFeature(
      name: json['name'] as String,
      offset: json['offset'] as int,
      fillValue: (json['fill_value'] as num).toDouble(),
    );
  }

  final String name;
  final int offset;
  final double fillValue;
}

class XgbM2cgenBundle {
  const XgbM2cgenBundle({
    required this.classes,
    required this.featureCount,
    required this.textFeature,
    required this.categoricalFeatures,
    required this.numericFeatures,
  });

  factory XgbM2cgenBundle.fromJson(Map<String, dynamic> json) {
    return XgbM2cgenBundle(
      classes: List<String>.from(json['classes'] as List<dynamic>),
      featureCount: json['feature_count'] as int,
      textFeature: XgbM2cgenTextFeature.fromJson(
        Map<String, dynamic>.from(json['text_feature'] as Map),
      ),
      categoricalFeatures: List<XgbM2cgenCategoricalFeature>.from(
        (json['categorical_features'] as List<dynamic>).map(
          (feature) => XgbM2cgenCategoricalFeature.fromJson(
            Map<String, dynamic>.from(feature as Map),
          ),
        ),
      ),
      numericFeatures: List<XgbM2cgenNumericFeature>.from(
        (json['numeric_features'] as List<dynamic>).map(
          (feature) => XgbM2cgenNumericFeature.fromJson(
            Map<String, dynamic>.from(feature as Map),
          ),
        ),
      ),
    );
  }

  final List<String> classes;
  final int featureCount;
  final XgbM2cgenTextFeature textFeature;
  final List<XgbM2cgenCategoricalFeature> categoricalFeatures;
  final List<XgbM2cgenNumericFeature> numericFeatures;
}

class XgbInputRecord {
  const XgbInputRecord({
    required this.combinedText,
    this.categorical = const <String, String?>{},
    this.numeric = const <String, double?>{},
  });

  final String combinedText;
  final Map<String, String?> categorical;
  final Map<String, double?> numeric;
}

class XgbPrediction {
  const XgbPrediction({
    required this.label,
    required this.classIndex,
    required this.confidence,
    required this.probabilities,
  });

  final String label;
  final int classIndex;
  final double confidence;
  final List<double> probabilities;
}

class XgbM2cgenPreprocessor {
  const XgbM2cgenPreprocessor(this.bundle);

  final XgbM2cgenBundle bundle;

  List<double> buildInputVector(XgbInputRecord record) {
    final dense = List<double>.filled(bundle.featureCount, double.nan);
    _applyTextFeatures(dense, record.combinedText);
    _applyCategoricalFeatures(dense, record.categorical);
    _applyNumericFeatures(dense, record.numeric);
    return Float32List.fromList(dense).toList(growable: false);
  }

  XgbPrediction predict(
    XgbInputRecord record,
    List<double> Function(List<double> input) scorer,
  ) {
    final probabilities = scorer(buildInputVector(record));
    var bestIndex = 0;
    var bestProbability = double.negativeInfinity;
    for (var i = 0; i < probabilities.length; i++) {
      if (probabilities[i] > bestProbability) {
        bestProbability = probabilities[i];
        bestIndex = i;
      }
    }

    return XgbPrediction(
      label: bundle.classes[bestIndex],
      classIndex: bestIndex,
      confidence: bestProbability,
      probabilities: probabilities,
    );
  }

  void _applyTextFeatures(List<double> dense, String text) {
    final counts = <String, int>{};
    final ngrams = charWbNgrams(
      text,
      minN: bundle.textFeature.ngramRange.first,
      maxN: bundle.textFeature.ngramRange.last,
    );
    for (final ngram in ngrams) {
      counts.update(ngram, (value) => value + 1, ifAbsent: () => 1);
    }

    final weighted = <int, double>{};
    counts.forEach((ngram, count) {
      final featureIndex = bundle.textFeature.vocabulary[ngram];
      if (featureIndex == null) {
        return;
      }
      final tf = bundle.textFeature.sublinearTf
          ? 1.0 + math.log(count.toDouble())
          : count.toDouble();
      weighted[featureIndex] = tf * bundle.textFeature.idf[featureIndex];
    });

    var norm = 0.0;
    for (final value in weighted.values) {
      norm += value * value;
    }
    norm = math.sqrt(norm);
    if (norm <= 0) {
      return;
    }

    weighted.forEach((featureIndex, value) {
      dense[featureIndex] = value / norm;
    });
  }

  void _applyCategoricalFeatures(
    List<double> dense,
    Map<String, String?> categorical,
  ) {
    for (final feature in bundle.categoricalFeatures) {
      final candidateValue = categorical[feature.name];
      if (candidateValue == null || candidateValue.trim().isEmpty) {
        continue;
      }
      final categoryIndex = feature.categories.indexOf(candidateValue);
      if (categoryIndex < 0) {
        continue;
      }
      dense[feature.offset + categoryIndex] = 1.0;
    }
  }

  void _applyNumericFeatures(
    List<double> dense,
    Map<String, double?> numeric,
  ) {
    for (final feature in bundle.numericFeatures) {
      final value = numeric[feature.name] ?? feature.fillValue;
      dense[feature.offset] = value;
    }
  }
}

Future<XgbM2cgenBundle> loadXgbM2cgenBundleAsset(String assetPath) async {
  final source = await rootBundle.loadString(assetPath);
  return XgbM2cgenBundle.fromJson(
    Map<String, dynamic>.from(jsonDecode(source) as Map),
  );
}

List<String> charWbNgrams(
  String text, {
  required int minN,
  required int maxN,
}) {
  final normalized = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.isEmpty) {
    return const <String>[];
  }

  final ngrams = <String>[];
  for (final word in normalized.split(' ')) {
    if (word.isEmpty) {
      continue;
    }
    final paddedWord = ' $word ';
    final wordLength = paddedWord.length;
    for (var n = minN; n <= maxN; n++) {
      var offset = 0;
      ngrams.add(
        paddedWord.substring(offset, math.min(wordLength, offset + n)),
      );
      while (offset + n < wordLength) {
        offset += 1;
        ngrams.add(
          paddedWord.substring(offset, math.min(wordLength, offset + n)),
        );
      }
      if (offset == 0) {
        break;
      }
    }
  }
  return ngrams;
}
