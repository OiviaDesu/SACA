import 'package:flutter_test/flutter_test.dart';
import 'package:saca/domain/services/duration_interpreter.dart';

void main() {
  const interpreter = DurationInterpreter();

  test('maps minutes and hours to less than one day', () {
    expect(interpreter.fromVoice('30 minutes')?.answer, 'less than one day');
    expect(interpreter.fromVoice('6 hours')?.answer, 'less than one day');
  });

  test('maps day counts to expected buckets', () {
    expect(interpreter.fromVoice('2 days')?.answer, 'one to three days');
    expect(interpreter.fromVoice('7 days')?.answer, 'four to seven days');
    expect(interpreter.fromVoice('2 weeks')?.answer, 'more than seven days');
  });
}
