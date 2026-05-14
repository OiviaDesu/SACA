import '../../domain/models/saca_models.dart';
import '../../domain/services/diagnosis_classifier.dart';

class DiagnosisResultFormatter {
  const DiagnosisResultFormatter();

  String humanizeDisease(String label) {
    return label
        .split(RegExp(r'[ _-]+'))
        .where((word) => word.isNotEmpty)
        .map((word) => word.length == 1
            ? word.toUpperCase()
            : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  List<ConditionPrediction> humanizedPredictions(
    DiagnosisPrediction prediction,
  ) {
    final source = prediction.ranked.isEmpty
        ? <ConditionPrediction>[
            ConditionPrediction(
              label: prediction.label,
              rank: 1,
              confidence: prediction.confidence,
            ),
          ]
        : prediction.ranked;
    return <ConditionPrediction>[
      for (final item in source.take(3))
        ConditionPrediction(
          label: humanizeDisease(item.label),
          rank: item.rank,
          confidence: item.confidence,
        ),
    ];
  }
}
