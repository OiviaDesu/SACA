import 'package:flutter/services.dart';

import '../../domain/models/lexicon_entry.dart';
import '../../domain/services/lexicon_repository.dart';

class AssetLexiconRepository implements LexiconRepository {
  const AssetLexiconRepository({
    AssetBundle? bundle,
    this.assetPath = 'assets/data/gurindji_lexicon.json',
  }) : _bundle = bundle;

  final AssetBundle? _bundle;
  final String assetPath;

  @override
  Future<List<LexiconEntry>> loadEntries() async {
    final source = await (_bundle ?? rootBundle).loadString(assetPath);
    return LexiconEntry.listFromJson(source);
  }
}
