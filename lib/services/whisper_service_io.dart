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
    _language = language;

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

  Future<void> _initMobileRecognizer() async {
    if (!_isWhisperKitPlatform) {
      _whisper = null;
      return;
    }

    if (_language == SacaLanguage.gurindji) {
      // Phase 2: custom fine-tuned model bundled in assets
      final dir = await getApplicationDocumentsDirectory();
      final modelPath = '${dir.path}/ggml-gurindji-small-q5_0.bin';

      if (!File(modelPath).existsSync()) {
        debugPrint(
          '[SACA] Gurindji model not found at $modelPath – falling back to whisper-small.',
        );
        _whisper = const Whisper(model: WhisperModel.small);
        return;
      }

      _whisper = Whisper(
        model: WhisperModel.none,
        modelDir: dir.path,
        // Override download host so whisper_kit won't try to fetch online.
        downloadHost: 'file://${dir.path}',
      );
      return;
    }

    final englishModelDir = await _prepareBundledEnglishMobileModel();
    if (englishModelDir != null) {
      debugPrint(
        '[SACA] Mobile English STT: using bundled ggml-base.en.bin via WhisperModel.base alias.',
      );
      _whisper = Whisper(
        model: WhisperModel.base,
        modelDir: englishModelDir.path,
      );
      return;
    }

    // Current whisper_kit runtime does not expose .en model enums.
    debugPrint(
      '[SACA] Mobile English STT: no bundled .en model found and whisper_kit 0.3.0 has no .en enum; falling back to multilingual whisper-small.',
    );
    _whisper = Whisper(
      model: WhisperModel.small,
      onDownloadProgress: (received, total) {
        if (total > 0) {
          debugPrint(
            '[SACA] Model download: ${(received / total * 100).toStringAsFixed(1)}%',
          );
        }
      },
    );
  }

  Future<void> _initWindowsRecognizer() async {
    _ensureSherpaBindingsInitialized();
    final bundle = await _resolveWindowsBundle();
    final modelDir = await _ensureWindowsModelFiles(bundle);
    final sep = Platform.pathSeparator;

    final modelConfig = sherpa.OfflineModelConfig(
      whisper: sherpa.OfflineWhisperModelConfig(
        encoder: '${modelDir.path}${sep}encoder.onnx',
        decoder: '${modelDir.path}${sep}decoder.onnx',
        language: 'en',
        task: 'transcribe',
      ),
      tokens: '${modelDir.path}${sep}tokens.txt',
      modelType: 'whisper',
      provider: 'cpu',
      numThreads: 4,
      debug: false,
    );

    final config = sherpa.OfflineRecognizerConfig(model: modelConfig);

    _disposeWindowsRecognizer();
    _windowsRecognizer = sherpa.OfflineRecognizer(config);

    debugPrint('[SACA] Windows ${bundle.label} loaded from ${modelDir.path}');
  }

  void _ensureSherpaBindingsInitialized() {
    if (_sherpaBindingsInitialized) return;
    sherpa.initBindings();
    _sherpaBindingsInitialized = true;
  }

  Future<Directory?> _prepareBundledEnglishMobileModel() async {
    if (_language != SacaLanguage.english || !_isWhisperKitPlatform) {
      return null;
    }

    const assetPath = 'assets/models/whisper-base.en/ggml-base.en.bin';
    final hasBundledEnglishModel = await _assetExists(assetPath);
    if (!hasBundledEnglishModel) {
      return null;
    }

    final modelDir = await _getWhisperKitModelDirectory();
    final targetFile = File('${modelDir.path}/ggml-base.bin');

    if (await targetFile.exists()) {
      return modelDir;
    }

    try {
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      await targetFile.writeAsBytes(bytes, flush: true);
      return modelDir;
    } catch (_) {
      return null;
    }
  }

  Future<Directory> _getWhisperKitModelDirectory() async {
    if (Platform.isAndroid) {
      return getApplicationSupportDirectory();
    }
    return getLibraryDirectory();
  }

  Future<_WhisperAssetBundle> _resolveWindowsBundle() async {
    if (_language != SacaLanguage.english) {
      return _defaultWindowsBundle;
    }

    final hasEnglishBundle = await _assetExists(
      '${_englishWindowsBundle.assetBase}/encoder.onnx',
    );
    if (hasEnglishBundle) {
      debugPrint(
        '[SACA] Windows English STT: using bundled ${_englishWindowsBundle.label}.',
      );
      return _englishWindowsBundle;
    }

    debugPrint(
      '[SACA] Windows English STT: no English-only ONNX bundle found; using ${_defaultWindowsBundle.label}.',
    );
    return _defaultWindowsBundle;
  }

  Future<bool> _assetExists(String assetPath) async {
    try {
      await rootBundle.load(assetPath);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Directory> _ensureWindowsModelFiles(_WhisperAssetBundle bundle) async {
    const requiredFiles = ['encoder.onnx', 'decoder.onnx', 'tokens.txt'];

    final supportDir = await getApplicationSupportDirectory();
    final sep = Platform.pathSeparator;
    final targetDir =
        Directory('${supportDir.path}$sep${bundle.supportDirName}');

    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    for (final fileName in requiredFiles) {
      final targetFile = File('${targetDir.path}$sep$fileName');
      if (await targetFile.exists()) continue;

      final assetPath = '${bundle.assetBase}/$fileName';
      try {
        final data = await rootBundle.load(assetPath);
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        await targetFile.writeAsBytes(bytes, flush: true);
      } catch (e) {
        throw Exception(
          'Missing model asset: $assetPath.\n'
          'Please place the required model files under ${bundle.assetBase}/.\n'
          'Original error: $e',
        );
      }
    }

    return targetDir;
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

  Future<List<TranscriptSegment>> _transcribeWindows(String audioPath) async {
    if (_windowsRecognizer == null) {
      await _initWindowsRecognizer();
    }

    final recognizer = _windowsRecognizer;
    if (recognizer == null) {
      throw Exception('Windows Whisper recognizer was not initialized.');
    }

    final wave = sherpa.readWave(audioPath);
    if (wave.samples.isEmpty || wave.sampleRate <= 0) {
      return const [];
    }

    final stream = recognizer.createStream();
    try {
      stream.acceptWaveform(samples: wave.samples, sampleRate: wave.sampleRate);
      recognizer.decode(stream);
      final result = recognizer.getResult(stream);

      final text = result.text.trim();
      if (text.isEmpty) {
        return const [];
      }

      final durationMs =
          ((wave.samples.length / wave.sampleRate) * 1000).round();
      final safeDuration =
          Duration(milliseconds: durationMs < 0 ? 0 : durationMs);

      return [
        TranscriptSegment(
          text: text,
          from: Duration.zero,
          to: safeDuration,
        ),
      ];
    } finally {
      stream.free();
    }
  }

  Future<List<TranscriptSegment>> _transcribeMobile(String audioPath) async {
    if (!_isWhisperKitPlatform) {
      return const [];
    }

    if (_whisper == null) {
      await _initMobileRecognizer();
    }

    if (_whisper == null) {
      return const [
        TranscriptSegment(
          text: 'Whisper model is not initialized yet.',
          from: Duration.zero,
          to: Duration.zero,
        ),
      ];
    }

    // Note: Whisper does not have a 'gu' language token. For Gurindji,
    // we use the fine-tuned model with forced language='en'.
    const langCode = 'en';

    final request = TranscribeRequest(
      audio: audioPath,
      language: langCode,
      isNoTimestamps: false,
      splitOnWord: true,
      threads: 4,
    );

    final response = await _whisper!.transcribe(transcribeRequest: request);
    final segments = response.segments;

    if (segments != null && segments.isNotEmpty) {
      return segments
          .map(
            (s) => TranscriptSegment(
              text: s.text.trim(),
              from: _toDuration(s.fromTs),
              to: _toDuration(s.toTs),
            ),
          )
          .toList();
    }

    // Fallback: single segment from full text
    return [
      TranscriptSegment(
        text: response.text.trim(),
        from: Duration.zero,
        to: Duration.zero,
      ),
    ];
  }

  Duration _toDuration(dynamic ts) {
    if (ts == null) return Duration.zero;

    if (ts is Duration) {
      return ts;
    }

    if (ts is num) {
      // Assume seconds when numeric timestamps are returned.
      return Duration(milliseconds: (ts * 1000).round());
    }

    if (ts is String) {
      final input = ts.trim();
      if (input.isEmpty) return Duration.zero;

      // Try numeric-string first (seconds)
      final numeric = double.tryParse(input.replaceAll(',', '.'));
      if (numeric != null) {
        return Duration(milliseconds: (numeric * 1000).round());
      }

      // Then try HH:MM:SS,mmm or MM:SS.mmm
      try {
        final parts = input.replaceAll(',', '.').split(':');
        if (parts.length == 3) {
          return Duration(
            hours: int.parse(parts[0]),
            minutes: int.parse(parts[1]),
            milliseconds: (double.parse(parts[2]) * 1000).round(),
          );
        }
        if (parts.length == 2) {
          return Duration(
            minutes: int.parse(parts[0]),
            milliseconds: (double.parse(parts[1]) * 1000).round(),
          );
        }
      } catch (_) {
        return Duration.zero;
      }
    }

    return Duration.zero;
  }

  void dispose() {
    _whisper = null;
    _disposeWindowsRecognizer();
  }

  void _disposeWindowsRecognizer() {
    _windowsRecognizer?.free();
    _windowsRecognizer = null;
  }
}

class _WhisperAssetBundle {
  const _WhisperAssetBundle({
    required this.assetBase,
    required this.supportDirName,
    required this.label,
  });

  final String assetBase;
  final String supportDirName;
  final String label;
}
