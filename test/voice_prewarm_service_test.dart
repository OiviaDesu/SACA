import 'package:flutter_test/flutter_test.dart';
import 'package:saca_demo/core/errors/app_error.dart';
import 'package:saca_demo/domain/models/saca_models.dart';
import 'package:saca_demo/domain/services/speech_input_service.dart';
import 'package:saca_demo/infrastructure/speech/voice_prewarm_service.dart';

void main() {
  group('VoicePrewarmService', () {
    test('prepares English voice input without blocking app startup callers',
        () async {
      final speechInput = _FakeSpeechInputService();
      final prewarmer = VoicePrewarmService(speechInput: speechInput);

      await prewarmer.prewarm();

      expect(speechInput.prepareCalls, 1);
      expect(speechInput.lastLanguage, SacaLanguage.english);
    });

    test('skips prepare when on-device voice is unavailable', () async {
      final speechInput = _FakeSpeechInputService(supportsStt: false);
      final prewarmer = VoicePrewarmService(speechInput: speechInput);

      await prewarmer.prewarm();

      expect(speechInput.prepareCalls, 0);
    });

    test('does not throw when voice prepare fails', () async {
      final speechInput = _FakeSpeechInputService(
        prepareResult: const AppResult.failure(
          AppFailure(
            kind: AppFailureKind.modelMissing,
            message: 'Voice model unavailable.',
          ),
        ),
      );
      final prewarmer = VoicePrewarmService(speechInput: speechInput);

      await prewarmer.prewarm();

      expect(speechInput.prepareCalls, 1);
    });
  });
}

class _FakeSpeechInputService implements SpeechInputService {
  _FakeSpeechInputService({
    this.supportsStt = true,
    this.prepareResult = const AppResult<void>.success(null),
  });

  final bool supportsStt;
  final AppResult<void> prepareResult;
  int prepareCalls = 0;
  SacaLanguage? lastLanguage;

  @override
  bool get supportsOnDeviceStt => supportsStt;

  @override
  Future<AppResult<void>> prepare(SacaLanguage language) async {
    prepareCalls += 1;
    lastLanguage = language;
    return prepareResult;
  }

  @override
  Future<AppResult<void>> startRecording() async {
    return const AppResult.success(null);
  }

  @override
  Future<AppResult<SpeechInputResult>> stopAndTranscribe() async {
    return const AppResult.success(SpeechInputResult(text: ''));
  }

  @override
  Future<void> cancel() async {}

  @override
  void dispose() {}
}
