// WhisperService â€“ platform service for on-device STT.
//
// - Windows: sherpa_onnx + bundled Whisper ONNX model
// - Android/iOS: whisper_kit + bundled GGML model

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'package:whisper_kit/whisper_kit.dart';

part 'whisper_service_parts/mobile_runtime.dart';
part 'whisper_service_parts/windows_runtime.dart';
part 'whisper_service_parts/whisper_asset_bundle.dart';

enum SacaLanguage { english, gurindji }

class SacaSttModelAssets {
  const SacaSttModelAssets._();

  static const rc1Label = 'gue-whisper-base-run4-ckpt200-rc1';
  static const rc1MobileAssetBase = 'assets/models/whisper-gue-base-run4-rc1';
  static const rc1MobileFileName =
      'ggml-gue-whisper-base-run4-ckpt200-rc1-q5_0.bin';
  static const rc1MobileAssetPath = '$rc1MobileAssetBase/$rc1MobileFileName';
  static const rc1WindowsAssetBase =
      'assets/models/sherpa-onnx-whisper-gue-base-run4-rc1';
  static const rc1WindowsSupportDirName =
      'sherpa-onnx-whisper-gue-base-run4-rc1';
  static const windowsRequiredFiles = <String>[
    'encoder.onnx',
    'decoder.onnx',
    'tokens.txt',
  ];

  static String windowsLanguageCode(SacaLanguage language) {
    return switch (language) {
      SacaLanguage.english => 'en',
      SacaLanguage.gurindji => '',
    };
  }

  static String windowsRuntimeKey(SacaLanguage language) {
    return '$rc1WindowsSupportDirName:${language.name}';
  }
}

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

class WhisperTranscriptionOptions {
  const WhisperTranscriptionOptions({
    this.isNoTimestamps = false,
    this.splitOnWord = true,
  });

  final bool isNoTimestamps;
  final bool splitOnWord;

  static const dictation = WhisperTranscriptionOptions();
  static const command = WhisperTranscriptionOptions(
    isNoTimestamps: true,
    splitOnWord: false,
  );
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
    assetBase: SacaSttModelAssets.rc1WindowsAssetBase,
    supportDirName: SacaSttModelAssets.rc1WindowsSupportDirName,
    label: SacaSttModelAssets.rc1Label,
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
      return 'windows:${SacaSttModelAssets.windowsRuntimeKey(language)}';
    }

    if (_isWhisperKitPlatform) {
      final hasRc1Model = await _assetExists(
        SacaSttModelAssets.rc1MobileAssetPath,
      );
      return hasRc1Model
          ? 'mobile:${SacaSttModelAssets.rc1Label}'
          : 'mobile:base-fallback';
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
  Future<List<TranscriptSegment>> transcribe(
    String audioPath, {
    WhisperTranscriptionOptions options = WhisperTranscriptionOptions.dictation,
  }) async {
    if (_isSherpaWindowsPlatform) {
      return _transcribeWindows(audioPath);
    }

    if (_isWhisperKitPlatform) {
      return _transcribeMobile(audioPath, options: options);
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
