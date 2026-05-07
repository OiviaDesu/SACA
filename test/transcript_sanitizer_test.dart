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

  test('rejects noise-only transcript', () {
    expect(sanitizer.isUsable('[BLANK_AUDIO] [MUSIC]'), isFalse);
  });
}
