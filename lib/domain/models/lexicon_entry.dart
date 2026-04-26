import 'dart:convert';

class LexiconEntry {
  const LexiconEntry({
    required this.gurindji,
    required this.english,
    required this.type,
  });

  final String gurindji;
  final String english;
  final String type;

  factory LexiconEntry.fromJson(Map<String, Object?> json) {
    return LexiconEntry(
      gurindji: (json['gurindji'] as String? ?? '').trim(),
      english: (json['english'] as String? ?? '').trim(),
      type: (json['type'] as String? ?? '').trim(),
    );
  }

  static List<LexiconEntry> listFromJson(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! List) return const <LexiconEntry>[];

    return decoded
        .whereType<Map<String, Object?>>()
        .map(LexiconEntry.fromJson)
        .where((entry) =>
            entry.gurindji.isNotEmpty &&
            entry.english.isNotEmpty &&
            entry.type.isNotEmpty)
        .toList(growable: false);
  }
}
