// AudioRecorderService – captures 16 kHz mono PCM WAV for Whisper.
//
// Uses the `record` package.
//   startRecording() → user speaks → stopRecording() → returns file path.

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  String? _currentPath;

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  Future<void> startRecording() async {
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
    debugPrint('[SACA] Recording started → $_currentPath');
  }

  /// Returns the WAV file path, or null on failure.
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;
    final path = await _recorder.stop();
    _isRecording = false;
    final resolvedPath = path ?? _currentPath;
    debugPrint('[SACA] Recording stopped → $resolvedPath');
    return resolvedPath;
  }

  Future<void> cancelRecording() async {
    if (_isRecording) {
      await _recorder.cancel();
      _isRecording = false;
    }
  }

  void dispose() {
    _recorder.dispose();
  }
}
