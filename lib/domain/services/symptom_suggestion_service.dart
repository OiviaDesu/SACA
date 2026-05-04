import '../models/saca_models.dart';

abstract interface class SymptomSuggestionService {
  List<String> suggestRelatedSymptoms(AnalysisRequest request);

  Future<List<String>> refineRelatedSymptoms(AnalysisRequest request);
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
    suggestions.removeAll(request.selectedSymptomIds);
    return _orderedRelatedSymptoms(suggestions);
  }

  @override
  Future<List<String>> refineRelatedSymptoms(AnalysisRequest request) async {
    return suggestRelatedSymptoms(request);
  }

  static List<String> orderedRelatedSymptoms(Iterable<String> ids) {
    return _orderedRelatedSymptoms(ids);
  }

  static List<String> _orderedRelatedSymptoms(Iterable<String> ids) {
    final idSet = ids.toSet();
    return [
      for (final symptom in SacaFlowState.relatedSymptoms)
        if (symptom.id != 'none' && idSet.contains(symptom.id)) symptom.id,
    ];
  }
}
