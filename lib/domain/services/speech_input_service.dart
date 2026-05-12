import '../../core/errors/app_error.dart';
import '../models/saca_models.dart';

class SpeechInputResult {
  const SpeechInputResult({required this.text, this.signalFeatures});

  final String text;
  final SpeechSignalFeatures? signalFeatures;
}

enum SpeechInputMode { dictation, command }

abstract interface class SpeechInputService {
  bool get supportsOnDeviceStt;
  Stream<String> get partialTranscriptStream;

  Future<AppResult<void>> prepare(SacaLanguage language);
  Future<AppResult<void>> startRecording({
    SpeechInputMode mode = SpeechInputMode.dictation,
  });
  Future<AppResult<SpeechInputResult>> waitForAutoStopAndTranscribe({
    SpeechInputMode mode = SpeechInputMode.dictation,
  });
  Future<AppResult<SpeechInputResult>> stopAndTranscribe({
    SpeechInputMode mode = SpeechInputMode.dictation,
  });
  Future<void> cancel();
  void dispose();
}
