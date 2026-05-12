class TranscriptSanitizer {
  const TranscriptSanitizer();

  static final RegExp _wrappedNoise = RegExp(
    r'[\[\(<]\s*(?:music|singing|blank[_\s-]*audio|laughter|applause|silence|noise|cough(?:ing|s)?|chok(?:e|ing|ed)|gasp(?:ing|ed)?|breath(?:ing|e)?|wheez(?:e|ing|ed))\s*[\]\)>]',
    caseSensitive: false,
  );

  static final RegExp _plainNoise = RegExp(
    r'\b(?:music|singing|blank[_\s-]*audio|laughter|applause|silence)\b',
    caseSensitive: false,
  );

  String clean(String value) {
    return value
        .replaceAll(_wrappedNoise, ' ')
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
