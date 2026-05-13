import 'package:flutter_test/flutter_test.dart';
import 'package:saca/domain/models/saca_models.dart';
import 'package:saca/domain/services/voice_command_matcher.dart';

void main() {
  const matcher = VoiceCommandMatcher();

  group('VoiceCommandMatcher', () {
    test('maps severity transcripts and aliases', () {
      expect(matcher.match(SacaStep.questionSeverity, 'nine')?.value, '9');
      expect(matcher.match(SacaStep.questionSeverity, 'severe')?.value, '9');
      expect(matcher.match(SacaStep.questionSeverity, 'warlarrp')?.value, '9');
      expect(matcher.match(SacaStep.questionSeverity, 'ate')?.value, '8');
    });

    test('maps duration transcripts and aliases', () {
      expect(
        matcher.match(SacaStep.questionDuration, 'today')?.value,
        'less than one day',
      );
      expect(
        matcher.match(SacaStep.questionDuration, 'jala')?.value,
        'less than one day',
      );
      expect(
        matcher.match(SacaStep.questionDuration, 'less than day')?.value,
        'less than one day',
      );
      expect(
        matcher.match(SacaStep.questionDuration, '>7 days')?.value,
        'more than seven days',
      );
    });

    test('maps negative and uncertainty choices safely', () {
      expect(
        matcher.match(SacaStep.questionMedication, 'nope')?.value,
        'no medication',
      );
      expect(
        matcher.match(SacaStep.questionMedication, 'lawara')?.value,
        'no medication',
      );
      expect(
        matcher.match(SacaStep.questionAllergies, 'none')?.value,
        'no known allergies',
      );
      expect(
        matcher.match(SacaStep.questionAllergies, 'dunno')?.value,
        'not sure allergies',
      );
    });

    test('uses synonym layer for related symptoms', () {
      expect(
        matcher.match(SacaStep.questionRelatedSymptoms, 'throat pain')?.value,
        'sore_throat',
      );
      expect(
        matcher.match(SacaStep.questionRelatedSymptoms, 'nothing else')?.value,
        'none',
      );
    });

    test('does not auto-match ambiguous low confidence transcripts', () {
      expect(matcher.match(SacaStep.questionMedication, 'banana sky'), isNull);
      expect(matcher.match(SacaStep.questionFood, 'normal allergy'), isNull);
    });
  });
}
