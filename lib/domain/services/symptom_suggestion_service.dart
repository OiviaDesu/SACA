import '../models/saca_models.dart';

abstract interface class SymptomSuggestionService {
  List<String> suggestRelatedSymptoms(AnalysisRequest request);

  Future<List<String>> refineRelatedSymptoms(AnalysisRequest request);
}

abstract interface class NonSpeechSuggestionService {
  List<String> reviewOnlySuggestions(AnalysisRequest request);
}

class SafeNonSpeechSuggestionService implements NonSpeechSuggestionService {
  const SafeNonSpeechSuggestionService();

  @override
  List<String> reviewOnlySuggestions(AnalysisRequest request) {
    final features = request.speechSignalFeatures;
    if (features == null || !features.hasUsableSignals) {
      return const <String>[];
    }

    final suggestions = <String>{};
    final hasCoughCue = features.cues.any(
      (cue) => cue.kind == 'cough' && cue.confidence >= 0.55,
    );
    if (hasCoughCue) {
      suggestions.add('cough');
    }

    final input = request.combinedInput.toLowerCase();
    final hasAirwayContext = request.selectedBodyAreaIds.contains('chest') ||
        request.selectedBodyAreaIds.contains('throat') ||
        input.contains('chest') ||
        input.contains('throat') ||
        input.contains('breath');
    final hasBreathingCue = features.cues.any(
      (cue) =>
          (cue.kind == 'choke' ||
              cue.kind == 'gasp' ||
              cue.kind == 'breath' ||
              cue.kind == 'wheeze') &&
          cue.confidence >= 0.55,
    );
    if (hasAirwayContext && hasBreathingCue) {
      suggestions.add('breathing_trouble');
    }

    suggestions.removeAll(RuleBasedSymptomSuggestionService.knownSymptomIds(
      request,
    ));
    return RuleBasedSymptomSuggestionService.orderedRelatedSymptoms(
      suggestions,
    );
  }
}

class RuleBasedSymptomSuggestionService implements SymptomSuggestionService {
  const RuleBasedSymptomSuggestionService();

  static const Map<String, List<String>> _keywordSuggestions = {
    'fever': ['cough', 'sore_throat', 'headache'],
    'cold': ['cough', 'sore_throat', 'headache'],
    'flu': ['cough', 'sore_throat', 'headache'],
    'cough': ['sore_throat', 'breathing_trouble', 'chest_pain'],
    'throat': ['cough', 'headache'],
    'headache': ['fever', 'nausea_vomiting'],
    'stomach': ['nausea_vomiting'],
    'belly': ['nausea_vomiting'],
    'nausea': ['nausea_vomiting'],
    'vomit': ['nausea_vomiting'],
    'rash': ['rash'],
    'itch': ['rash'],
    'chest': ['chest_pain', 'breathing_trouble'],
    'breath': ['breathing_trouble', 'chest_pain'],
  };

  static const Map<String, List<String>> _selectedSymptomSuggestions = {
    'fever': ['cough', 'sore_throat', 'headache'],
    'headache': ['fever', 'nausea_vomiting'],
    'stomachache': ['nausea_vomiting'],
    'sore_throat': ['cough', 'fever', 'headache'],
    'chest_pain': ['breathing_trouble'],
    'breathing_trouble': ['chest_pain', 'cough'],
    'vomiting': ['nausea_vomiting'],
    'bloating': ['nausea_vomiting'],
  };

  static const Map<String, List<String>> _knownSymptomTerms = {
    'headache': ['headache', 'head pain'],
    'fever': ['fever', 'temperature', 'hot body'],
    'stomachache': ['stomachache', 'stomach ache', 'belly pain'],
    'sore_throat': ['sore throat', 'throat pain'],
    'chest_pain': ['chest pain'],
    'breathing_trouble': [
      'breathing trouble',
      'trouble breathing',
      'cannot breathe',
      'can not breathe',
      'shortness of breath',
      'short of breath',
      'wheezing',
    ],
    'vomiting': ['vomiting', 'vomit', 'throwing up'],
    'bloating': ['bloating', 'bloated'],
    'cough': ['cough', 'coughing', 'coughs'],
    'nausea_vomiting': ['nausea', 'nauseous', 'vomiting', 'vomit'],
    'rash': ['rash', 'skin itch', 'itchy skin'],
  };

  @override
  List<String> suggestRelatedSymptoms(AnalysisRequest request) {
    final suggestions = <String>{};
    final input = request.combinedInput.toLowerCase();

    for (final id in request.selectedSymptomIds) {
      suggestions.addAll(_selectedSymptomSuggestions[id] ?? const <String>[]);
    }

    for (final entry in _keywordSuggestions.entries) {
      if (input.contains(entry.key)) {
        suggestions.addAll(entry.value);
      }
    }

    suggestions.remove('none');
    suggestions.removeAll(knownSymptomIds(request));
    return _orderedRelatedSymptoms(suggestions);
  }

  @override
  Future<List<String>> refineRelatedSymptoms(AnalysisRequest request) async {
    return suggestRelatedSymptoms(request);
  }

  static List<String> orderedRelatedSymptoms(Iterable<String> ids) {
    return _orderedRelatedSymptoms(ids);
  }

  static Set<String> knownSymptomIds(AnalysisRequest request) {
    final known = <String>{...request.selectedSymptomIds};
    final input = request.combinedInput.toLowerCase();
    for (final entry in _knownSymptomTerms.entries) {
      if (entry.value.any(input.contains)) {
        known.add(entry.key);
      }
    }
    return known;
  }

  static List<String> _orderedRelatedSymptoms(Iterable<String> ids) {
    final idSet = ids.toSet();
    return [
      for (final symptom in SacaFlowState.relatedSymptoms)
        if (symptom.id != 'none' && idSet.contains(symptom.id)) symptom.id,
    ];
  }
}
