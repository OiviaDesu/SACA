import 'package:flutter_test/flutter_test.dart';
import 'package:saca_demo/domain/services/transcript_sanitizer.dart';

void main() {
  const sanitizer = TranscriptSanitizer();

  test('removes common whisper bracket artifacts', () {
    expect(
      sanitizer.clean('[MUSIC] fever [SINGING] and cough [BLANK_AUDIO]'),
      'fever and cough',
    );
  });

  test('removes bracketed non-speech cues but keeps spoken symptoms', () {
    expect(
      sanitizer.clean('[coughing] I have cough and throat pain [gasp]'),
      'I have cough and throat pain',
    );
  });

  test('removes wrapped non-speech cues from all common delimiters', () {
    expect(sanitizer.clean('[coughing] fever'), 'fever');
    expect(sanitizer.clean('(gasping) chest pain'), 'chest pain');
    expect(sanitizer.clean('<wheezing> sore throat'), 'sore throat');
  });

  test('keeps wrapped clinical text that is not a noise cue', () {
    expect(sanitizer.clean('(possible fever)'), '(possible fever)');
  });

  test('rejects noise-only transcript', () {
    expect(sanitizer.isUsable('[BLANK_AUDIO] (noise) <silence>'), isFalse);
  });
}
