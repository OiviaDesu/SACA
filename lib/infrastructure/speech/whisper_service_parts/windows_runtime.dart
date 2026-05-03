part of '../whisper_service_io.dart';

extension _WhisperWindowsRuntime on WhisperService {
  Future<void> _initWindowsRecognizer() async {
    _ensureSherpaBindingsInitialized();
    final bundle = await _resolveWindowsBundle(language: _language);
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
    if (WhisperService._sherpaBindingsInitialized) return;
    sherpa.initBindings();
    WhisperService._sherpaBindingsInitialized = true;
  }

  Future<_WhisperAssetBundle> _resolveWindowsBundle({
    required SacaLanguage language,
  }) async {
    if (language != SacaLanguage.english) {
      return WhisperService._defaultWindowsBundle;
    }

    final hasEnglishBundle = await _assetExists(
      '${WhisperService._englishWindowsBundle.assetBase}/encoder.onnx',
    );
    if (hasEnglishBundle) {
      debugPrint(
        '[SACA] Windows English STT: using bundled ${WhisperService._englishWindowsBundle.label}.',
      );
      return WhisperService._englishWindowsBundle;
    }

    debugPrint(
      '[SACA] Windows English STT: no English-only ONNX bundle found; using ${WhisperService._defaultWindowsBundle.label}.',
    );
    return WhisperService._defaultWindowsBundle;
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

  void _disposeWindowsRecognizer() {
    _windowsRecognizer?.free();
    _windowsRecognizer = null;
  }
}
