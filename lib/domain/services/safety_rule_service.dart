import '../models/saca_models.dart';

class SafetyRuleService {
  const SafetyRuleService();

  static const _redFlagTerms = <String>[
    'chest pain',
    'chest tight',
    'short of breath',
    'cannot breathe',
    "can't breathe",
    'unconscious',
    'fainted',
    'seizure',
    'stroke',
    'severe bleeding',
    'bleeding',
    'blood',
  ];

  bool hasRedFlag(AnalysisRequest request) {
    final input = request.combinedInput.toLowerCase();
    final selected = request.selectedSymptomIds;
    final areas = request.selectedBodyAreaIds;
    return _redFlagTerms.any(input.contains) ||
        selected.contains('chest_pain') ||
        selected.contains('breathing_trouble') ||
        areas.contains('chest') ||
        areas.contains('heart');
  }

  AnalysisResult apply(AnalysisRequest request, AnalysisResult result) {
    if (!hasRedFlag(request)) return result;

    return result.copyWith(
      disease: 'Urgent symptoms',
      severity: SeverityLevel.emergency,
      isEmergency: true,
      guidance: const [
        'Call 000 now or ask someone nearby to call.',
        'Do not wait for the app to make a diagnosis.',
        'If safe, stay seated and keep the phone nearby.',
      ],
    );
  }
}
