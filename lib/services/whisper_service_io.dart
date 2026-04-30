// WhisperService – platform service for on-device STT.
//
// - Windows: sherpa_onnx + bundled Whisper ONNX model
// - Android/iOS: whisper_kit with optional bundled English-only base.en asset

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'package:whisper_kit/whisper_kit.dart';

part 'whisper_service/mobile_runtime.dart';
part 'whisper_service/windows_runtime.dart';
part 'whisper_service/whisper_asset_bundle.dart';

enum SacaLanguage { english, gurindji }

class TranscriptSegment {
  final String text;
  final Duration from;
  final Duration to;

  const TranscriptSegment({
    required this.text,
    required this.from,
    required this.to,
  });
}

class WhisperService {
  static final WhisperService _instance = WhisperService._internal();
  factory WhisperService() => _instance;
  WhisperService._internal();

  static bool _sherpaBindingsInitialized = false;

  Whisper? _whisper;
  sherpa.OfflineRecognizer? _windowsRecognizer;
  SacaLanguage _language = SacaLanguage.english;
  String? _loadedRuntimeKey;
  String? _initializingRuntimeKey;
  Future<void>? _initFuture;

  bool get _isWhisperKitPlatform => Platform.isAndroid || Platform.isIOS;
  bool get _isSherpaWindowsPlatform => Platform.isWindows;
  bool get supportsOnDeviceStt =>
      _isWhisperKitPlatform || _isSherpaWindowsPlatform;

  static const _defaultWindowsBundle = _WhisperAssetBundle(
    assetBase: 'assets/models/sherpa-onnx-whisper-base',
    supportDirName: 'sherpa-onnx-whisper-base',
    label: 'whisper-base',
  );
  static const _englishWindowsBundle = _WhisperAssetBundle(
    assetBase: 'assets/models/sherpa-onnx-whisper-base-en',
    supportDirName: 'sherpa-onnx-whisper-base-en',
    label: 'whisper-base.en',
  );

  /// Call once at app start to initialize the platform STT runtime.
  Future<void> init({SacaLanguage language = SacaLanguage.english}) async {
    final runtimeKey = await _resolveRuntimeKey(language);
    if (_isRuntimeReady(runtimeKey)) {
      _language = language;
      return;
    }

    final activeInit = _initFuture;
    if (activeInit != null && _initializingRuntimeKey == runtimeKey) {
      await activeInit;
      _language = language;
      return;
    }
    if (activeInit != null) {
      await activeInit;
      if (_isRuntimeReady(runtimeKey)) {
        _language = language;
        return;
      }
    }

    _language = language;
    _initializingRuntimeKey = runtimeKey;
    final initFuture = _initForLanguage(language).then((_) {
      _loadedRuntimeKey = runtimeKey;
    });
    _initFuture = initFuture;

    try {
      await initFuture;
    } finally {
      if (identical(_initFuture, initFuture)) {
        _initFuture = null;
        _initializingRuntimeKey = null;
      }
    }
  }

  Future<void> _initForLanguage(SacaLanguage language) async {
    if (_isSherpaWindowsPlatform) {
      await _initWindowsRecognizer();
      return;
    }

    if (_isWhisperKitPlatform) {
      await _initMobileRecognizer();
      return;
    }

    debugPrint('[SACA] No on-device STT runtime on this platform.');
    _whisper = null;
    _disposeWindowsRecognizer();
  }

  bool _isRuntimeReady(String runtimeKey) {
    if (_loadedRuntimeKey != runtimeKey) {
      return false;
    }

    if (_isSherpaWindowsPlatform) {
      return _windowsRecognizer != null;
    }

    if (_isWhisperKitPlatform) {
      return _whisper != null;
    }

    return true;
  }

  Future<String> _resolveRuntimeKey(SacaLanguage language) async {
    if (_isSherpaWindowsPlatform) {
      final bundle = await _resolveWindowsBundle(language: language);
      return 'windows:${bundle.supportDirName}';
    }

    if (_isWhisperKitPlatform) {
      if (language == SacaLanguage.gurindji) {
        final dir = await getApplicationDocumentsDirectory();
        final modelPath = '${dir.path}/ggml-gurindji-small-q5_0.bin';
        return File(modelPath).existsSync()
            ? 'mobile:gurindji-custom'
            : 'mobile:gurindji-small-fallback';
      }

      const assetPath = 'assets/models/whisper-base.en/ggml-base.en.bin';
      final hasBundledEnglishModel = await _assetExists(assetPath);
      return hasBundledEnglishModel ? 'mobile:base-en' : 'mobile:small';
    }

    return 'unsupported';
  }

  Future<bool> _assetExists(String assetPath) async {
    try {
      await rootBundle.load(assetPath);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Transcribe a WAV file at [audioPath]. Returns segments with timestamps.
  Future<List<TranscriptSegment>> transcribe(String audioPath) async {
    if (_isSherpaWindowsPlatform) {
      return _transcribeWindows(audioPath);
    }

    if (_isWhisperKitPlatform) {
      return _transcribeMobile(audioPath);
    }

    return const [];
  }

  void dispose() {
    _whisper = null;
    _loadedRuntimeKey = null;
    _initFuture = null;
    _initializingRuntimeKey = null;
    _disposeWindowsRecognizer();
  }
}
