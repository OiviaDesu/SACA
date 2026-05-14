import '../models/saca_models.dart';

class DiagnosisPrediction {
  const DiagnosisPrediction({
    required this.label,
    this.confidence,
    this.ranked = const <ConditionPrediction>[],
  });

  final String label;
  final double? confidence;
  final List<ConditionPrediction> ranked;
}

abstract interface class DiagnosisClassifier {
  Future<DiagnosisPrediction> predict(AnalysisRequest request);
}
