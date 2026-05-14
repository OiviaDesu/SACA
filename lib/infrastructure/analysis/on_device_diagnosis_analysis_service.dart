import 'package:flutter/foundation.dart';

import '../../core/runtime/runtime_acceleration_policy.dart';
import '../../core/errors/app_error.dart';
import '../../domain/models/saca_models.dart';
import '../../domain/services/analysis_service.dart';
import '../../domain/services/clinical_vocabulary_service.dart';
import '../../domain/services/diagnosis_classifier.dart';
import '../../domain/services/safety_rule_service.dart';
import 'diagnosis_result_formatter.dart';
import 'hybrid_logreg_runtime.dart';
import 'mock_analysis_service.dart';
import 'xgb_m2cgen_runtime.dart';

enum DiagnosisModelMode { hybridLogReg, xgbBundle }

class DiagnosisClassifierFactory {
  const DiagnosisClassifierFactory._();

  static DiagnosisClassifier create({
    DiagnosisModelMode mode = DiagnosisModelMode.hybridLogReg,
  }) {
    return switch (mode) {
      DiagnosisModelMode.hybridLogReg => FallbackDiagnosisClassifier(
          primary: HybridLogRegDiagnosisClassifier(),
          fallback: XgbBundleDiagnosisClassifier(),
        ),
      DiagnosisModelMode.xgbBundle => XgbBundleDiagnosisClassifier(),
    };
  }
}

class FallbackDiagnosisClassifier implements DiagnosisClassifier {
  const FallbackDiagnosisClassifier({
    required this.primary,
    required this.fallback,
  });

  final DiagnosisClassifier primary;
  final DiagnosisClassifier fallback;

  @override
  Future<DiagnosisPrediction> predict(AnalysisRequest request) async {
    try {
      return await primary.predict(request);
    } catch (error, stackTrace) {
      debugPrint(
          '[SACA] Hybrid LogReg unavailable, using XGB fallback: $error');
      debugPrintStack(stackTrace: stackTrace);
      return fallback.predict(request);
    }
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
    DiagnosisResultFormatter formatter = const DiagnosisResultFormatter(),
  })  : _classifier = classifier ?? DiagnosisClassifierFactory.create(),
        _fallback = fallback ?? MockAnalysisService(vocabulary: vocabulary),
        _safetyRules = safetyRules ?? const SafetyRuleService(),
        _vocabulary = vocabulary ?? const ClinicalVocabularyService.empty(),
        _formatter = formatter;

  final DiagnosisClassifier _classifier;
  final AnalysisService _fallback;
  final SafetyRuleService _safetyRules;
  final ClinicalVocabularyService _vocabulary;
  final DiagnosisResultFormatter _formatter;

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

    final acceleration = RuntimeAccelerationPolicy().choose(
      feature: RuntimeFeature.ml,
      cpuBackend: AccelerationBackend.cpu,
      unavailableReason: 'diagnosis classifier has no GPU provider',
    );
    debugPrint('[SACA] Diagnosis runtime ${acceleration.toLogFields()}');

    try {
      final prediction = await _classifier.predict(normalizedRequest);
      final mlSeverity = _maxSeverity(<SeverityLevel>[
        fallbackValue.severity,
        _severityFromUserAnswer(normalizedRequest),
        _minimumSeverityForDisease(prediction.label),
      ]);
      final mlResult = fallbackValue.copyWith(
        disease: _formatter.humanizeDisease(prediction.label),
        severity: mlSeverity,
        predictions: _formatter.humanizedPredictions(prediction),
      );
      return AppResult.success(_safetyRules.apply(normalizedRequest, mlResult));
    } catch (error, stackTrace) {
      debugPrint(
          '[SACA] Diagnosis classifier unavailable, using fallback: $error');
      debugPrintStack(stackTrace: stackTrace);
      return fallbackResult;
    }
  }

  SeverityLevel _severityFromUserAnswer(AnalysisRequest request) {
    final value = int.tryParse(request.answers['severity'] ?? '');
    if (value == null) return SeverityLevel.mild;
    if (value >= 8) return SeverityLevel.severe;
    if (value >= 5) return SeverityLevel.moderate;
    return SeverityLevel.mild;
  }

  SeverityLevel _minimumSeverityForDisease(String label) {
    final normalized = label.toLowerCase().replaceAll(RegExp(r'[_-]+'), ' ');
    const moderateFloorDiseases = <String>{
      'malaria',
      'dengue',
      'typhoid',
      'pneumonia',
      'jaundice',
    };
    return moderateFloorDiseases.any(normalized.contains)
        ? SeverityLevel.moderate
        : SeverityLevel.mild;
  }

  SeverityLevel _maxSeverity(List<SeverityLevel> values) {
    return values.reduce(
      (current, next) => next.index > current.index ? next : current,
    );
  }
}
