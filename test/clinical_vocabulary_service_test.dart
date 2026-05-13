import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saca/domain/models/lexicon_entry.dart';
import 'package:saca/domain/models/saca_models.dart';
import 'package:saca/domain/services/clinical_vocabulary_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<LexiconEntry> entries;
  late ClinicalVocabularyService vocabulary;

  setUpAll(() async {
    final source = await rootBundle.loadString(
      'assets/data/gurindji_lexicon.json',
    );
    entries = LexiconEntry.listFromJson(source);
    vocabulary = ClinicalVocabularyService.fromEntries(entries);
  });

  test('parses dictionary asset and keeps entry types', () {
    expect(entries.length, 771);
    expect(entries.where((entry) => entry.type == 'body'), isNotEmpty);
    expect(entries.where((entry) => entry.type == 'symptom'), isNotEmpty);
    expect(entries.where((entry) => entry.type == 'disease'), isNotEmpty);
  });

  test('maps standardized core clinical terms from the dictionary', () {
    expect(vocabulary.symptomTerm('fever')?.gurindjiLabel, 'makurrmakurr');
    expect(vocabulary.symptomTerm('cough')?.gurindjiLabel, 'kulyurrk');
    expect(vocabulary.symptomTerm('vomiting')?.gurindjiLabel, 'kurlpak yuwa-');
    expect(vocabulary.bodyAreaTerm('throat')?.gurindjiLabel, 'ngirlkirri');
    expect(vocabulary.bodyAreaTerm('chest')?.gurindjiLabel, 'mangarli');
    expect(vocabulary.bodyAreaTerm('stomach')?.gurindjiLabel, 'majul');
    expect(vocabulary.bodyAreaTerm('head')?.gurindjiLabel, 'ngarlaka');
    expect(vocabulary.bodyAreaTerm('heart')?.gurindjiLabel, 'mangarli');
    expect(vocabulary.symptomTerm('headache')?.gurindjiLabel, 'ngarlaka pung');
    expect(
      vocabulary.symptomTerm('stomachache')?.gurindjiLabel,
      'majul turlung',
    );
    expect(
      vocabulary.symptomTerm('sore_throat')?.gurindjiLabel,
      'ngirlkirri pung',
    );
    expect(
      vocabulary.symptomTerm('chest_pain')?.gurindjiLabel,
      'mangarli pung',
    );
    expect(vocabulary.normalizeText('pung'), contains('pain'));
    expect(vocabulary.normalizeText('kangkurr ma-'), contains('pain'));
    expect(vocabulary.normalizeText('walawupkarra'), contains('bleeding'));
  });

  test('falls back to English when a safe dictionary term is missing', () {
    const symptom = Symptom(id: 'bloating', label: 'Bloating');
    expect(vocabulary.symptomLabel(SacaLanguage.gurindji, symptom), 'Bloating');
  });

  test('normalizes Gurindji text into canonical analysis terms', () {
    final normalized = vocabulary.normalizeRequest(
      const AnalysisRequest(
        language: SacaLanguage.gurindji,
        inputMethod: InputMethod.text,
        transcript: '',
        textInput: 'makurrmakurr',
        selectedSymptomIds: <String>{},
        selectedBodyAreaIds: <String>{},
        answers: <String, String>{},
      ),
    );

    expect(normalized.combinedInput, contains('fever'));
  });

  test('normalizes priority Gurindji symptom phrases to canonical tokens', () {
    expect(vocabulary.normalizeText('kulyurrk'), contains('cough'));
    expect(vocabulary.normalizeText('kurlpak yuwa-'), contains('vomiting'));
    expect(vocabulary.normalizeText('ngarlaka pung'), contains('headache'));
    expect(
      vocabulary.normalizeText('ngirlkirri pung'),
      contains('sore throat'),
    );
    expect(vocabulary.normalizeText('mangarli pung'), contains('chest pain'));
    expect(vocabulary.normalizeText('majul pung'), contains('stomachache'));
    expect(vocabulary.normalizeText('majul turlung'), contains('stomachache'));
    expect(
      vocabulary.normalizeText('walawupkarra'),
      contains('severe bleeding'),
    );
  });

  test('normalizes mixed Gurindji and English input without changing ids', () {
    final normalized = vocabulary.normalizeRequest(
      const AnalysisRequest(
        language: SacaLanguage.gurindji,
        inputMethod: InputMethod.text,
        transcript: 'I feel makurrmakurr and kulyurrk',
        textInput: 'ngarlaka pung',
        selectedSymptomIds: <String>{'fever'},
        selectedBodyAreaIds: <String>{'head'},
        answers: <String, String>{'related_symptoms': 'ngirlkirri pung'},
      ),
    );

    expect(normalized.transcript, contains('fever'));
    expect(normalized.transcript, contains('cough'));
    expect(normalized.textInput, contains('headache'));
    expect(normalized.answers['related_symptoms'], contains('sore throat'));
    expect(normalized.selectedSymptomIds, <String>{'fever'});
    expect(normalized.selectedBodyAreaIds, <String>{'head'});
  });

  test('preserves unknown text when no safe mapping exists', () {
    const unknown = 'unmapped community phrase';

    expect(vocabulary.normalizeText(unknown), unknown);
  });
}
