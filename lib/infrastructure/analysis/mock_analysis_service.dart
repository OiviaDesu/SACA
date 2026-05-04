import '../../core/errors/app_error.dart';
import '../../domain/models/saca_models.dart';
import '../../domain/services/analysis_service.dart';
import '../../domain/services/clinical_vocabulary_service.dart';
import '../../domain/services/safety_rule_service.dart';

class MockAnalysisService implements AnalysisService {
  MockAnalysisService({
    SafetyRuleService? safetyRules,
    ClinicalVocabularyService? vocabulary,
  })  : _safetyRules = safetyRules ?? const SafetyRuleService(),
        _vocabulary = vocabulary ?? const ClinicalVocabularyService.empty();

  final SafetyRuleService _safetyRules;
  final ClinicalVocabularyService _vocabulary;

  @override
  Future<AppResult<AnalysisResult>> analyse(AnalysisRequest request) async {
    final normalizedRequest = _vocabulary.normalizeRequest(request);
    final input = normalizedRequest.combinedInput.trim();
    if (input.isEmpty) {
      return const AppResult.failure(
        AppFailure(
          kind: AppFailureKind.emptyInput,
          message: 'Please add at least one symptom before analysis.',
        ),
      );
    }

    await Future<void>.delayed(const Duration(milliseconds: 450));

    if (_isHealthyInput(input)) {
      return const AppResult.success(
        AnalysisResult(
          disease: 'No clear illness detected',
          severity: SeverityLevel.mild,
          isEmergency: false,
          disclaimer:
              'SACA provides preliminary triage guidance only. It does not replace a clinician.',
          guidance: [
            'No clear symptom was reported, so no disease prediction is needed.',
            'Monitor how you feel and return if symptoms appear.',
            'Seek urgent help if chest pain, breathing trouble, severe bleeding, or confusion starts.',
          ],
        ),
      );
    }

    final result = _safetyRules.apply(
      normalizedRequest,
      _baseResultFor(normalizedRequest),
    );
    return AppResult.success(result);
  }

  bool _isHealthyInput(String text) {
    final normalized = text.toLowerCase().trim();
    const healthyPhrases = <String>[
      'i am good',
      'i feel good',
      'i am okay',
      'i feel okay',
      'i am fine',
      'i feel fine',
      'i feel healthy',
      'nothing wrong',
      'no symptoms',
      'no symptom',
      'no problem',
      'not sick',
      'i am not sick',
      'i am healthy',
      'feeling good',
      'feeling fine',
    ];
    return healthyPhrases.any(normalized.contains);
  }

  AnalysisResult _baseResultFor(AnalysisRequest request) {
    final input = request.combinedInput.toLowerCase();
    final symptoms = request.selectedSymptomIds;
    final severity = int.tryParse(request.answers['severity'] ?? '') ?? 0;

    if ((symptoms.contains('headache') && symptoms.contains('sore_throat')) ||
        symptoms.contains('fever') ||
        (input.contains('headache') && input.contains('sore throat')) ||
        input.contains('flu') ||
        input.contains('cold') ||
        input.contains('cough') ||
        input.contains('fever')) {
      return AnalysisResult(
        disease: 'Influenza',
        severity: severity >= 8 ? SeverityLevel.severe : SeverityLevel.mild,
        isEmergency: false,
        disclaimer:
            'SACA provides preliminary triage guidance only. It does not replace a clinician.',
        guidance: const [
          'Rest and drink fluids.',
          'Use fever relief if it is safe for you.',
          'Monitor symptoms and visit the clinic if they worsen.',
          'Avoid close contact with others where possible.',
        ],
      );
    }

    if (symptoms.contains('stomachache') ||
        symptoms.contains('vomiting') ||
        symptoms.contains('bloating') ||
        input.contains('stomach') ||
        input.contains('belly') ||
        input.contains('nausea') ||
        input.contains('diarrhea') ||
        input.contains('vomit')) {
      return const AnalysisResult(
        disease: 'Stomach upset',
        severity: SeverityLevel.moderate,
        isEmergency: false,
        disclaimer:
            'SACA provides preliminary triage guidance only. It does not replace a clinician.',
        guidance: [
          'Sip water often.',
          'Rest and avoid heavy meals for now.',
          'Visit the clinic if vomiting continues or pain increases.',
        ],
      );
    }

    if (input.contains('rash') ||
        input.contains('itch') ||
        input.contains('skin')) {
      return const AnalysisResult(
        disease: 'Skin irritation',
        severity: SeverityLevel.mild,
        isEmergency: false,
        disclaimer:
            'SACA provides preliminary triage guidance only. It does not replace a clinician.',
        guidance: [
          'Keep the area clean and avoid scratching.',
          'Visit the clinic if the rash spreads, becomes painful, or has pus.',
          'Seek urgent help if rash appears with breathing trouble or face swelling.',
        ],
      );
    }

    if (input.contains('pain')) {
      return AnalysisResult(
        disease: 'Pain symptoms',
        severity: severity >= 7 ? SeverityLevel.severe : SeverityLevel.moderate,
        isEmergency: false,
        disclaimer:
            'SACA provides preliminary triage guidance only. It does not replace a clinician.',
        guidance: const [
          'Note where the pain is and how long it has been present.',
          'Rest and avoid activities that worsen the pain.',
          'Visit the clinic if pain is severe, spreading, or not improving.',
        ],
      );
    }

    return const AnalysisResult(
      disease: 'General symptoms',
      severity: SeverityLevel.mild,
      isEmergency: false,
      disclaimer:
          'SACA provides preliminary triage guidance only. It does not replace a clinician.',
      guidance: [
        'Rest and keep track of changes.',
        'Use the local clinic if symptoms continue.',
        'Seek urgent help if breathing, chest pain, or bleeding starts.',
      ],
    );
  }
}
