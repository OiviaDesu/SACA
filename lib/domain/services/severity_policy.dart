import '../models/saca_models.dart';

class SeverityPolicy {
  const SeverityPolicy();

  static const defaultScore = 5;

  int scoreFromAnswer(String? answer) {
    return int.tryParse(answer ?? '')?.clamp(1, 10).toInt() ?? defaultScore;
  }

  String descriptorKeyForScore(int score) {
    return switch (score.clamp(1, 10)) {
      <= 3 => 'severityDescriptorLow',
      <= 6 => 'severityDescriptorModerate',
      <= 8 => 'severityDescriptorHigh',
      _ => 'severityDescriptorEmergency',
    };
  }

  ConfidenceLevel confidenceLevel(double? confidence) {
    if (confidence == null) return ConfidenceLevel.low;
    if (confidence >= 0.70) return ConfidenceLevel.high;
    if (confidence >= 0.40) return ConfidenceLevel.medium;
    return ConfidenceLevel.low;
  }
}
