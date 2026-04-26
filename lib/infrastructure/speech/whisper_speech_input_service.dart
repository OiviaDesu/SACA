import 'package:flutter/foundation.dart';

import '../../core/errors/app_error.dart';
import '../../domain/models/saca_models.dart' as domain;
import '../../domain/services/speech_input_service.dart';
import '../../services/audio_recorder_service.dart';
import '../../services/whisper_service.dart' as whisper;

class WhisperSpeechInputService implements SpeechInputService {
  WhisperSpeechInputService({
    AudioRecorderService? recorder,
    whisper.WhisperService? whisperService,
  })  : _recorder = recorder ?? AudioRecorderService(),
        _whisper = whisperService ?? whisper.WhisperService();

  final AudioRecorderService _recorder;
  final whisper.WhisperService _whisper;

  @override
  bool get supportsOnDeviceStt => _whisper.supportsOnDeviceStt;

  @override
  Future<AppResult<void>> prepare(domain.SacaLanguage language) async {
    if (!supportsOnDeviceStt) {
      return const AppResult.failure(
        AppFailure(
          kind: AppFailureKind.modelMissing,
          message: 'Offline voice input is not available on this platform.',
        ),
      );
    }

    try {
      await _whisper.init(language: _mapLanguage(language));
      return const AppResult.success(null);
    } catch (error, stackTrace) {
      debugPrint('[SACA] Whisper init failed: $error\n$stackTrace');
      return AppResult.failure(
        AppFailure(
          kind: AppFailureKind.modelMissing,
          message: 'Voice model is not ready. Use text or symptom selection.',
          debugMessage: error,
        ),
      );
    }
  }

  @override
  Future<AppResult<void>> startRecording() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        return const AppResult.failure(
          AppFailure(
            kind: AppFailureKind.permissionDenied,
            message: 'Microphone permission is needed for voice input.',
          ),
        );
      }

      await _recorder.startRecording();
      return const AppResult.success(null);
    } catch (error, stackTrace) {
      debugPrint('[SACA] Recording failed: $error\n$stackTrace');
      return AppResult.failure(
        AppFailure(
          kind: AppFailureKind.recordingFailed,
          message: 'Could not start recording. Try text input instead.',
          debugMessage: error,
        ),
      );
    }
  }

  @override
  Future<AppResult<SpeechInputResult>> stopAndTranscribe() async {
    try {
      final audioPath = await _recorder.stopRecording();
      if (audioPath == null || audioPath.isEmpty) {
        return const AppResult.failure(
          AppFailure(
            kind: AppFailureKind.recordingFailed,
            message: 'Recording did not save. Please try again.',
          ),
        );
      }

      final segments = await _whisper.transcribe(audioPath);
      final text = segments.map((segment) => segment.text).join(' ').trim();
      if (text.isEmpty) {
        return const AppResult.failure(
          AppFailure(
            kind: AppFailureKind.emptyInput,
            message: 'No speech was detected. Try again or type the symptom.',
          ),
        );
      }

      return AppResult.success(SpeechInputResult(text: text));
    } catch (error, stackTrace) {
      debugPrint('[SACA] Transcription failed: $error\n$stackTrace');
      return AppResult.failure(
        AppFailure(
          kind: AppFailureKind.transcriptionFailed,
          message: 'Could not transcribe the recording. Try text input.',
          debugMessage: error,
        ),
      );
    }
  }

  @override
  Future<void> cancel() {
    return _recorder.cancelRecording();
  }

  @override
  void dispose() {
    _recorder.dispose();
    _whisper.dispose();
  }

  whisper.SacaLanguage _mapLanguage(domain.SacaLanguage language) {
    switch (language) {
      case domain.SacaLanguage.english:
        return whisper.SacaLanguage.english;
      case domain.SacaLanguage.gurindji:
        return whisper.SacaLanguage.gurindji;
    }
  }
}
