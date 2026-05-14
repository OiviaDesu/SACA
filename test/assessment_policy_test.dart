import 'package:flutter_test/flutter_test.dart';
import 'package:saca/domain/models/saca_models.dart';
import 'package:saca/domain/services/clinical_risk_policy.dart';
import 'package:saca/domain/services/related_symptom_policy.dart';
import 'package:saca/domain/services/severity_policy.dart';

void main() {
  group('SeverityPolicy', () {
    const policy = SeverityPolicy();

    test('keeps current default, clamp, and descriptor thresholds', () {
      expect(policy.scoreFromAnswer(null), 5);
      expect(policy.scoreFromAnswer('0'), 1);
      expect(policy.scoreFromAnswer('11'), 10);
      expect(policy.descriptorKeyForScore(3), 'severityDescriptorLow');
      expect(policy.descriptorKeyForScore(4), 'severityDescriptorModerate');
      expect(policy.descriptorKeyForScore(8), 'severityDescriptorHigh');
      expect(policy.descriptorKeyForScore(9), 'severityDescriptorEmergency');
    });

    test('keeps current confidence thresholds', () {
      expect(policy.confidenceLevel(null), ConfidenceLevel.low);
      expect(policy.confidenceLevel(0.39), ConfidenceLevel.low);
      expect(policy.confidenceLevel(0.40), ConfidenceLevel.medium);
      expect(policy.confidenceLevel(0.70), ConfidenceLevel.high);
    });
  });

  group('RelatedSymptomPolicy', () {
    const policy = RelatedSymptomPolicy();

    test('filters known symptoms and preserves related catalog order', () {
      const request = AnalysisRequest(
        language: SacaLanguage.english,
        inputMethod: InputMethod.text,
        transcript: '',
        textInput: 'fever and cough',
        selectedSymptomIds: <String>{'headache'},
        selectedBodyAreaIds: <String>{},
        answers: <String, String>{},
      );

      expect(
        policy.knownFilteredSuggestions(
          <String>['cough', 'fever', 'rash', 'sore_throat', 'headache'],
          request,
        ),
        <String>['sore_throat', 'rash'],
      );
    });

    test('merges current and voice cue suggestions in catalog order', () {
      expect(
        policy.mergeOrdered(
          <String>['breathing_trouble', 'headache'],
          <String>['cough', 'sore_throat'],
        ),
        <String>['sore_throat', 'headache', 'cough', 'breathing_trouble'],
      );
    });
  });

  group('ClinicalRiskPolicy', () {
    test('keeps current red-flag override output', () {
      const policy = ClinicalRiskPolicy();
      const request = AnalysisRequest(
        language: SacaLanguage.english,
        inputMethod: InputMethod.visual,
        transcript: '',
        textInput: '',
        selectedSymptomIds: <String>{'breathing_trouble'},
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

      expect(policy.hasRedFlag(request), isTrue);
      final result = policy.apply(request, base);
      expect(result.disease, 'Urgent symptoms');
      expect(result.severity, SeverityLevel.emergency);
      expect(result.isEmergency, isTrue);
    });
  });
}
