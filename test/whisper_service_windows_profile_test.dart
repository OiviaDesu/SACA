import 'package:flutter_test/flutter_test.dart';
import 'package:saca/infrastructure/speech/whisper_service_io.dart';

void main() {
  group('SacaSttModelAssets Windows profile', () {
    test('uses forced English only for English mode', () {
      expect(
        SacaSttModelAssets.windowsLanguageCode(SacaLanguage.english),
        'en',
      );
      expect(SacaSttModelAssets.windowsLanguageCode(SacaLanguage.gurindji), '');
    });

    test('keeps Windows runtime cache separated by app language', () {
      expect(
        SacaSttModelAssets.windowsRuntimeKey(SacaLanguage.english),
        'sherpa-onnx-whisper-gue-base-run4-rc1:english',
      );
      expect(
        SacaSttModelAssets.windowsRuntimeKey(SacaLanguage.gurindji),
        'sherpa-onnx-whisper-gue-base-run4-rc1:gurindji',
      );
      expect(
        SacaSttModelAssets.windowsRuntimeKey(SacaLanguage.english),
        isNot(SacaSttModelAssets.windowsRuntimeKey(SacaLanguage.gurindji)),
      );
    });
  });
}
