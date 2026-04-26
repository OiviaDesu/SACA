import '../models/lexicon_entry.dart';

abstract interface class LexiconRepository {
  Future<List<LexiconEntry>> loadEntries();
}
