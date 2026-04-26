import '../../core/errors/app_error.dart';
import '../models/saca_models.dart';

class SpeechInputResult {
  const SpeechInputResult({required this.text});

  final String text;
}

abstract interface class SpeechInputService {
  bool get supportsOnDeviceStt;

  Future<AppResult<void>> prepare(SacaLanguage language);
  Future<AppResult<void>> startRecording();
  Future<AppResult<SpeechInputResult>> stopAndTranscribe();
  Future<void> cancel();
  void dispose();
}
