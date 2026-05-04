import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saca_demo/core/errors/app_error.dart';
import 'package:saca_demo/domain/models/lexicon_entry.dart';
import 'package:saca_demo/domain/models/saca_models.dart';
import 'package:saca_demo/domain/services/clinical_vocabulary_service.dart';
import 'package:saca_demo/infrastructure/analysis/mock_analysis_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MockAnalysisService', () {
    late ClinicalVocabularyService vocabulary;

    setUpAll(() async {
      final source = await rootBundle.loadString(
        'assets/data/gurindji_lexicon.json',
      );
      vocabulary = ClinicalVocabularyService.fromEntries(
        LexiconEntry.listFromJson(source),
      );
    });

    test('maps fever and related throat symptoms to influenza guidance',
        () async {
      final service = MockAnalysisService();

      final result = await service.analyse(
        const AnalysisRequest(
          language: SacaLanguage.english,
          inputMethod: InputMethod.text,
          transcript: '',
          textInput: 'fever',
          selectedSymptomIds: <String>{},
          selectedBodyAreaIds: <String>{},
          answers: <String, String>{
            'severity': '4',
            'related_symptoms': 'sore_throat|headache',
          },
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(result.value?.disease, 'Influenza');
      expect(result.value?.severity, SeverityLevel.mild);
      expect(result.value?.isEmergency, isFalse);
    });

    test('overrides red flags with emergency Call 000 guidance', () async {
      final service = MockAnalysisService();

      final result = await service.analyse(
        const AnalysisRequest(
          language: SacaLanguage.english,
          inputMethod: InputMethod.text,
          transcript: '',
          textInput: 'I have chest pain and cannot breathe',
          selectedSymptomIds: <String>{},
          selectedBodyAreaIds: <String>{},
          answers: <String, String>{'severity': '8'},
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(result.value?.disease, 'Urgent symptoms');
      expect(result.value?.severity, SeverityLevel.emergency);
      expect(result.value?.isEmergency, isTrue);
      expect(result.value?.guidance.first, contains('Call 000'));
    });

    test('does not treat minor bleeding mentions as emergency red flags',
        () async {
      final service = MockAnalysisService();

      final result = await service.analyse(
        const AnalysisRequest(
          language: SacaLanguage.english,
          inputMethod: InputMethod.text,
          transcript: '',
          textInput: 'small cut on hand no bleeding now',
          selectedSymptomIds: <String>{},
          selectedBodyAreaIds: <String>{},
          answers: <String, String>{'severity': '2'},
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(result.value?.isEmergency, isFalse);
      expect(result.value?.disease, isNot('Urgent symptoms'));
    });

    test('still escalates phrase-level blood red flags', () async {
      final service = MockAnalysisService();

      final result = await service.analyse(
        const AnalysisRequest(
          language: SacaLanguage.english,
          inputMethod: InputMethod.text,
          transcript: '',
          textInput: 'I am coughing blood',
          selectedSymptomIds: <String>{},
          selectedBodyAreaIds: <String>{},
          answers: <String, String>{'severity': '7'},
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(result.value?.disease, 'Urgent symptoms');
      expect(result.value?.isEmergency, isTrue);
    });

    test('does not force disease prediction for healthy/no-symptom input',
        () async {
      final service = MockAnalysisService();

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
      expect(result.value?.isEmergency, isFalse);
    });

    test('maps rash symptoms to skin guidance', () async {
      final service = MockAnalysisService();

      final result = await service.analyse(
        const AnalysisRequest(
          language: SacaLanguage.english,
          inputMethod: InputMethod.text,
          transcript: '',
          textInput: 'itchy rash on my arm',
          selectedSymptomIds: <String>{},
          selectedBodyAreaIds: <String>{},
          answers: <String, String>{'severity': '3'},
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(result.value?.disease, 'Skin irritation');
      expect(result.value?.severity, SeverityLevel.mild);
    });

    test('does not classify isolated headache as influenza', () async {
      final service = MockAnalysisService();

      final result = await service.analyse(
        const AnalysisRequest(
          language: SacaLanguage.english,
          inputMethod: InputMethod.text,
          transcript: '',
          textInput: 'headache only',
          selectedSymptomIds: <String>{'headache'},
          selectedBodyAreaIds: <String>{},
          answers: <String, String>{'severity': '3'},
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(result.value?.disease, isNot('Influenza'));
      expect(result.value?.isEmergency, isFalse);
    });

    test('returns typed failure for empty input', () async {
      final service = MockAnalysisService();

      final result = await service.analyse(
        const AnalysisRequest(
          language: SacaLanguage.english,
          inputMethod: InputMethod.text,
          transcript: '',
          textInput: '',
          selectedSymptomIds: <String>{},
          selectedBodyAreaIds: <String>{},
          answers: <String, String>{},
        ),
      );

      expect(result.isSuccess, isFalse);
      expect(result.failure?.kind, AppFailureKind.emptyInput);
    });

    test('normalizes Gurindji fever text to the same influenza result',
        () async {
      final service = MockAnalysisService(vocabulary: vocabulary);

      final result = await service.analyse(
        const AnalysisRequest(
          language: SacaLanguage.gurindji,
          inputMethod: InputMethod.text,
          transcript: '',
          textInput: 'makurrmakurr',
          selectedSymptomIds: <String>{},
          selectedBodyAreaIds: <String>{},
          answers: <String, String>{'severity': '4'},
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(result.value?.disease, 'Influenza');
    });

    test('normalizes Gurindji chest pain as emergency red flag', () async {
      final service = MockAnalysisService(vocabulary: vocabulary);

      final result = await service.analyse(
        const AnalysisRequest(
          language: SacaLanguage.gurindji,
          inputMethod: InputMethod.text,
          transcript: '',
          textInput: 'mangarli pung',
          selectedSymptomIds: <String>{},
          selectedBodyAreaIds: <String>{},
          answers: <String, String>{'severity': '8'},
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(result.value?.disease, 'Urgent symptoms');
      expect(result.value?.isEmergency, isTrue);
    });
  });
}
