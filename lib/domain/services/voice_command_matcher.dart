import '../models/saca_models.dart';
import 'duration_interpreter.dart';

class VoiceCommandAnswer {
  const VoiceCommandAnswer(this.questionId, this.value);

  final String questionId;
  final String value;
}

class VoiceCommandMatcher {
  const VoiceCommandMatcher({
    DurationInterpreter durationInterpreter = const DurationInterpreter(),
  }) : _durationInterpreter = durationInterpreter;

  final DurationInterpreter _durationInterpreter;

  VoiceCommandAnswer? match(SacaStep step, String transcript) {
    final normalized = _normalize(transcript);
    if (normalized.isEmpty) return null;
    return switch (step) {
      SacaStep.questionSeverity => _severityVoiceAnswer(normalized),
      SacaStep.questionDuration => _durationVoiceAnswer(normalized) ??
          _choiceVoiceAnswer('duration', normalized, _durationChoices),
      SacaStep.questionRelatedSymptoms =>
        _relatedSymptomsVoiceAnswer(normalized),
      SacaStep.questionMedication =>
        _choiceVoiceAnswer('medication', normalized, _medicationChoices),
      SacaStep.questionFood =>
        _choiceVoiceAnswer('food', normalized, _foodChoices),
      SacaStep.questionAllergies =>
        _choiceVoiceAnswer('allergies', normalized, _allergyChoices),
      SacaStep.questionHealthChanges => _choiceVoiceAnswer(
          'health_changes',
          normalized,
          _healthChangeChoices,
        ),
      _ => null,
    };
  }

  VoiceCommandAnswer? _severityVoiceAnswer(String normalized) {
    const words = {
      'one': 1,
      'won': 1,
      'jintaku': 1,
      'two': 2,
      'too': 2,
      'to': 2,
      'kujarra': 2,
      'three': 3,
      'tree': 3,
      'murrkun': 3,
      'four': 4,
      'for': 4,
      'kujarra kujarra': 4,
      'five': 5,
      'fife': 5,
      'ngarra': 5,
      'six': 6,
      'seven': 7,
      'eight': 8,
      'ate': 8,
      'nine': 9,
      'ten': 10,
    };
    final numericMatch = RegExp(r'\b(10|[1-9])\b').firstMatch(normalized);
    var value = numericMatch == null ? null : int.parse(numericMatch.group(1)!);
    for (final entry in words.entries) {
      if (value == null && _containsPhrase(normalized, entry.key)) {
        value = entry.value;
      }
    }
    if (value == null) {
      if (_containsAny(normalized, const ['emergency', 'extreme'])) value = 10;
      if (_containsAny(normalized, const ['severe', 'bad pain', 'warlarrp'])) {
        value = 9;
      }
      if (_containsAny(normalized, const ['moderate', 'medium'])) value = 5;
      if (_containsAny(normalized, const ['mild', 'small pain', 'yamak'])) {
        value = 2;
      }
    }
    return value == null
        ? null
        : VoiceCommandAnswer('severity', value.clamp(1, 10).toString());
  }

  VoiceCommandAnswer? _durationVoiceAnswer(String normalized) {
    final interpreted = _durationInterpreter.fromVoice(normalized);
    if (interpreted == null) return null;
    return VoiceCommandAnswer('duration', interpreted.answer);
  }

  VoiceCommandAnswer? _choiceVoiceAnswer(
    String questionId,
    String normalized,
    Map<String, List<String>> choices,
  ) {
    for (final entry in choices.entries) {
      if (_matchesAnyVoiceKeyword(normalized, entry.value)) {
        return VoiceCommandAnswer(questionId, entry.key);
      }
    }
    return null;
  }

  bool _matchesAnyVoiceKeyword(String normalized, List<String> keywords) {
    for (final keyword in keywords) {
      final normalizedKeyword = _normalize(keyword);
      if (normalizedKeyword.isEmpty) continue;
      if (normalized == normalizedKeyword) return true;
    }
    for (final keyword in keywords) {
      final normalizedKeyword = _normalize(keyword);
      if (normalizedKeyword.isEmpty) continue;
      if (_containsPhrase(normalized, normalizedKeyword)) return true;
    }
    for (final keyword in keywords) {
      final normalizedKeyword = _normalize(keyword);
      if (normalizedKeyword.isEmpty) continue;
      if (_safeFuzzyPhraseMatch(normalized, normalizedKeyword)) return true;
    }
    return false;
  }

  VoiceCommandAnswer? _relatedSymptomsVoiceAnswer(String normalized) {
    final matches = <String>{};
    for (final symptom in SacaFlowState.relatedSymptoms) {
      final terms = <String>{
        symptom.label,
        symptom.id.replaceAll('_', ' '),
        ...?_relatedSymptomAliases[symptom.id],
      };
      if (_matchesAnyVoiceKeyword(normalized, terms.toList())) {
        matches.add(symptom.id);
      }
    }
    if (matches.isEmpty) return null;
    if (matches.contains('none')) {
      return const VoiceCommandAnswer('related_symptoms', 'none');
    }
    matches.remove('none');
    return VoiceCommandAnswer('related_symptoms', matches.join('|'));
  }

  bool _containsAny(String normalized, List<String> phrases) {
    return phrases
        .any((phrase) => _containsPhrase(normalized, _normalize(phrase)));
  }

  bool _containsPhrase(String normalized, String phrase) {
    return ' $normalized '.contains(' $phrase ');
  }

  bool _safeFuzzyPhraseMatch(String normalized, String keyword) {
    final normalizedTokens =
        normalized.split(' ').where((token) => token.isNotEmpty);
    final keywordTokens =
        keyword.split(' ').where((token) => token.isNotEmpty).toList();
    if (keywordTokens.isEmpty) return false;
    if (keywordTokens.length == 1 && keywordTokens.first.length < 5) {
      return false;
    }
    var hits = 0;
    for (final keywordToken in keywordTokens) {
      if (normalizedTokens.any((token) => _closeToken(token, keywordToken))) {
        hits++;
      }
    }
    final score = hits / keywordTokens.length;
    return score >= 0.85;
  }

  bool _closeToken(String left, String right) {
    if (left == right) return true;
    if (left.length < 5 || right.length < 5) return false;
    return _levenshtein(left, right) <= 1;
  }

  int _levenshtein(String left, String right) {
    final previous = List<int>.generate(right.length + 1, (index) => index);
    final current = List<int>.filled(right.length + 1, 0);
    for (var leftIndex = 0; leftIndex < left.length; leftIndex++) {
      current[0] = leftIndex + 1;
      for (var rightIndex = 0; rightIndex < right.length; rightIndex++) {
        final substitutionCost =
            left.codeUnitAt(leftIndex) == right.codeUnitAt(rightIndex) ? 0 : 1;
        current[rightIndex + 1] = [
          current[rightIndex] + 1,
          previous[rightIndex + 1] + 1,
          previous[rightIndex] + substitutionCost,
        ].reduce((value, element) => value < element ? value : element);
      }
      for (var index = 0; index < previous.length; index++) {
        previous[index] = current[index];
      }
    }
    return previous[right.length];
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'>\s*7'), 'more than 7')
        .replaceAll(RegExp(r'>\s*seven'), 'more than seven')
        .replaceAll(RegExp(r'<\s*1'), 'less than 1')
        .replaceAll(RegExp(r'<\s*one'), 'less than one')
        .replaceAll(RegExp(r'\byep\b'), 'yes')
        .replaceAll(RegExp(r'\byeah\b'), 'yes')
        .replaceAll(RegExp(r'\bnope\b'), 'no')
        .replaceAll(RegExp(r'\bdunno\b'), 'not sure')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }
}

const _durationChoices = <String, List<String>>{
  'more than seven days': [
    'more than seven days',
    'more than 7 days',
    'more than seven',
    'more than 7',
    'over seven days',
    'over 7 days',
    'over seven',
    'over 7',
    'greater than seven',
    'greater than 7',
    'longer than seven',
    'longer than 7',
    'after seven days',
    'after 7 days',
    'seven plus',
    '7 plus',
    'above seven',
    'above 7',
    'more than week',
  ],
  'four to seven days': [
    'four to seven days',
    '4 to 7 days',
    'four seven days',
    '4 7 days',
    'four to seven',
    '4 to 7',
    'four seven',
    '4 7',
    'one week',
    'a week',
    'week',
  ],
  'one to three days': [
    'one to three days',
    '1 to 3 days',
    'one three days',
    '1 3 days',
    'one to three',
    '1 to 3',
    'one three',
    '1 3',
    'three days',
    '3 days',
  ],
  'less than one day': [
    'less than one day',
    'less than 1 day',
    'under one day',
    'under 1 day',
    'less than day',
    'today',
    'jala',
  ],
};

const _medicationChoices = <String, List<String>>{
  'not sure medication': ['not sure medication', 'not sure', 'unsure', 'maybe'],
  'taken medication': [
    'taken medication',
    'yes',
    'yuwayi',
    'medicine',
    'medication',
    'mirrijin',
  ],
  'no medication': ['no medication', 'none medication', 'no', 'none', 'lawara'],
};

const _foodChoices = <String, List<String>>{
  'not sure food': ['not sure food', 'not sure', 'unsure', 'maybe'],
  'skipped meals': ['skipped meals', 'skipped', 'missed meal', 'not eating'],
  'unfamiliar food': [
    'unfamiliar food',
    'unfamiliar',
    'new food',
    'different food'
  ],
  'no food change': [
    'no food change',
    'no change',
    'same food',
    'normal food',
    'no',
    'lawara'
  ],
};

const _allergyChoices = <String, List<String>>{
  'not sure allergies': [
    'not sure allergies',
    'not sure allergy',
    'not sure',
    'unsure',
    'maybe',
  ],
  'no known allergies': [
    'no known allergies',
    'no known allergy',
    'no allergies',
    'no allergy',
    'no known',
    'none',
    'no',
    'lawara',
  ],
  'possible allergies': ['allergy', 'allergies', 'yes', 'yuwayi'],
};

const _healthChangeChoices = <String, List<String>>{
  'sick contact or travel': ['sick contact', 'travel', 'someone sick'],
  'sleep or stress change': ['sleep', 'stress', 'tired'],
  'not sure health change': ['not sure health', 'not sure', 'unsure', 'maybe'],
  'no recent health change': [
    'no recent health change',
    'no health change',
    'no change',
    'normal',
    'no',
    'lawara',
  ],
};

const _relatedSymptomAliases = <String, List<String>>{
  'none': [
    'no related symptoms',
    'no other symptoms',
    'nothing else',
    'lawara'
  ],
  'cough': ['coughing', 'kulyurrk'],
  'fever': ['hot', 'temperature', 'makurrmakurr'],
  'sore_throat': ['sore throat', 'throat pain', 'ngirlkirri'],
  'headache': ['head pain', 'ngarlaka'],
  'vomiting': ['throwing up', 'sick up', 'jawuljaru'],
  'diarrhoea': ['diarrhea', 'runny poo'],
};
