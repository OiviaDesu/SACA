import 'package:flutter_test/flutter_test.dart';
import 'package:saca_demo/domain/models/saca_models.dart';
import 'package:saca_demo/infrastructure/analysis/mock_analysis_service.dart';
import 'package:saca_demo/infrastructure/analysis/on_device_diagnosis_analysis_service.dart';

void main() {
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
