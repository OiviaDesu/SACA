class DurationInterpretation {
  const DurationInterpretation({required this.answer, required this.days});

  final String answer;
  final double days;
}

class DurationInterpreter {
  const DurationInterpreter();

  static const lessThanOneDay = 'less than one day';
  static const oneToThreeDays = 'one to three days';
  static const fourToSevenDays = 'four to seven days';
  static const moreThanSevenDays = 'more than seven days';

  DurationInterpretation fromDays(double days) {
    final safeDays = days.clamp(0.0, 30.0);
    return DurationInterpretation(
      answer: answerForDays(safeDays),
      days: safeDays,
    );
  }

  String answerForDays(double days) {
    if (days < 1) return lessThanOneDay;
    if (days <= 3) return oneToThreeDays;
    if (days <= 7) return fourToSevenDays;
    return moreThanSevenDays;
  }

  double daysForAnswer(String? answer) {
    return switch (answer) {
      lessThanOneDay => 0.25,
      oneToThreeDays => 2,
      fourToSevenDays => 5,
      moreThanSevenDays => 10,
      _ => 0.25,
    };
  }

  DurationInterpretation? fromVoice(String value) {
    final normalized = _normalize(value);
    if (normalized.isEmpty) return null;

    if (normalized.contains('more than seven') ||
        normalized.contains('more than 7') ||
        normalized.contains('over seven') ||
        normalized.contains('over 7')) {
      return fromDays(8);
    }
    if (normalized.contains('today') ||
        normalized.contains('under one day') ||
        normalized.contains('under 1 day') ||
        normalized.contains('less than one day') ||
        normalized.contains('less than 1 day')) {
      return fromDays(0.25);
    }
    final explicit = _explicitDuration(normalized);
    if (explicit != null) return explicit;

    if (normalized.contains('week') || normalized.contains('seven days')) {
      return fromDays(7);
    }
    return null;
  }

  DurationInterpretation? _explicitDuration(String normalized) {
    final match = RegExp(
      r'\b(\d+(?:\.\d+)?|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)\s*(minute|minutes|min|mins|hour|hours|hr|hrs|day|days|week|weeks)\b',
    ).firstMatch(normalized);
    if (match == null) return null;
    final amount = _number(match.group(1)!);
    final unit = match.group(2)!;
    final days = switch (unit) {
      'minute' || 'minutes' || 'min' || 'mins' => amount / 1440,
      'hour' || 'hours' || 'hr' || 'hrs' => amount / 24,
      'week' || 'weeks' => amount * 7,
      _ => amount,
    };
    return fromDays(days);
  }

  double _number(String value) {
    final parsed = double.tryParse(value);
    if (parsed != null) return parsed;
    return switch (value) {
      'one' => 1,
      'two' => 2,
      'three' => 3,
      'four' => 4,
      'five' => 5,
      'six' => 6,
      'seven' => 7,
      'eight' => 8,
      'nine' => 9,
      'ten' => 10,
      'eleven' => 11,
      'twelve' => 12,
      _ => 0,
    };
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'>\s*7'), 'more than 7')
        .replaceAll(RegExp(r'<\s*1'), 'less than 1')
        .replaceAll(RegExp(r'[^a-z0-9.]+'), ' ')
        .trim();
  }
}
