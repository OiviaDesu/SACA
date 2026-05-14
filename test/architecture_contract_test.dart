import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:saca/core/theme/saca_theme.dart';
import 'package:saca/domain/models/saca_catalogs.dart';
import 'package:saca/domain/models/saca_models.dart';
import 'package:saca/domain/services/saca_flow_step_policy.dart';
import 'package:saca/domain/services/safety_rule_service.dart';

void main() {
  group('SACA architecture regression contract', () {
    test('assessment catalog IDs stay stable', () {
      expect(
        SacaCatalogs.symptoms.map((item) => item.id),
        <String>[
          'headache',
          'fever',
          'stomachache',
          'sore_throat',
          'chest_pain',
          'breathing_trouble',
          'vomiting',
          'bloating',
        ],
      );
      expect(
        SacaCatalogs.relatedSymptoms.map((item) => item.id),
        <String>[
          'none',
          'sore_throat',
          'headache',
          'cough',
          'nausea_vomiting',
          'rash',
          'chest_pain',
          'breathing_trouble',
        ],
      );
      expect(SacaCatalogs.bodyAreas.map((item) => item.id), <String>[
        'head',
        'eyes',
        'throat',
        'heart',
        'chest',
        'stomach',
        'hand',
        'leg',
        'knees',
        'toes',
        'ears',
        'neck',
        'shoulder',
        'back',
        'arm',
        'elbow',
        'lower_back',
        'finger',
        'lower_leg',
        'ankle',
      ]);
    });

    test('questionnaire order and skin branch stay stable', () {
      const policy = SacaFlowStepPolicy();
      const baseState = SacaFlowState(textInput: 'fever and headache');
      const skinState = SacaFlowState(textInput: 'itchy rash on skin');

      final steps = <SacaStep>[];
      var step = SacaStep.questionSeverity;
      while (step != SacaStep.reviewInformation) {
        steps.add(step);
        step = policy.nextQuestionStep(step, baseState);
      }
      steps.add(step);

      expect(steps, <SacaStep>[
        SacaStep.questionSeverity,
        SacaStep.questionDuration,
        SacaStep.questionRelatedSymptoms,
        SacaStep.questionMedication,
        SacaStep.questionFood,
        SacaStep.questionAllergies,
        SacaStep.questionHealthChanges,
        SacaStep.reviewInformation,
      ]);
      expect(
        policy.nextQuestionStep(SacaStep.questionRelatedSymptoms, skinState),
        SacaStep.questionSkinDetails,
      );
      expect(
        policy.previousStep(SacaStep.questionMedication, skinState),
        SacaStep.questionSkinDetails,
      );
    });

    test('analysis request composition keeps all current input channels', () {
      const request = AnalysisRequest(
        language: SacaLanguage.gurindji,
        inputMethod: InputMethod.visual,
        transcript: 'draft transcript',
        textInput: 'typed symptom',
        selectedSymptomIds: <String>{'fever'},
        selectedBodyAreaIds: <String>{'throat'},
        answers: <String, String>{
          'severity': '5',
          'related_symptoms': 'cough|sore_throat',
        },
      );

      expect(
        request.combinedInput,
        'draft transcript typed symptom fever throat 5 cough|sore_throat',
      );
    });

    test('clinical red flags keep emergency override contract', () {
      const service = SafetyRuleService();
      const request = AnalysisRequest(
        language: SacaLanguage.english,
        inputMethod: InputMethod.text,
        transcript: '',
        textInput: 'I have chest pain and cannot breathe',
        selectedSymptomIds: <String>{},
        selectedBodyAreaIds: <String>{},
        answers: <String, String>{},
      );
      const base = AnalysisResult(
        disease: 'Common cold',
        severity: SeverityLevel.mild,
        guidance: <String>['Rest.'],
        isEmergency: false,
        disclaimer: 'Not medical advice.',
      );

      final result = service.apply(request, base);

      expect(result.disease, 'Urgent symptoms');
      expect(result.severity, SeverityLevel.emergency);
      expect(result.isEmergency, isTrue);
      expect(result.guidance, <String>[
        'Call 000 now or ask someone nearby to call.',
        'Do not wait for the app to make a diagnosis.',
        'If safe, stay seated and keep the phone nearby.',
      ]);
    });

    test('localization catalogs keep key parity across supported languages', () {
      final source = File('lib/presentation/localization/saca_localizer_data.dart')
          .readAsStringSync();
      final english = _mapKeys(source, '_english');
      final gurindji = _mapKeys(source, '_gurindji');

      expect(gurindji, english);
    });

    test('theme visual styles keep isolated renderer tokens', () {
      const modern = SacaThemeContext(
        colors: SacaTheme.lightColors,
        surfaceStyle: SacaThemeSurfaceStyle.modern,
        glassUnavailable: false,
        glassSolidFallback: false,
      );
      const glass = SacaThemeContext(
        colors: SacaTheme.lightColors,
        surfaceStyle: SacaThemeSurfaceStyle.glass,
        glassUnavailable: false,
        glassSolidFallback: false,
      );
      const classic = SacaThemeContext(
        colors: SacaTheme.lightColors,
        surfaceStyle: SacaThemeSurfaceStyle.classic,
        glassUnavailable: false,
        glassSolidFallback: false,
      );

      expect(modern.useGlassStyle, isFalse);
      expect(glass.useGlassStyle, isTrue);
      expect(classic.flattenGradients, isTrue);
      expect(glass.surfaceOpacity, lessThan(modern.surfaceOpacity));
      expect(classic.radiusScale, isNot(modern.radiusScale));
    });
  });
}

Set<String> _mapKeys(String source, String name) {
  final match = RegExp(
    'const $name = <String, String>\\{(.*?)\\};',
    dotAll: true,
  ).firstMatch(source);
  if (match == null) return <String>{};
  return RegExp(r"^\s*'([^']+)':", multiLine: true)
      .allMatches(match.group(1)!)
      .map((match) => match.group(1)!)
      .toSet();
}
