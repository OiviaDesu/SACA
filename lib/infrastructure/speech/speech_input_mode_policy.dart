import '../../domain/services/speech_input_service.dart';
import 'audio_recorder_service.dart';
import 'whisper_service.dart' as whisper;

class SpeechInputModePolicy {
  const SpeechInputModePolicy._();

  static Duration maxDurationFor(SpeechInputMode mode) {
    return switch (mode) {
      SpeechInputMode.dictation => AudioRecorderService.maxRecordingDuration,
      SpeechInputMode.command => const Duration(seconds: 3),
    };
  }

  static Duration silenceDelayFor(SpeechInputMode mode) {
    return switch (mode) {
      SpeechInputMode.dictation => AudioRecorderService.silenceAutoStopDelay,
      SpeechInputMode.command => const Duration(milliseconds: 900),
    };
  }

  static whisper.WhisperTranscriptionOptions transcriptionOptionsFor(
    SpeechInputMode mode,
  ) {
    return switch (mode) {
      SpeechInputMode.dictation =>
        whisper.WhisperTranscriptionOptions.dictation,
      SpeechInputMode.command => whisper.WhisperTranscriptionOptions.command,
    };
  }
}
