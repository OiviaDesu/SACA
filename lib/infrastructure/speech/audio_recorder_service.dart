// AudioRecorderService – captures 16 kHz mono PCM WAV for Whisper.
//
// Uses the `record` package.
//   startRecording() → user speaks → stopRecording() → returns file path.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'partial_transcript_policy.dart';

class AudioRecorderService {
  AudioRecorderService({
    PartialTranscriptPolicy partialTranscriptPolicy =
        const PartialTranscriptPolicy(),
  }) : _partialTranscriptPolicy = partialTranscriptPolicy;

  final AudioRecorder _recorder = AudioRecorder();
  final PartialTranscriptPolicy _partialTranscriptPolicy;
  String? _currentPath;
  StreamSubscription<Uint8List>? _pcmSubscription;
  final List<Uint8List> _pcmChunks = <Uint8List>[];
  int _pcmBufferedBytes = 0;
  Timer? _autoStopTimer;
  DateTime? _recordingStartedAt;
  DateTime? _lastSpeechAt;
  Duration _maxRecordingDuration = maxRecordingDuration;
  Duration _silenceAutoStopDelay = silenceAutoStopDelay;
  Duration _noSpeechAutoStopDelay = noSpeechAutoStopDelay;
  bool _heardSpeech = false;
  Completer<String?>? _autoStopCompleter;
  bool _isStreamRecording = false;

  bool _isRecording = false;
  bool get isRecording => _isRecording;
  bool get isStreamRecording => _isStreamRecording;

  static const Duration silenceAutoStopDelay = Duration(milliseconds: 2500);
  static const Duration maxRecordingDuration = Duration(seconds: 30);
  static const Duration noSpeechAutoStopDelay = Duration(seconds: 6);
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
    _maxRecordingDuration = maxDuration;
    _silenceAutoStopDelay = silenceDelay;
    _noSpeechAutoStopDelay = _fallbackDelayFor(maxDuration);
    _clearPcmBuffer();

    const config = RecordConfig(
      encoder: AudioEncoder.wav,
      sampleRate: 16000,
      numChannels: 1, // mono – Whisper requirement
      bitRate: 256000,
    );

    _isStreamRecording = false;
    if (_partialTranscriptPolicy.supportsPcmStreamRecording &&
        await _recorder.isEncoderSupported(AudioEncoder.pcm16bits)) {
      try {
        const streamConfig = RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 256000,
        );
        final stream = await _recorder.startStream(streamConfig);
        _pcmSubscription = stream.listen(
          _appendPcmChunk,
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('[SACA] PCM stream failed: $error\n$stackTrace');
          },
        );
        _isStreamRecording = true;
      } catch (error, stackTrace) {
        debugPrint('[SACA] PCM stream unavailable: $error\n$stackTrace');
        await _closePcmStream();
        await _recorder.start(config, path: outputPath);
      }
    } else {
      debugPrint(
        '[SACA] PCM stream skipped platform=${defaultTargetPlatform.name} '
        'supported=${_partialTranscriptPolicy.supportsPcmStreamRecording}',
      );
      await _recorder.start(config, path: outputPath);
    }

    _isRecording = true;
    _recordingStartedAt = DateTime.now();
    _lastSpeechAt = null;
    _heardSpeech = false;
    _autoStopCompleter = Completer<String?>();
    _startAutoStopPolling();
    debugPrint(
      '[SACA] Recording started path=$_currentPath '
      'platform=${defaultTargetPlatform.name} max=${maxDuration.inMilliseconds}ms '
      'silence=${silenceDelay.inMilliseconds}ms stream=$_isStreamRecording '
      'noSpeech=${_noSpeechAutoStopDelay.inMilliseconds}ms',
    );
  }

  Future<String?> waitForAutoStop() async {
    return _autoStopCompleter?.future;
  }

  Future<String?> stopRecording() async {
    return _stopRecording(reason: 'manual');
  }

  /// Returns the WAV file path, or null on failure.
  Future<String?> _stopRecording({required String reason}) async {
    if (!_isRecording) return null;
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    final path = await _recorder.stop();
    await _closePcmStream();
    _isRecording = false;
    final resolvedPath = _isStreamRecording
        ? await _writeWavFromPcmBuffer(_currentPath)
        : path ?? _currentPath;
    _isStreamRecording = false;
    _clearPcmBuffer();
    final size = await _fileSize(resolvedPath);
    debugPrint(
      '[SACA] Recording stopped reason=$reason path=$resolvedPath size=$size',
    );
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
    await _closePcmStream();
    _isStreamRecording = false;
    _clearPcmBuffer();
    await deleteTempPath(_currentPath);
    _currentPath = null;
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    if (!(_autoStopCompleter?.isCompleted ?? true)) {
      _autoStopCompleter?.complete(null);
    }
  }

  void dispose() {
    _autoStopTimer?.cancel();
    unawaited(_closePcmStream());
    _clearPcmBuffer();
    unawaited(deleteTempPath(_currentPath));
    _recorder.dispose();
  }

  static const Duration partialTranscriptWindow = Duration(seconds: 12);

  Future<String?> writePartialWav({
    Duration window = partialTranscriptWindow,
  }) async {
    if (!_isStreamRecording) return null;
    try {
      final bytes = _pcmSnapshotBytes();
      if (bytes.isEmpty) return null;
      const bytesPerSecond = 16000 * 2;
      final maxBytes = window.inSeconds * bytesPerSecond;
      final start = bytes.length > maxBytes ? bytes.length - maxBytes : 0;
      final alignedStart = start.isEven ? start : start + 1;
      final partialBytes = bytes.sublist(alignedStart);
      if (partialBytes.length < bytesPerSecond) return null;
      final dir = await getTemporaryDirectory();
      final outputPath =
          '${dir.path}/saca_partial_${DateTime.now().millisecondsSinceEpoch}.wav';
      await File(outputPath).writeAsBytes(
        _wavBytesFromPcm(partialBytes),
        flush: true,
      );
      return outputPath;
    } catch (error, stackTrace) {
      debugPrint('[SACA] Partial WAV write failed: $error\n$stackTrace');
      return null;
    }
  }

  Future<void> _closePcmStream() async {
    await _pcmSubscription?.cancel();
    _pcmSubscription = null;
  }

  Future<String?> _writeWavFromPcmBuffer(String? outputPath) async {
    if (outputPath == null) return outputPath;
    try {
      final pcmBytes = _pcmSnapshotBytes();
      if (pcmBytes.isEmpty) return outputPath;
      await File(outputPath).writeAsBytes(
        _wavBytesFromPcm(pcmBytes),
        flush: true,
      );
      return outputPath;
    } catch (error, stackTrace) {
      debugPrint('[SACA] WAV finalization failed: $error\n$stackTrace');
      return outputPath;
    }
  }

  void _appendPcmChunk(Uint8List chunk) {
    final copy = Uint8List.fromList(chunk);
    _pcmChunks.add(copy);
    _pcmBufferedBytes += copy.length;

    final maxBytes =
        (_maxRecordingDuration.inMilliseconds / 1000 * 16000 * 2).ceil();
    while (_pcmBufferedBytes > maxBytes && _pcmChunks.isNotEmpty) {
      final removed = _pcmChunks.removeAt(0);
      _pcmBufferedBytes -= removed.length;
      _zeroBytes(removed);
    }
  }

  Uint8List _pcmSnapshotBytes() {
    if (_pcmBufferedBytes <= 0 || _pcmChunks.isEmpty) return Uint8List(0);
    final bytes = Uint8List(_pcmBufferedBytes);
    var offset = 0;
    for (final chunk in _pcmChunks) {
      bytes.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    return bytes;
  }

  void _clearPcmBuffer() {
    for (final chunk in _pcmChunks) {
      _zeroBytes(chunk);
    }
    _pcmChunks.clear();
    _pcmBufferedBytes = 0;
  }

  void _zeroBytes(Uint8List bytes) {
    bytes.fillRange(0, bytes.length, 0);
  }

  Future<void> deleteTempPath(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (error, stackTrace) {
      debugPrint('[SACA] Temp audio cleanup failed: $error\n$stackTrace');
    }
  }

  Uint8List _wavBytesFromPcm(List<int> pcmBytes) {
    const sampleRate = 16000;
    const channels = 1;
    const bitsPerSample = 16;
    const byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    const blockAlign = channels * bitsPerSample ~/ 8;
    final dataLength = pcmBytes.length;
    final bytes = BytesBuilder(copy: false)
      ..add(_ascii('RIFF'))
      ..add(_uint32(36 + dataLength))
      ..add(_ascii('WAVE'))
      ..add(_ascii('fmt '))
      ..add(_uint32(16))
      ..add(_uint16(1))
      ..add(_uint16(channels))
      ..add(_uint32(sampleRate))
      ..add(_uint32(byteRate))
      ..add(_uint16(blockAlign))
      ..add(_uint16(bitsPerSample))
      ..add(_ascii('data'))
      ..add(_uint32(dataLength))
      ..add(pcmBytes);
    return bytes.toBytes();
  }

  Uint8List _ascii(String value) => Uint8List.fromList(value.codeUnits);

  Uint8List _uint16(int value) {
    final data = ByteData(2)..setUint16(0, value, Endian.little);
    return data.buffer.asUint8List();
  }

  Uint8List _uint32(int value) {
    final data = ByteData(4)..setUint32(0, value, Endian.little);
    return data.buffer.asUint8List();
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
      await _stopRecording(reason: 'max_duration');
      return;
    }

    try {
      final amplitude = await _recorder.getAmplitude();
      if (amplitude.current > speechAmplitudeDb) {
        _heardSpeech = true;
        _lastSpeechAt = now;
      }
    } catch (_) {
      if (_shouldAutoStopWithoutSpeech(now, startedAt)) {
        await _stopRecording(reason: 'no_amplitude_no_speech');
      }
      return;
    }

    final lastSpeechAt = _lastSpeechAt;
    if (_heardSpeech &&
        lastSpeechAt != null &&
        now.difference(lastSpeechAt) >= _silenceAutoStopDelay) {
      await _stopRecording(reason: 'silence');
      return;
    }
    if (_shouldAutoStopWithoutSpeech(now, startedAt)) {
      await _stopRecording(reason: 'no_speech');
    }
  }

  bool _shouldAutoStopWithoutSpeech(DateTime now, DateTime startedAt) {
    return !_heardSpeech && now.difference(startedAt) >= _noSpeechAutoStopDelay;
  }

  Duration _fallbackDelayFor(Duration maxDuration) {
    if (maxDuration <= noSpeechAutoStopDelay) return maxDuration;
    return noSpeechAutoStopDelay;
  }

  Future<int?> _fileSize(String? path) async {
    if (path == null || path.isEmpty) return null;
    try {
      return await File(path).length();
    } catch (_) {
      return null;
    }
  }
}
