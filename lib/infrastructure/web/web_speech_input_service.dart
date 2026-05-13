// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/errors/app_error.dart';
import '../../domain/models/saca_models.dart';
import '../../domain/services/speech_input_service.dart';
import 'saca_backend_serializers.dart';

class WebSpeechInputService implements SpeechInputService {
  WebSpeechInputService({required Uri baseUri, http.Client? client})
      : _baseUri = baseUri,
        _client = client ?? http.Client();

  final Uri _baseUri;
  final http.Client _client;
  final StreamController<String> _partialTranscriptController =
      StreamController<String>.broadcast();
  final List<html.Blob> _chunks = <html.Blob>[];
  html.MediaRecorder? _recorder;
  html.MediaStream? _stream;
  String _recordingMimeType = '';
  DateTime? _recordingStartedAt;
  Completer<AppResult<SpeechInputResult>>? _autoStopCompleter;
  Timer? _autoStopTimer;
  SacaLanguage _language = SacaLanguage.english;
  SpeechInputMode _mode = SpeechInputMode.dictation;

  @override
  bool get supportsOnDeviceStt => false;

  @override
  Stream<String> get partialTranscriptStream =>
      _partialTranscriptController.stream;

  @override
  Future<AppResult<void>> prepare(SacaLanguage language) async {
    _language = language;
    try {
      final response = await _client
          .get(_baseUri.resolve('/health'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return const AppResult<void>.success(null);
      }
      return AppResult<void>.failure(
        AppFailure(
          kind: AppFailureKind.modelMissing,
          message: 'Voice backend is unavailable. Try text input instead.',
          debugMessage: 'GET /health ${response.statusCode}',
        ),
      );
    } catch (error) {
      return AppResult<void>.failure(
        AppFailure(
          kind: AppFailureKind.modelMissing,
          message: 'Voice backend is unavailable. Try text input instead.',
          debugMessage: error,
        ),
      );
    }
  }

  @override
  Future<AppResult<void>> startRecording({
    SpeechInputMode mode = SpeechInputMode.dictation,
  }) async {
    _mode = mode;
    _chunks.clear();
    try {
      _stream = await html.window.navigator.mediaDevices?.getUserMedia(
        <String, Object>{'audio': true},
      );
      final stream = _stream;
      if (stream == null) {
        return const AppResult<void>.failure(
          AppFailure(
            kind: AppFailureKind.permissionDenied,
            message: 'Microphone is unavailable. Try text input instead.',
          ),
        );
      }
      _recordingMimeType = _bestRecordingMimeType();
      final recorder = _recordingMimeType.isEmpty
          ? html.MediaRecorder(stream)
          : html.MediaRecorder(stream, <String, Object?>{
              'mimeType': _recordingMimeType,
              'audioBitsPerSecond': 128000,
            });
      _recorder = recorder;
      _recordingStartedAt = DateTime.now();
      _autoStopCompleter = Completer<AppResult<SpeechInputResult>>();
      recorder.addEventListener('dataavailable', (event) {
        final data = (event as dynamic).data as html.Blob?;
        debugPrint('[SACA] Web recorder chunk size=${data?.size ?? 0}');
        if (data != null && data.size > 0) {
          _chunks.add(data);
        }
      });
      recorder.addEventListener('error', (event) {
        debugPrint('[SACA] Web recorder error: $event');
      });
      recorder.addEventListener('stop', (_) {
        unawaited(Future<void>.delayed(
          const Duration(milliseconds: 500),
          _completeRecording,
        ));
      });
      recorder.start(1000);
      _autoStopTimer = Timer(const Duration(seconds: 30), () {
        unawaited(_stopRecorder());
      });
      return const AppResult<void>.success(null);
    } catch (error) {
      await cancel();
      return AppResult<void>.failure(
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
    final future = _autoStopCompleter?.future;
    if (future != null) return future;
    return const AppResult<SpeechInputResult>.failure(
      AppFailure(
        kind: AppFailureKind.recordingFailed,
        message: 'No active recording. Try again.',
      ),
    );
  }

  @override
  Future<AppResult<SpeechInputResult>> stopAndTranscribe({
    SpeechInputMode mode = SpeechInputMode.dictation,
  }) async {
    await _stopRecorder();
    return waitForAutoStopAndTranscribe(mode: mode);
  }

  Future<void> _stopRecorder() async {
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    final recorder = _recorder;
    if (recorder != null && recorder.state == 'recording') {
      final elapsed = DateTime.now().difference(
        _recordingStartedAt ?? DateTime.now(),
      );
      if (elapsed < const Duration(milliseconds: 1200)) {
        await Future<void>.delayed(
            const Duration(milliseconds: 1200) - elapsed);
      }
      recorder.requestData();
      await Future<void>.delayed(const Duration(milliseconds: 600));
      recorder.stop();
    } else {
      await _completeRecording();
    }
  }

  Future<void> _completeRecording() async {
    final completer = _autoStopCompleter;
    if (completer == null || completer.isCompleted) return;
    _stopTracks();
    try {
      final audio = await _readBlob(html.Blob(_chunks));
      debugPrint(
        '[SACA] Web recorder complete chunks=${_chunks.length} bytes=${audio.length}',
      );
      if (audio.isEmpty) {
        completer.complete(
          const AppResult<SpeechInputResult>.failure(
            AppFailure(
              kind: AppFailureKind.recordingFailed,
              message:
                  'No audio was captured. Check microphone access and try again.',
            ),
          ),
        );
        return;
      }
      final extension = _recordingMimeType.contains('wav') ? 'wav' : 'webm';
      final request = http.MultipartRequest('POST', _baseUri.resolve('/stt'))
        ..fields['language'] = _language.name
        ..fields['mode'] = _mode.name
        ..files.add(
          http.MultipartFile.fromBytes(
            'audio',
            audio,
            filename: 'saca-web-recording.$extension',
          ),
        );
      final streamed =
          await _client.send(request).timeout(const Duration(seconds: 45));
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        completer.complete(
          AppResult<SpeechInputResult>.failure(
            AppFailure(
              kind: AppFailureKind.transcriptionFailed,
              message: 'Could not transcribe the recording. Try text input.',
              debugMessage:
                  'POST /stt ${response.statusCode}: ${response.body}',
            ),
          ),
        );
        return;
      }
      final json = jsonDecode(response.body) as Map<String, Object?>;
      completer.complete(AppResult<SpeechInputResult>.success(
        speechInputResultFromJson(json),
      ));
    } catch (error) {
      completer.complete(
        AppResult<SpeechInputResult>.failure(
          AppFailure(
            kind: AppFailureKind.transcriptionFailed,
            message: 'Could not transcribe the recording. Try text input.',
            debugMessage: error,
          ),
        ),
      );
    } finally {
      _chunks.clear();
      _recorder = null;
      _recordingMimeType = '';
      _recordingStartedAt = null;
    }
  }

  String _bestRecordingMimeType() {
    const candidates = <String>[
      'audio/webm;codecs=opus',
      'audio/webm',
      'audio/ogg;codecs=opus',
      'audio/ogg',
      'audio/wav',
    ];
    for (final candidate in candidates) {
      if (html.MediaRecorder.isTypeSupported(candidate)) {
        return candidate;
      }
    }
    return '';
  }

  Future<Uint8List> _readBlob(html.Blob blob) {
    final completer = Completer<Uint8List>();
    final reader = html.FileReader();
    reader.onLoad.listen((_) {
      final result = reader.result;
      if (result is String) {
        final marker = result.indexOf(',');
        final payload = marker >= 0 ? result.substring(marker + 1) : result;
        completer.complete(base64Decode(payload));
      } else if (result is ByteBuffer) {
        completer.complete(Uint8List.view(result));
      } else if (result is Uint8List) {
        completer.complete(result);
      } else {
        debugPrint(
            '[SACA] Web recorder unsupported FileReader result: $result');
        completer.complete(Uint8List(0));
      }
    });
    reader.onError
        .listen((_) => completer.completeError(reader.error ?? 'read failed'));
    reader.readAsDataUrl(blob);
    return completer.future;
  }

  @override
  Future<void> cancel() async {
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    _stopTracks();
    _recorder = null;
    _chunks.clear();
    final completer = _autoStopCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(
        const AppResult<SpeechInputResult>.failure(
          AppFailure(
            kind: AppFailureKind.recordingFailed,
            message: 'Recording cancelled.',
          ),
        ),
      );
    }
  }

  void _stopTracks() {
    for (final track in _stream?.getTracks() ?? <html.MediaStreamTrack>[]) {
      track.stop();
    }
    _stream = null;
  }

  @override
  void dispose() {
    unawaited(cancel());
    _client.close();
    unawaited(_partialTranscriptController.close());
  }
}
