import '../models/lexicon_entry.dart';
import '../models/saca_models.dart';

class ClinicalTerm {
  const ClinicalTerm({
    required this.id,
    required this.englishLabel,
    this.gurindjiLabel,
  });

  final String id;
  final String englishLabel;
  final String? gurindjiLabel;

  bool get hasGurindji => gurindjiLabel?.trim().isNotEmpty ?? false;

  String labelFor(SacaLanguage? language) {
    if (language == SacaLanguage.gurindji && hasGurindji) {
      return gurindjiLabel!;
    }
    return englishLabel;
  }

  String compactLabelFor(SacaLanguage? language) {
    return labelFor(language).replaceAll('\n', ' / ');
  }
}

class ClinicalVocabularyService {
  const ClinicalVocabularyService._({
    required Map<String, ClinicalTerm> symptomTerms,
    required Map<String, ClinicalTerm> bodyAreaTerms,
    required Map<String, ClinicalTerm> resultTerms,
    required List<_NormalizationRule> normalizationRules,
  })  : _symptomTerms = symptomTerms,
        _bodyAreaTerms = bodyAreaTerms,
        _resultTerms = resultTerms,
        _normalizationRules = normalizationRules;

  const ClinicalVocabularyService.empty()
      : this._(
          symptomTerms: const <String, ClinicalTerm>{},
          bodyAreaTerms: const <String, ClinicalTerm>{},
          resultTerms: const <String, ClinicalTerm>{},
          normalizationRules: const <_NormalizationRule>[],
        );

  factory ClinicalVocabularyService.fromEntries(List<LexiconEntry> entries) {
    final index = _LexiconIndex(entries);

    ClinicalTerm? preferred({
      required String id,
      required String englishLabel,
      required String type,
      required String preferredGurindji,
      required String fallbackLookup,
    }) {
      final preferredEntry =
          index.findByGurindji(type: type, gurindji: preferredGurindji);
      if (preferredEntry != null) {
        return ClinicalTerm(
          id: id,
          englishLabel: englishLabel,
          gurindjiLabel: preferredEntry.gurindji,
        );
      }

      final fallbackEntry = index.find(type: type, english: fallbackLookup);
      if (fallbackEntry == null) return null;
      return ClinicalTerm(
        id: id,
        englishLabel: englishLabel,
        gurindjiLabel: fallbackEntry.gurindji,
      );
    }

    ClinicalTerm? exact({
      required String id,
      required String englishLabel,
      required String type,
      required String lookup,
    }) {
      final entry = index.find(type: type, english: lookup);
      if (entry == null) return null;
      return ClinicalTerm(
        id: id,
        englishLabel: englishLabel,
        gurindjiLabel: entry.gurindji,
      );
    }

    ClinicalTerm? phrase({
      required String id,
      required String englishLabel,
      required String gurindjiLabel,
    }) {
      return ClinicalTerm(
        id: id,
        englishLabel: englishLabel,
        gurindjiLabel: gurindjiLabel,
      );
    }

    final pain = exact(
          id: 'pain',
          englishLabel: 'Pain',
          type: 'symptom',
          lookup: 'ache',
        ) ??
        exact(
          id: 'pain',
          englishLabel: 'Pain',
          type: 'symptom',
          lookup: 'pain',
        );
    final painPhrase = exact(
      id: 'pain',
      englishLabel: 'Pain',
      type: 'symptom',
      lookup: 'pain',
    );
    final bleeding = exact(
      id: 'bleeding',
      englishLabel: 'Bleeding',
      type: 'symptom',
      lookup: 'bleed',
    );
    final illness = exact(
      id: 'illness',
      englishLabel: 'General symptoms',
      type: 'symptom',
      lookup: 'illness',
    );

    final bodyTerms = <String, ClinicalTerm>{
      if (preferred(
        id: 'head',
        englishLabel: 'Head',
        type: 'body',
        preferredGurindji: 'ngarlaka',
        fallbackLookup: 'head',
      )
          case final term?)
        'head': term,
      if (preferred(
        id: 'eyes',
        englishLabel: 'Eyes',
        type: 'body',
        preferredGurindji: 'mila',
        fallbackLookup: 'eye',
      )
          case final term?)
        'eyes': term,
      if (preferred(
        id: 'throat',
        englishLabel: 'Throat',
        type: 'body',
        preferredGurindji: 'ngirlkirri',
        fallbackLookup: 'throat',
      )
          case final term?)
        'throat': term,
      if (preferred(
        id: 'heart',
        englishLabel: 'Heart',
        type: 'body',
        preferredGurindji: 'mangarli',
        fallbackLookup: 'heart',
      )
          case final term?)
        'heart': term,
      if (preferred(
        id: 'chest',
        englishLabel: 'Chest',
        type: 'body',
        preferredGurindji: 'mangarli',
        fallbackLookup: 'chest',
      )
          case final term?)
        'chest': term,
      if (preferred(
        id: 'stomach',
        englishLabel: 'Stomach',
        type: 'body',
        preferredGurindji: 'majul',
        fallbackLookup: 'stomach',
      )
          case final term?)
        'stomach': term,
      if (preferred(
        id: 'hand',
        englishLabel: 'Hand',
        type: 'body',
        preferredGurindji: 'marla',
        fallbackLookup: 'hand',
      )
          case final term?)
        'hand': term,
      if (preferred(
        id: 'knees',
        englishLabel: 'Knees',
        type: 'body',
        preferredGurindji: 'tingarri',
        fallbackLookup: 'knee',
      )
          case final term?)
        'knees': term,
      if (preferred(
        id: 'toes',
        englishLabel: 'Toes',
        type: 'body',
        preferredGurindji: 'jamana nantananta',
        fallbackLookup: 'toes',
      )
          case final term?)
        'toes': term,
      if (preferred(
        id: 'ears',
        englishLabel: 'Ears',
        type: 'body',
        preferredGurindji: 'langa',
        fallbackLookup: 'ear',
      )
          case final term?)
        'ears': term,
      if (preferred(
        id: 'neck',
        englishLabel: 'Neck',
        type: 'body',
        preferredGurindji: 'wirri',
        fallbackLookup: 'neck',
      )
          case final term?)
        'neck': term,
      if (preferred(
        id: 'shoulder',
        englishLabel: 'Shoulder',
        type: 'body',
        preferredGurindji: 'laja',
        fallbackLookup: 'shoulder',
      )
          case final term?)
        'shoulder': term,
      if (preferred(
        id: 'back',
        englishLabel: 'Back',
        type: 'body',
        preferredGurindji: 'parntawurru',
        fallbackLookup: 'back',
      )
          case final term?)
        'back': term,
      if (preferred(
        id: 'arm',
        englishLabel: 'Arm',
        type: 'body',
        preferredGurindji: 'murna',
        fallbackLookup: 'arm',
      )
          case final term?)
        'arm': term,
      if (preferred(
        id: 'finger',
        englishLabel: 'Finger',
        type: 'body',
        preferredGurindji: 'wartan nantananta',
        fallbackLookup: 'finger',
      )
          case final term?)
        'finger': term,
      if (preferred(
        id: 'ankle',
        englishLabel: 'Ankle',
        type: 'body',
        preferredGurindji: 'tari',
        fallbackLookup: 'ankle',
      )
          case final term?)
        'ankle': term,
    };

    final symptomTerms = <String, ClinicalTerm>{
      if (exact(
        id: 'fever',
        englishLabel: 'Fever',
        type: 'symptom',
        lookup: 'fever',
      )
          case final term?)
        'fever': term,
      if (exact(
        id: 'cough',
        englishLabel: 'Cough',
        type: 'symptom',
        lookup: 'cough',
      )
          case final term?)
        'cough': term,
      if (exact(
        id: 'vomiting',
        englishLabel: 'Vomiting',
        type: 'symptom',
        lookup: 'vomit',
      )
          case final term?)
        'vomiting': term,
      if (exact(
        id: 'nausea_vomiting',
        englishLabel: 'Nausea or vomiting',
        type: 'symptom',
        lookup: 'vomit',
      )
          case final term?)
        'nausea_vomiting': term,
      if (phrase(
        id: 'headache',
        englishLabel: 'Headache',
        gurindjiLabel: 'ngarlaka pung',
      )
          case final term?)
        'headache': term,
      if (phrase(
        id: 'stomachache',
        englishLabel: 'Stomachache',
        gurindjiLabel: 'majul turlung',
      )
          case final term?)
        'stomachache': term,
      if (phrase(
        id: 'sore_throat',
        englishLabel: 'Sore throat',
        gurindjiLabel: 'ngirlkirri pung',
      )
          case final term?)
        'sore_throat': term,
      if (phrase(
        id: 'chest_pain',
        englishLabel: 'Chest pain',
        gurindjiLabel: 'mangarli pung',
      )
          case final term?)
        'chest_pain': term,
    };

    final normalizations = <_NormalizationRule>[
      for (final MapEntry(key: id, value: term) in symptomTerms.entries)
        if (term.hasGurindji)
          _NormalizationRule(
            term.gurindjiLabel!,
            <String>{id, term.englishLabel},
          ),
      for (final MapEntry(key: id, value: term) in bodyTerms.entries)
        if (term.hasGurindji)
          _NormalizationRule(
            term.gurindjiLabel!,
            <String>{id, term.englishLabel},
          ),
      if (pain?.hasGurindji ?? false)
        _NormalizationRule(pain!.gurindjiLabel!, <String>{'pain'}),
      if ((painPhrase?.hasGurindji ?? false) &&
          painPhrase!.gurindjiLabel != pain?.gurindjiLabel)
        _NormalizationRule(painPhrase.gurindjiLabel!, <String>{'pain'}),
      if (bleeding?.hasGurindji ?? false)
        _NormalizationRule(
          bleeding!.gurindjiLabel!,
          <String>{'bleeding', 'blood', 'severe bleeding'},
        ),
    ];

    return ClinicalVocabularyService._(
      symptomTerms: symptomTerms,
      bodyAreaTerms: bodyTerms,
      resultTerms: <String, ClinicalTerm>{
        if (illness != null) 'general symptoms': illness,
        if (bodyTerms['stomach'] case final stomach?)
          'stomach upset': ClinicalTerm(
            id: 'stomach_upset',
            englishLabel: 'Stomach upset',
            gurindjiLabel: stomach.gurindjiLabel,
          ),
      },
      normalizationRules: normalizations,
    );
  }

  final Map<String, ClinicalTerm> _symptomTerms;
  final Map<String, ClinicalTerm> _bodyAreaTerms;
  final Map<String, ClinicalTerm> _resultTerms;
  final List<_NormalizationRule> _normalizationRules;

  ClinicalTerm? symptomTerm(String id) => _symptomTerms[id];

  ClinicalTerm? bodyAreaTerm(String id) => _bodyAreaTerms[id];

  String symptomLabel(SacaLanguage? language, Symptom symptom) {
    return _symptomTerms[symptom.id]?.labelFor(language) ?? symptom.label;
  }

  String bodyAreaLabel(SacaLanguage? language, BodyArea area) {
    return _bodyAreaTerms[area.id]?.labelFor(language) ?? area.label;
  }

  String compactSymptomLabel(SacaLanguage? language, Symptom symptom) {
    return _symptomTerms[symptom.id]?.compactLabelFor(language) ??
        symptom.label;
  }

  String compactBodyAreaLabel(SacaLanguage? language, BodyArea area) {
    return _bodyAreaTerms[area.id]?.compactLabelFor(language) ?? area.label;
  }

  String resultDiseaseLabel(SacaLanguage? language, String disease) {
    if (language != SacaLanguage.gurindji) return disease;
    return _resultTerms[disease.toLowerCase()]?.labelFor(language) ?? disease;
  }

  AnalysisRequest normalizeRequest(AnalysisRequest request) {
    return request.copyWith(
      transcript: normalizeText(request.transcript),
      textInput: normalizeText(request.textInput),
      answers: request.answers.map(
        (key, value) => MapEntry(key, normalizeText(value)),
      ),
    );
  }

  String normalizeText(String input) {
    final normalizedInput = _normalizePhrase(input);
    if (normalizedInput.isEmpty) return input;

    final tokens = <String>{};
    for (final rule in _normalizationRules) {
      if (normalizedInput.contains(rule.normalizedPhrase)) {
        tokens.addAll(rule.canonicalTokens.map(_normalizePhrase));
      }
    }

    if (tokens.contains('chest') && tokens.contains('pain')) {
      tokens.add('chest pain');
    }
    if (tokens.contains('throat') && tokens.contains('pain')) {
      tokens.add('sore throat');
    }
    if (tokens.contains('head') && tokens.contains('pain')) {
      tokens.add('headache');
    }
    if (tokens.contains('stomach') && tokens.contains('pain')) {
      tokens.add('stomachache');
      tokens.add('stomach pain');
    }

    if (tokens.isEmpty) return input;
    return '$input ${tokens.join(' ')}';
  }
}

class _LexiconIndex {
  _LexiconIndex(List<LexiconEntry> entries) {
    for (final entry in entries) {
      _entriesByGurindji[
          '${entry.type}:${_normalizePhrase(entry.gurindji)}'] ??= entry;
      for (final variant in _englishVariants(entry.english)) {
        _entriesByLookup['${entry.type}:$variant'] ??= entry;
      }
    }
  }

  final Map<String, LexiconEntry> _entriesByLookup = <String, LexiconEntry>{};
  final Map<String, LexiconEntry> _entriesByGurindji = <String, LexiconEntry>{};

  LexiconEntry? find({required String type, required String english}) {
    return _entriesByLookup['$type:${_normalizePhrase(english)}'];
  }

  LexiconEntry? findByGurindji({
    required String type,
    required String gurindji,
  }) {
    return _entriesByGurindji['$type:${_normalizePhrase(gurindji)}'];
  }

  static Set<String> _englishVariants(String value) {
    final withoutParentheses =
        value.toLowerCase().replaceAll(RegExp(r'\([^)]*\)'), ' ');
    final parts = withoutParentheses
        .split(RegExp(r'[/;,]'))
        .map(_normalizePhrase)
        .where((part) => part.isNotEmpty)
        .toSet();
    parts.add(_normalizePhrase(withoutParentheses));
    return parts;
  }
}

class _NormalizationRule {
  _NormalizationRule(String phrase, this.canonicalTokens)
      : normalizedPhrase = _normalizePhrase(phrase);

  final String normalizedPhrase;
  final Set<String> canonicalTokens;
}

String _normalizePhrase(String value) {
  var normalized = value.toLowerCase();
  normalized = normalized.replaceAll('-', ' ');
  normalized = normalized.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
  normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
  for (final prefix in const [
    'the ',
    'to be in ',
    'to be ',
    'to ',
    'a ',
    'an ',
  ]) {
    if (normalized.startsWith(prefix)) {
      normalized = normalized.substring(prefix.length).trim();
    }
  }
  return normalized;
}
