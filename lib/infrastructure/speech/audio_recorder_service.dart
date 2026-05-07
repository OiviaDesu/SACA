// AudioRecorderService – captures 16 kHz mono PCM WAV for Whisper.
//
// Uses the `record` package.
//   startRecording() → user speaks → stopRecording() → returns file path.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  String? _currentPath;
  Timer? _autoStopTimer;
  DateTime? _recordingStartedAt;
  DateTime? _lastSpeechAt;
  Duration _maxRecordingDuration = maxRecordingDuration;
  Duration _silenceAutoStopDelay = silenceAutoStopDelay;
  bool _heardSpeech = false;
  Completer<String?>? _autoStopCompleter;

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  static const Duration silenceAutoStopDelay = Duration(milliseconds: 2500);
  static const Duration maxRecordingDuration = Duration(seconds: 30);
  static const double speechAmplitudeDb = -38;

  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  Future<void> startRecording({
    Duration maxDuration = maxRecordingDuration,
    Duration silenceDelay = silenceAutoStopDelay,
  }) async {
    if (_isRecording) return;

    final dir = await getTemporaryDirectory();
    final outputPath =
        '${dir.path}/saca_input_${DateTime.now().millisecondsSinceEpoch}.wav';

    _currentPath = outputPath;

    const config = RecordConfig(
      encoder: AudioEncoder.wav,
      sampleRate: 16000,
      numChannels: 1, // mono – Whisper requirement
      bitRate: 256000,
    );

    await _recorder.start(config, path: outputPath);

    _isRecording = true;
    _recordingStartedAt = DateTime.now();
    _lastSpeechAt = null;
    _maxRecordingDuration = maxDuration;
    _silenceAutoStopDelay = silenceDelay;
    _heardSpeech = false;
    _autoStopCompleter = Completer<String?>();
    _startAutoStopPolling();
    debugPrint('[SACA] Recording started → $_currentPath');
  }

  Future<String?> waitForAutoStop() async {
    return _autoStopCompleter?.future;
  }

  /// Returns the WAV file path, or null on failure.
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    final path = await _recorder.stop();
    _isRecording = false;
    final resolvedPath = path ?? _currentPath;
    debugPrint('[SACA] Recording stopped → $resolvedPath');
    if (!(_autoStopCompleter?.isCompleted ?? true)) {
      _autoStopCompleter?.complete(resolvedPath);
    }
    return resolvedPath;
  }

  Future<void> cancelRecording() async {
    if (_isRecording) {
      await _recorder.cancel();
      _isRecording = false;
    }
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    if (!(_autoStopCompleter?.isCompleted ?? true)) {
      _autoStopCompleter?.complete(null);
    }
  }

  void dispose() {
    _autoStopTimer?.cancel();
    _recorder.dispose();
  }

  void _startAutoStopPolling() {
    _autoStopTimer?.cancel();
    _autoStopTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      _checkAutoStop();
    });
  }

  Future<void> _checkAutoStop() async {
    if (!_isRecording) return;
    final now = DateTime.now();
    final startedAt = _recordingStartedAt ?? now;
    if (now.difference(startedAt) >= _maxRecordingDuration) {
      await stopRecording();
      return;
    }

    try {
      final amplitude = await _recorder.getAmplitude();
      if (amplitude.current > speechAmplitudeDb) {
        _heardSpeech = true;
        _lastSpeechAt = now;
      }
    } catch (_) {
      return;
    }

    final lastSpeechAt = _lastSpeechAt;
    if (_heardSpeech &&
        lastSpeechAt != null &&
        now.difference(lastSpeechAt) >= _silenceAutoStopDelay) {
      await stopRecording();
    }
  }
}
