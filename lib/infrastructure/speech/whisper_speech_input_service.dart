import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/errors/app_error.dart';
import '../../domain/models/saca_models.dart' as domain;
import '../../domain/services/speech_input_service.dart';
import '../../domain/services/transcript_sanitizer.dart';
import 'audio_recorder_service.dart';
import 'partial_transcript_policy.dart';
import 'speech_input_mode_policy.dart';
import 'whisper_service.dart' as whisper;

class WhisperSpeechInputService implements SpeechInputService {
  WhisperSpeechInputService({
    AudioRecorderService? recorder,
    whisper.WhisperService? whisperService,
    TranscriptSanitizer? transcriptSanitizer,
    PartialTranscriptPolicy partialTranscriptPolicy =
        const PartialTranscriptPolicy(),
  })  : _recorder = recorder ??
            AudioRecorderService(
                partialTranscriptPolicy: partialTranscriptPolicy),
        _whisper = whisperService ?? whisper.WhisperService(),
        _transcriptSanitizer =
            transcriptSanitizer ?? const TranscriptSanitizer(),
        _partialTranscriptPolicy = partialTranscriptPolicy;

  final AudioRecorderService _recorder;
  final whisper.WhisperService _whisper;
  final TranscriptSanitizer _transcriptSanitizer;
  final PartialTranscriptPolicy _partialTranscriptPolicy;
  final StreamController<String> _partialTranscriptController =
      StreamController<String>.broadcast();
  Timer? _partialTranscriptTimer;
  bool _partialDecodeInFlight = false;
  bool _partialsDisabledForRecording = false;
  int _slowPartialDecodeCount = 0;
  String _lastPartialTranscript = '';

  @override
  bool get supportsOnDeviceStt => _whisper.supportsOnDeviceStt;

  @override
  Stream<String> get partialTranscriptStream =>
      _partialTranscriptController.stream;

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
  Future<AppResult<void>> startRecording({
    SpeechInputMode mode = SpeechInputMode.dictation,
  }) async {
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

      await _recorder.startRecording(
        maxDuration: SpeechInputModePolicy.maxDurationFor(mode),
        silenceDelay: SpeechInputModePolicy.silenceDelayFor(mode),
      );
      _startPartialTranscriptPolling(mode);
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
  Future<AppResult<SpeechInputResult>> waitForAutoStopAndTranscribe({
    SpeechInputMode mode = SpeechInputMode.dictation,
  }) async {
    final audioPath = await _recorder.waitForAutoStop();
    _stopPartialTranscriptPolling();
    if (audioPath == null || audioPath.isEmpty) {
      return const AppResult.failure(
        AppFailure(
          kind: AppFailureKind.recordingFailed,
          message:
              'Recording stopped before audio was saved. Please try again.',
        ),
      );
    }
    return _transcribeSavedAudio(audioPath, mode: mode);
  }

  @override
  Future<AppResult<SpeechInputResult>> stopAndTranscribe({
    SpeechInputMode mode = SpeechInputMode.dictation,
  }) async {
    try {
      _stopPartialTranscriptPolling();
      final audioPath = await _recorder.stopRecording();
      if (audioPath == null || audioPath.isEmpty) {
        return const AppResult.failure(
          AppFailure(
            kind: AppFailureKind.recordingFailed,
            message: 'Recording did not save. Please try again.',
          ),
        );
      }
      return _transcribeSavedAudio(audioPath, mode: mode);
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

  Future<AppResult<SpeechInputResult>> _transcribeSavedAudio(
    String audioPath, {
    SpeechInputMode mode = SpeechInputMode.dictation,
  }) async {
    try {
      final stopwatch = Stopwatch()..start();
      final segments = await _whisper.transcribe(
        audioPath,
        options: SpeechInputModePolicy.transcriptionOptionsFor(mode),
      );
      final rawText = segments.map((segment) => segment.text).join(' ').trim();
      final text = _transcriptSanitizer.clean(rawText);
      final signalFeatures = _buildSignalFeatures(
        rawText: rawText,
        transcript: text,
      );
      stopwatch.stop();
      debugPrint(
        '[SACA] Voice ${mode.name} stop-to-text '
        'latency=${stopwatch.elapsedMilliseconds}ms',
      );
      if (!_transcriptSanitizer.isUsable(text) &&
          !signalFeatures.hasUsableSignals) {
        return const AppResult.failure(
          AppFailure(
            kind: AppFailureKind.emptyInput,
            message:
                'No usable speech was detected. Try again or type the symptom.',
          ),
        );
      }

      return AppResult.success(
        SpeechInputResult(text: text, signalFeatures: signalFeatures),
      );
    } catch (error, stackTrace) {
      debugPrint('[SACA] Transcription failed: $error\n$stackTrace');
      return AppResult.failure(
        AppFailure(
          kind: AppFailureKind.transcriptionFailed,
          message: 'Could not transcribe the recording. Try text input.',
          debugMessage: error,
        ),
      );
    } finally {
      await _recorder.deleteTempPath(audioPath);
    }
  }

  domain.SpeechSignalFeatures _buildSignalFeatures({
    required String rawText,
    required String transcript,
  }) {
    final cues = <domain.NonSpeechCue>[];
    void addCue(String kind, String evidence) {
      if (cues.any((cue) => cue.kind == kind)) return;
      cues.add(
        domain.NonSpeechCue(
          kind: kind,
          confidence: evidence == 'bracket_token' ? 0.75 : 0.62,
          evidence: evidence,
        ),
      );
    }

    final lower = rawText.toLowerCase();
    final wrappedCues = RegExp(r'[\[\(<]([^\]\)>]+)[\]\)>]').allMatches(lower);
    for (final match in wrappedCues) {
      final value = match.group(1) ?? '';
      if (value.contains('cough')) addCue('cough', 'bracket_token');
      if (value.contains('chok')) addCue('choke', 'bracket_token');
      if (value.contains('gasp')) addCue('gasp', 'bracket_token');
      if (value.contains('breath')) addCue('breath', 'bracket_token');
      if (value.contains('wheez')) addCue('wheeze', 'bracket_token');
    }

    if (RegExp(r'\b(cough|coughing|coughs)\b').hasMatch(lower)) {
      addCue('cough', 'raw_transcript_token');
    }
    if (RegExp(r'\b(choke|choking|choked)\b').hasMatch(lower)) {
      addCue('choke', 'raw_transcript_token');
    }
    if (RegExp(r'\b(gasp|gasping|gasped)\b').hasMatch(lower)) {
      addCue('gasp', 'raw_transcript_token');
    }
    if (RegExp(r'\b(breath|breathing|breathe)\b').hasMatch(lower)) {
      addCue('breath', 'raw_transcript_token');
    }
    if (RegExp(r'\b(wheeze|wheezing|wheezed)\b').hasMatch(lower)) {
      addCue('wheeze', 'raw_transcript_token');
    }

    return domain.SpeechSignalFeatures(
      transcript: transcript,
      cues: cues,
      confidence: cues.isEmpty ? null : 0.65,
      isSupported: cues.isNotEmpty,
    );
  }

  @override
  Future<void> cancel() {
    _stopPartialTranscriptPolling();
    return _recorder.cancelRecording();
  }

  @override
  void dispose() {
    _stopPartialTranscriptPolling();
    unawaited(_partialTranscriptController.close());
    _recorder.dispose();
    _whisper.dispose();
  }

  void _startPartialTranscriptPolling(SpeechInputMode mode) {
    _stopPartialTranscriptPolling();
    if (mode != SpeechInputMode.dictation || !_recorder.isStreamRecording) {
      return;
    }
    _lastPartialTranscript = '';
    _partialsDisabledForRecording = false;
    _slowPartialDecodeCount = 0;
    _partialTranscriptTimer = Timer.periodic(
      _partialTranscriptPolicy.pollingInterval,
      (_) => unawaited(_decodePartialTranscript()),
    );
  }

  void _stopPartialTranscriptPolling() {
    _partialTranscriptTimer?.cancel();
    _partialTranscriptTimer = null;
    _partialDecodeInFlight = false;
  }

  Future<void> _decodePartialTranscript() async {
    if (_partialsDisabledForRecording) return;
    if (_partialDecodeInFlight || !_recorder.isStreamRecording) {
      debugPrint(
        '[SACA] Partial transcript skipped platform=${defaultTargetPlatform.name} '
        'reason=${_partialDecodeInFlight ? 'decode_in_flight' : 'not_streaming'}',
      );
      return;
    }
    _partialDecodeInFlight = true;
    final stopwatch = Stopwatch()..start();
    try {
      final audioPath = await _recorder.writePartialWav(
        window: _partialTranscriptPolicy.rollingWindow,
      );
      if (audioPath == null || audioPath.isEmpty) {
        debugPrint(
          '[SACA] Partial transcript skipped platform=${defaultTargetPlatform.name} '
          'reason=audio_not_ready',
        );
        return;
      }
      try {
        final segments = await _whisper.transcribe(
          audioPath,
          options: whisper.WhisperTranscriptionOptions.command,
        );
        final rawText =
            segments.map((segment) => segment.text).join(' ').trim();
        final text = _transcriptSanitizer.clean(rawText);
        stopwatch.stop();
        _updatePartialPerformance(stopwatch.elapsed);
        if (!_transcriptSanitizer.isUsable(text)) return;
        if (text == _lastPartialTranscript) return;
        _lastPartialTranscript = text;
        _partialTranscriptController.add(text);
        debugPrint(
          '[SACA] Voice partial transcript platform=${defaultTargetPlatform.name} '
          'latency=${stopwatch.elapsedMilliseconds}ms',
        );
      } finally {
        await _recorder.deleteTempPath(audioPath);
      }
    } catch (error, stackTrace) {
      debugPrint('[SACA] Partial transcription skipped: $error\n$stackTrace');
      if (_partialTranscriptPolicy.isMobile) {
        _disablePartialsForRecording('mobile_decode_error');
      }
    } finally {
      _partialDecodeInFlight = false;
    }
  }

  void _updatePartialPerformance(Duration elapsed) {
    if (!_partialTranscriptPolicy.isMobile) return;
    if (elapsed <= _partialTranscriptPolicy.slowDecodeThreshold) {
      _slowPartialDecodeCount = 0;
      return;
    }
    _slowPartialDecodeCount += 1;
    debugPrint(
      '[SACA] Partial transcript slow platform=${defaultTargetPlatform.name} '
      'latency=${elapsed.inMilliseconds}ms '
      'threshold=${_partialTranscriptPolicy.slowDecodeThreshold.inMilliseconds}ms '
      'count=$_slowPartialDecodeCount',
    );
    if (_slowPartialDecodeCount >= 2) {
      _disablePartialsForRecording('mobile_decode_slow');
    }
  }

  void _disablePartialsForRecording(String reason) {
    _partialsDisabledForRecording = true;
    _partialTranscriptTimer?.cancel();
    _partialTranscriptTimer = null;
    debugPrint(
      '[SACA] Partial transcript disabled platform=${defaultTargetPlatform.name} '
      'reason=$reason',
    );
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
