import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import '../../core/errors/app_error.dart';
import '../../domain/models/saca_models.dart';
import '../../domain/services/analysis_service.dart';
import '../../domain/services/clinical_vocabulary_service.dart';
import '../../domain/services/safety_rule_service.dart';
import 'mock_analysis_service.dart';
import 'xgb_m2cgen_runtime.dart';

enum DiagnosisModelMode { lrOnnx, xgbBundle }

class DiagnosisPrediction {
  const DiagnosisPrediction({
    required this.label,
    this.confidence,
    this.ranked = const <ConditionPrediction>[],
  });

  final String label;
  final double? confidence;
  final List<ConditionPrediction> ranked;
}

abstract interface class DiagnosisClassifier {
  Future<DiagnosisPrediction> predict(AnalysisRequest request);
}

class DiagnosisClassifierFactory {
  const DiagnosisClassifierFactory._();

  static DiagnosisClassifier create({
    DiagnosisModelMode mode = DiagnosisModelMode.lrOnnx,
    XgbScoreFunction? xgbScorer,
  }) {
    return switch (mode) {
      DiagnosisModelMode.lrOnnx => OnnxDiagnosisClassifier(),
      DiagnosisModelMode.xgbBundle => XgbBundleDiagnosisClassifier(
          scorer: xgbScorer ?? _missingXgbScorer,
        ),
    };
  }

  static List<double> _missingXgbScorer(List<double> input) {
    throw StateError(
      'XGBoost diagnosis scorer is staged but not enabled. Run parity checks '
      'and inject the generated scorer before selecting xgbBundle.',
    );
  }
}

typedef XgbScoreFunction = List<double> Function(List<double> input);

class OnnxDiagnosisClassifier implements DiagnosisClassifier {
  OnnxDiagnosisClassifier({
    OnnxRuntime? runtime,
    this.modelAsset = 'assets/models/diagnosis_lr_flutter.onnx',
    this.labelsAsset = 'assets/models/diagnosis_lr_flutter_labels.json',
    this.inferenceTimeout = const Duration(seconds: 5),
  }) : _runtime = runtime ?? OnnxRuntime();

  final OnnxRuntime _runtime;
  final String modelAsset;
  final String labelsAsset;
  final Duration inferenceTimeout;

  Future<OrtSession>? _sessionFuture;
  Future<List<String>>? _labelsFuture;

  @override
  Future<DiagnosisPrediction> predict(AnalysisRequest request) async {
    final session = await _session();
    final labels = await _labels();
    final inputs = <String, OrtValue>{
      'combined_text':
          await OrtValue.fromList(<String>[request.combinedInput], <int>[1, 1]),
      'language': await OrtValue.fromList(
          <String>[_languageValue(request.language)], <int>[1, 1]),
      'source':
          await OrtValue.fromList(const <String>['saca_app'], <int>[1, 1]),
    };

    Map<String, OrtValue>? outputs;
    try {
      outputs = await session.run(inputs).timeout(
            inferenceTimeout,
            onTimeout: () => throw TimeoutException(
              'ONNX inference timed out',
              inferenceTimeout,
            ),
          );
      final outputLabel = outputs['output_label'];
      if (outputLabel == null) {
        throw StateError(
          'ONNX output_label missing. Outputs: ${outputs.keys.join(', ')}',
        );
      }
      final labelValues = await outputLabel.asFlattenedList();
      final labelIndex = (labelValues.first as num).toInt();
      final label = _labelForIndex(labels, labelIndex);
      final ranked =
          await _rankedPredictions(outputs, labels, label, labelIndex);
      return DiagnosisPrediction(
        label: label,
        confidence: ranked.isEmpty ? null : ranked.first.confidence,
        ranked: ranked,
      );
    } finally {
      for (final input in inputs.values) {
        await input.dispose();
      }
      for (final output in outputs?.values ?? const <OrtValue>[]) {
        await output.dispose();
      }
    }
  }

  Future<OrtSession> _session() {
    return _sessionFuture ??= _runtime.createSessionFromAsset(modelAsset);
  }

  Future<List<String>> _labels() {
    return _labelsFuture ??= _loadLabels();
  }

  Future<List<String>> _loadLabels() async {
    final source = await rootBundle.loadString(labelsAsset);
    final json = jsonDecode(source) as Map<String, dynamic>;
    final classes = List<String>.from(
        json['classes'] as List<dynamic>? ?? const <String>[]);
    final task = json['task'] as String?;
    if (classes.isEmpty) {
      throw StateError('Diagnosis labels asset has no classes.');
    }
    if (task != null && task != 'diagnosis') {
      debugPrint(
          '[SACA] Classifier labels task=$task; treating classes as diagnosis labels.');
    }
    return classes;
  }

  String _labelForIndex(List<String> labels, int index) {
    if (index < 0 || index >= labels.length) {
      throw RangeError.index(
          index, labels, 'index', 'Classifier label index out of range');
    }
    return labels[index];
  }

  Future<List<ConditionPrediction>> _rankedPredictions(
    Map<String, OrtValue> outputs,
    List<String> labels,
    String fallbackLabel,
    int fallbackIndex,
  ) async {
    final probabilityOutput = outputs['output_probability'];
    final probabilities = probabilityOutput == null
        ? const <double>[]
        : await _probabilityList(probabilityOutput, labels.length);
    if (probabilities.isEmpty) {
      return <ConditionPrediction>[
        ConditionPrediction(label: fallbackLabel, rank: 1),
      ];
    }

    final indexed = <({int index, double probability})>[
      for (var i = 0; i < probabilities.length; i++)
        (index: i, probability: probabilities[i]),
    ]..sort((a, b) => b.probability.compareTo(a.probability));

    if (indexed.every((item) => item.index != fallbackIndex)) {
      indexed.insert(0, (index: fallbackIndex, probability: 0));
    }

    return <ConditionPrediction>[
      for (var rank = 0; rank < indexed.take(3).length; rank++)
        ConditionPrediction(
          label: _labelForIndex(labels, indexed[rank].index),
          rank: rank + 1,
          confidence: indexed[rank].probability,
        ),
    ];
  }

  Future<List<double>> _probabilityList(OrtValue value, int labelCount) async {
    final flattened = await value.asFlattenedList();
    if (flattened.isEmpty) return const <double>[];
    final first = flattened.first;
    if (first is Map) {
      final probabilities = List<double>.filled(labelCount, 0);
      first.forEach((key, probability) {
        final index = (key as num).toInt();
        if (index >= 0 && index < labelCount) {
          probabilities[index] = (probability as num).toDouble();
        }
      });
      return probabilities;
    }
    if (flattened.every((item) => item is num)) {
      return flattened.map((item) => (item as num).toDouble()).toList();
    }
    return const <double>[];
  }

  String _languageValue(SacaLanguage language) {
    return switch (language) {
      SacaLanguage.english => 'english',
      SacaLanguage.gurindji => 'gurindji',
    };
  }
}

class XgbBundleDiagnosisClassifier implements DiagnosisClassifier {
  XgbBundleDiagnosisClassifier({
    required XgbScoreFunction scorer,
    this.bundleAsset = 'assets/models/classifier-xgb-best/bundle.json',
  }) : _scorer = scorer;

  final XgbScoreFunction _scorer;
  final String bundleAsset;

  Future<XgbM2cgenBundle>? _bundleFuture;

  @override
  Future<DiagnosisPrediction> predict(AnalysisRequest request) async {
    final bundle = await _bundle();
    final preprocessor = XgbM2cgenPreprocessor(bundle);
    final prediction = preprocessor.predict(
      XgbInputRecord(
        combinedText: request.combinedInput,
        categorical: <String, String?>{
          'language': _languageValue(request.language),
          'source': 'saca_app',
        },
      ),
      _scorer,
    );
    final ranked = <ConditionPrediction>[
      for (var i = 0; i < prediction.probabilities.length; i++)
        ConditionPrediction(
          label: bundle.classes[i],
          rank: i + 1,
          confidence: prediction.probabilities[i],
        ),
    ]..sort((a, b) => (b.confidence ?? 0).compareTo(a.confidence ?? 0));

    return DiagnosisPrediction(
      label: prediction.label,
      confidence: prediction.confidence,
      ranked: <ConditionPrediction>[
        for (var i = 0; i < ranked.take(3).length; i++)
          ConditionPrediction(
            label: ranked[i].label,
            rank: i + 1,
            confidence: ranked[i].confidence,
          ),
      ],
    );
  }

  Future<XgbM2cgenBundle> _bundle() {
    return _bundleFuture ??= loadXgbM2cgenBundleAsset(bundleAsset);
  }

  String _languageValue(SacaLanguage language) {
    return switch (language) {
      SacaLanguage.english => 'english',
      SacaLanguage.gurindji => 'gurindji',
    };
  }
}

class OnDeviceDiagnosisAnalysisService implements AnalysisService {
  OnDeviceDiagnosisAnalysisService({
    DiagnosisClassifier? classifier,
    AnalysisService? fallback,
    SafetyRuleService? safetyRules,
    ClinicalVocabularyService? vocabulary,
  })  : _classifier = classifier ?? DiagnosisClassifierFactory.create(),
        _fallback = fallback ?? MockAnalysisService(vocabulary: vocabulary),
        _safetyRules = safetyRules ?? const SafetyRuleService(),
        _vocabulary = vocabulary ?? const ClinicalVocabularyService.empty();

  final DiagnosisClassifier _classifier;
  final AnalysisService _fallback;
  final SafetyRuleService _safetyRules;
  final ClinicalVocabularyService _vocabulary;

  @override
  Future<AppResult<AnalysisResult>> analyse(AnalysisRequest request) async {
    final normalizedRequest = _vocabulary.normalizeRequest(request);
    final fallbackResult = await _fallback.analyse(normalizedRequest);
    if (!fallbackResult.isSuccess || fallbackResult.value == null) {
      return fallbackResult;
    }
    final fallbackValue = fallbackResult.value!;
    if (fallbackValue.isEmergency ||
        fallbackValue.disease == 'No clear illness detected') {
      return fallbackResult;
    }

    try {
      final prediction = await _classifier.predict(normalizedRequest);
      final mlResult = fallbackValue.copyWith(
        disease: _humanizeDisease(prediction.label),
        predictions: _humanizedPredictions(prediction),
      );
      return AppResult.success(_safetyRules.apply(normalizedRequest, mlResult));
    } catch (error, stackTrace) {
      debugPrint(
          '[SACA] Diagnosis classifier unavailable, using fallback: $error');
      debugPrintStack(stackTrace: stackTrace);
      return fallbackResult;
    }
  }

  String _humanizeDisease(String label) {
    return label
        .split(RegExp(r'[ _-]+'))
        .where((word) => word.isNotEmpty)
        .map((word) => word.length == 1
            ? word.toUpperCase()
            : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  List<ConditionPrediction> _humanizedPredictions(
      DiagnosisPrediction prediction) {
    final source = prediction.ranked.isEmpty
        ? <ConditionPrediction>[
            ConditionPrediction(
              label: prediction.label,
              rank: 1,
              confidence: prediction.confidence,
            ),
          ]
        : prediction.ranked;
    return <ConditionPrediction>[
      for (final item in source.take(3))
        ConditionPrediction(
          label: _humanizeDisease(item.label),
          rank: item.rank,
          confidence: item.confidence,
        ),
    ];
  }
}
