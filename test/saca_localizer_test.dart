import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saca_demo/domain/models/lexicon_entry.dart';
import 'package:saca_demo/domain/models/saca_models.dart';
import 'package:saca_demo/domain/services/clinical_vocabulary_service.dart';
import 'package:saca_demo/presentation/localization/saca_localizer.dart';

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
}
