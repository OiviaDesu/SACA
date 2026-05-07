// Whisper service stub for web builds (no dart:ffi support).

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

  bool get supportsOnDeviceStt => false;

  Future<void> init({SacaLanguage language = SacaLanguage.english}) async {
    // Web fallback only; primary runtime target is Windows desktop.
  }

  Future<List<TranscriptSegment>> transcribe(
    String audioPath, {
    WhisperTranscriptionOptions options = WhisperTranscriptionOptions.dictation,
  }) async {
    return const [];
  }

  void dispose() {}
}
