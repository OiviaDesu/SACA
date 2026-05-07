class TranscriptSanitizer {
  const TranscriptSanitizer();

  static final RegExp _bracketNoise = RegExp(
    r'\[(?:music|singing|blank[_\s-]*audio|laughter|applause|silence|noise)\]',
    caseSensitive: false,
  );

  static final RegExp _plainNoise = RegExp(
    r'\b(?:music|singing|blank[_\s-]*audio|laughter|applause|silence)\b',
    caseSensitive: false,
  );

  String clean(String value) {
    return value
        .replaceAll(_bracketNoise, ' ')
        .replaceAll(_plainNoise, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool isUsable(String value) {
    final cleaned = clean(value);
    if (cleaned.isEmpty) return false;
    if (!RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(cleaned)) {
      return false;
    }
    return true;
  }
}
