import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saca/domain/models/lexicon_entry.dart';
import 'package:saca/domain/models/saca_models.dart';
import 'package:saca/domain/services/clinical_vocabulary_service.dart';
import 'package:saca/presentation/localization/saca_localizer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SacaLocalizer localizer;

  setUpAll(() async {
    final source = await rootBundle.loadString(
      'assets/data/gurindji_lexicon.json',
    );
    final vocabulary = ClinicalVocabularyService.fromEntries(
      LexiconEntry.listFromJson(source),
    );
    localizer = SacaLocalizer(vocabulary: vocabulary);
  });

  test('returns English UI strings in English mode', () {
    expect(localizer.t(SacaLanguage.english, 'inputTitle'),
        'How do you want to enter symptoms?');
    expect(localizer.t(SacaLanguage.english, 'continue'), 'Continue');
  });

  test('returns Gurindji UI strings in Gurindji mode', () {
    expect(localizer.t(SacaLanguage.gurindji, 'inputTitle'),
        'Nyatpa jangany nyawa?');
    expect(localizer.t(SacaLanguage.gurindji, 'continue'), 'Kawayi');
  });

  test('language screen copy remains bilingual before selection', () {
    expect(localizer.t(null, 'languageTitle'), contains('Choose'));
    expect(localizer.t(null, 'languageTitle'), contains('Yawu'));
    expect(localizer.t(null, 'languageGurindjiLabel'), 'Gurindji');
    expect(localizer.t(null, 'languageEnglishLabel'), 'English');
  });

  test('Gurindji clinical labels do not include English fallback', () {
    const fever = Symptom(id: 'fever', label: 'Fever');
    const bloating = Symptom(id: 'bloating', label: 'Bloating');

    expect(
        localizer.symptomLabel(SacaLanguage.gurindji, fever), 'makurrmakurr');
    expect(
        localizer.symptomLabel(SacaLanguage.gurindji, bloating), 'majul rumpa');
    expect(localizer.symptomLabel(SacaLanguage.gurindji, fever),
        isNot(contains('Fever')));
  });

  test('Gurindji result labels cover XGB classes without English fallback', () {
    final labels = <String>[
      'Common Cold',
      'urinary tract infection',
      'bronchial asthma',
      'migraine',
      'chest_pain mystery',
    ];

    for (final label in labels) {
      final translated = localizer.resultDiseaseLabel(
        SacaLanguage.gurindji,
        label,
      );
      expect(translated, isNot(isEmpty), reason: label);
      expect(translated, isNot(contains('_')), reason: label);
      expect(translated.toLowerCase(), isNot(contains('common cold')),
          reason: label);
      expect(translated.toLowerCase(), isNot(contains('urinary')),
          reason: label);
      expect(translated.toLowerCase(), isNot(contains('asthma')),
          reason: label);
      expect(translated.toLowerCase(), isNot(contains('migraine')),
          reason: label);
    }
  });

  test('unknown Gurindji result uses generic disease fallback', () {
    expect(
      localizer.resultDiseaseLabel(SacaLanguage.gurindji, 'unknown disease'),
      'jangany',
    );
  });

  test('Gurindji result guidance does not return English fallback', () {
    const result = AnalysisResult(
      disease: 'common cold',
      severity: SeverityLevel.mild,
      guidance: <String>['Rest and drink water.'],
      isEmergency: false,
      disclaimer: 'Not medical advice.',
    );

    final guidance = localizer.guidance(SacaLanguage.gurindji, result);

    expect(guidance, isNotEmpty);
    expect(guidance.join(' ').toLowerCase(), isNot(contains('rest')));
    expect(guidance.join(' ').toLowerCase(), isNot(contains('drink')));
  });

  test('English result labels and guidance stay unchanged', () {
    expect(
      localizer.resultDiseaseLabel(SacaLanguage.english, 'common cold'),
      'common cold',
    );

    const result = AnalysisResult(
      disease: 'unknown condition',
      severity: SeverityLevel.mild,
      guidance: <String>['Use the original guidance.'],
      isEmergency: false,
      disclaimer: 'Not medical advice.',
    );

    expect(
      localizer.guidance(SacaLanguage.english, result),
      <String>['Use the original guidance.'],
    );
  });
}
