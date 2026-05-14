import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:saca/domain/models/saca_models.dart';
import 'package:saca/domain/services/diagnosis_classifier.dart';
import 'package:saca/infrastructure/analysis/mock_analysis_service.dart';
import 'package:saca/infrastructure/analysis/on_device_diagnosis_analysis_service.dart';
import 'package:saca/infrastructure/analysis/xgb_m2cgen_runtime.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OnDeviceDiagnosisAnalysisService', () {
    test('uses classifier disease while keeping safety guidance', () async {
      final service = OnDeviceDiagnosisAnalysisService(
        classifier: const _FakeDiagnosisClassifier('common cold'),
        fallback: MockAnalysisService(),
      );

      final result = await service.analyse(
        const AnalysisRequest(
          language: SacaLanguage.english,
          inputMethod: InputMethod.text,
          transcript: '',
          textInput: 'fever cough sore throat',
          selectedSymptomIds: <String>{},
          selectedBodyAreaIds: <String>{},
          answers: <String, String>{'severity': '4'},
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(result.value?.disease, 'Common Cold');
      expect(result.value?.severity, SeverityLevel.mild);
      expect(result.value?.isEmergency, isFalse);
      expect(result.value?.guidance, isNotEmpty);
    });

    test('serious infectious top disease raises severity floor', () async {
      final service = OnDeviceDiagnosisAnalysisService(
        classifier: const _FakeDiagnosisClassifier('malaria'),
        fallback: MockAnalysisService(),
      );

      final result = await service.analyse(
        const AnalysisRequest(
          language: SacaLanguage.english,
          inputMethod: InputMethod.text,
          transcript: '',
          textInput: 'fever with chills and sweating, weak and cold',
          selectedSymptomIds: <String>{},
          selectedBodyAreaIds: <String>{},
          answers: <String, String>{'severity': '7'},
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(result.value?.disease, 'Malaria');
      expect(result.value?.severity, SeverityLevel.moderate);
    });

    test('high user severity still stays severe for ML disease', () async {
      final service = OnDeviceDiagnosisAnalysisService(
        classifier: const _FakeDiagnosisClassifier('malaria'),
        fallback: MockAnalysisService(),
      );

      final result = await service.analyse(
        const AnalysisRequest(
          language: SacaLanguage.english,
          inputMethod: InputMethod.text,
          transcript: '',
          textInput: 'fever with chills and sweating',
          selectedSymptomIds: <String>{},
          selectedBodyAreaIds: <String>{},
          answers: <String, String>{'severity': '8'},
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(result.value?.severity, SeverityLevel.severe);
    });

    test('red flags override classifier disease', () async {
      final service = OnDeviceDiagnosisAnalysisService(
        classifier: const _FakeDiagnosisClassifier('hypertension'),
        fallback: MockAnalysisService(),
      );

      final result = await service.analyse(
        const AnalysisRequest(
          language: SacaLanguage.english,
          inputMethod: InputMethod.text,
          transcript: '',
          textInput: 'chest pain and cannot breathe',
          selectedSymptomIds: <String>{},
          selectedBodyAreaIds: <String>{},
          answers: <String, String>{'severity': '9'},
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(result.value?.disease, 'Urgent symptoms');
      expect(result.value?.severity, SeverityLevel.emergency);
      expect(result.value?.guidance.first, contains('Call 000'));
    });

    test('healthy input skips classifier prediction', () async {
      final classifier = _CountingDiagnosisClassifier('common cold');
      final service = OnDeviceDiagnosisAnalysisService(
        classifier: classifier,
        fallback: MockAnalysisService(),
      );

      final result = await service.analyse(
        const AnalysisRequest(
          language: SacaLanguage.english,
          inputMethod: InputMethod.text,
          transcript: '',
          textInput: 'I feel fine and have no symptoms',
          selectedSymptomIds: <String>{},
          selectedBodyAreaIds: <String>{},
          answers: <String, String>{},
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(result.value?.disease, 'No clear illness detected');
      expect(classifier.callCount, 0);
    });

    test('falls back when classifier throws', () async {
      final service = OnDeviceDiagnosisAnalysisService(
        classifier: const _ThrowingDiagnosisClassifier(),
        fallback: MockAnalysisService(),
      );

      final result = await service.analyse(
        const AnalysisRequest(
          language: SacaLanguage.english,
          inputMethod: InputMethod.text,
          transcript: '',
          textInput: 'fever',
          selectedSymptomIds: <String>{},
          selectedBodyAreaIds: <String>{},
          answers: <String, String>{'severity': '4'},
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(result.value?.disease, 'Influenza');
    });

    test('falls back when classifier inference times out', () async {
      final service = OnDeviceDiagnosisAnalysisService(
        classifier: const _TimeoutDiagnosisClassifier(),
        fallback: MockAnalysisService(),
      );

      final result = await service.analyse(
        const AnalysisRequest(
          language: SacaLanguage.english,
          inputMethod: InputMethod.text,
          transcript: '',
          textInput: 'fever cough',
          selectedSymptomIds: <String>{},
          selectedBodyAreaIds: <String>{},
          answers: <String, String>{'severity': '4'},
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(result.value?.disease, 'Influenza');
    });

    test('default classifier factory uses fallback hybrid classifier', () {
      final classifier = DiagnosisClassifierFactory.create();

      expect(classifier, isA<FallbackDiagnosisClassifier>());
    });

    test('XGBoost bundle detects Git LFS pointer assets', () {
      expect(
        isGitLfsPointer(
          'version https://git-lfs.github.com/spec/v1\n'
          'oid sha256:abc\n'
          'size 123\n',
        ),
        isTrue,
      );
      expect(isGitLfsPointer('{"bundle_version":1}'), isFalse);
    });

    test('confidence level maps 70 and 40 percent thresholds', () {
      expect(
        const ConditionPrediction(label: 'a', rank: 1, confidence: 0.70)
            .confidenceLevel,
        ConfidenceLevel.high,
      );
      expect(
        const ConditionPrediction(label: 'b', rank: 2, confidence: 0.40)
            .confidenceLevel,
        ConfidenceLevel.medium,
      );
      expect(
        const ConditionPrediction(label: 'c', rank: 3, confidence: 0.39)
            .confidenceLevel,
        ConfidenceLevel.low,
      );
    });
  });
}

class _FakeDiagnosisClassifier implements DiagnosisClassifier {
  const _FakeDiagnosisClassifier(this.label);

  final String label;

  @override
  Future<DiagnosisPrediction> predict(AnalysisRequest request) async {
    return DiagnosisPrediction(label: label, confidence: 0.9);
  }
}

class _CountingDiagnosisClassifier implements DiagnosisClassifier {
  _CountingDiagnosisClassifier(this.label);

  final String label;
  int callCount = 0;

  @override
  Future<DiagnosisPrediction> predict(AnalysisRequest request) async {
    callCount += 1;
    return DiagnosisPrediction(label: label, confidence: 0.9);
  }
}

class _ThrowingDiagnosisClassifier implements DiagnosisClassifier {
  const _ThrowingDiagnosisClassifier();

  @override
  Future<DiagnosisPrediction> predict(AnalysisRequest request) {
    throw StateError('classifier unavailable');
  }
}

class _TimeoutDiagnosisClassifier implements DiagnosisClassifier {
  const _TimeoutDiagnosisClassifier();

  @override
  Future<DiagnosisPrediction> predict(AnalysisRequest request) {
    throw TimeoutException('timed out');
  }
}
