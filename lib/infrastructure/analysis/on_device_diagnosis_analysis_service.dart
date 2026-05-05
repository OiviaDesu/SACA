import 'package:flutter/foundation.dart';

import '../../core/errors/app_error.dart';
import '../../domain/models/saca_models.dart';
import '../../domain/services/analysis_service.dart';
import '../../domain/services/clinical_vocabulary_service.dart';
import '../../domain/services/safety_rule_service.dart';
import 'mock_analysis_service.dart';
import 'xgb_m2cgen_runtime.dart';

enum DiagnosisModelMode { xgbBundle }

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
    DiagnosisModelMode mode = DiagnosisModelMode.xgbBundle,
  }) {
    return XgbBundleDiagnosisClassifier();
  }
}

class XgbBundleDiagnosisClassifier implements DiagnosisClassifier {
  XgbBundleDiagnosisClassifier({
    this.bundleAsset = 'assets/models/classifier-xgb-best/bundle.json',
  });

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
