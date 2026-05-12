// WhisperService â€“ platform service for on-device STT.
//
// - Windows/macOS: sherpa_onnx + bundled Whisper ONNX model
// - Android/iOS: whisper_kit + bundled GGML model

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'package:whisper_kit/whisper_kit.dart';

import '../../core/runtime/runtime_acceleration_policy.dart';

part 'whisper_service_parts/mobile_runtime.dart';
part 'whisper_service_parts/windows_runtime.dart';
part 'whisper_service_parts/whisper_asset_bundle.dart';

enum SacaLanguage { english, gurindji }

enum _SpeechRuntimeFamily { desktopSherpa, mobileWhisperKit, unsupported }

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

  _SpeechRuntimeFamily get _runtimeFamily {
    if (Platform.isWindows || Platform.isMacOS) {
      return _SpeechRuntimeFamily.desktopSherpa;
    }
    if (Platform.isAndroid || Platform.isIOS) {
      return _SpeechRuntimeFamily.mobileWhisperKit;
    }
    return _SpeechRuntimeFamily.unsupported;
  }

  bool get _usesWhisperKit =>
      _runtimeFamily == _SpeechRuntimeFamily.mobileWhisperKit;
  bool get _usesDesktopSherpa =>
      _runtimeFamily == _SpeechRuntimeFamily.desktopSherpa;
  bool get supportsOnDeviceStt =>
      _runtimeFamily != _SpeechRuntimeFamily.unsupported;

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
    if (_usesDesktopSherpa) {
      await _initWindowsRecognizer();
      return;
    }

    if (_usesWhisperKit) {
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

    if (_usesDesktopSherpa) {
      return _windowsRecognizer != null;
    }

    if (_usesWhisperKit) {
      return _whisper != null;
    }

    return true;
  }

  Future<String> _resolveRuntimeKey(SacaLanguage language) async {
    if (_usesDesktopSherpa) {
      return 'desktop:${SacaSttModelAssets.windowsRuntimeKey(language)}';
    }

    if (_usesWhisperKit) {
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
    if (_usesDesktopSherpa) {
      return _transcribeWindows(audioPath);
    }

    if (_usesWhisperKit) {
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
