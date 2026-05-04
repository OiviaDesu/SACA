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

class DiagnosisPrediction {
  const DiagnosisPrediction({required this.label, this.confidence});

  final String label;
  final double? confidence;
}

abstract interface class DiagnosisClassifier {
  Future<DiagnosisPrediction> predict(AnalysisRequest request);
}

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
      return DiagnosisPrediction(label: label);
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
  })  : _classifier = classifier ?? OnnxDiagnosisClassifier(),
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
}
