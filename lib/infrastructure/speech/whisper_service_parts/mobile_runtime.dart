part of '../whisper_service_io.dart';

extension _WhisperMobileRuntime on WhisperService {
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
          '[SACA] Gurindji model not found at $modelPath â€“ falling back to whisper-small.',
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
}
