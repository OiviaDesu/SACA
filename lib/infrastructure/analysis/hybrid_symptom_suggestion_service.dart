import '../../domain/models/saca_models.dart';
import '../../domain/services/symptom_suggestion_service.dart';
import 'on_device_diagnosis_analysis_service.dart';

class HybridSymptomSuggestionService extends RuleBasedSymptomSuggestionService {
  HybridSymptomSuggestionService({DiagnosisClassifier? classifier})
      : _classifier = classifier;

  DiagnosisClassifier? _classifier;

  static const Map<String, List<String>> _diseaseSuggestions = {
    'asthma': ['breathing_trouble', 'cough', 'chest_pain'],
    'pneumonia': ['cough', 'breathing_trouble', 'chest_pain'],
    'common cold': ['cough', 'sore_throat', 'headache'],
    'migraine': ['headache', 'nausea_vomiting'],
    'gastroesophageal reflux disease': ['nausea_vomiting', 'chest_pain'],
    'peptic ulcer disease': ['nausea_vomiting'],
    'uti': ['nausea_vomiting'],
    'fungal infection': ['rash'],
    'allergy': ['rash', 'cough', 'breathing_trouble'],
    'chicken pox': ['rash', 'fever'],
    'dengue': ['fever', 'headache', 'rash'],
    'malaria': ['fever', 'headache', 'nausea_vomiting'],
    'typhoid': ['fever', 'headache', 'nausea_vomiting'],
  };

  @override
  Future<List<String>> refineRelatedSymptoms(AnalysisRequest request) async {
    final suggestions = suggestRelatedSymptoms(request).toSet();
    try {
      final prediction =
          await (_classifier ??= DiagnosisClassifierFactory.create()).predict(
        request,
      );
      suggestions.addAll(_diseaseSuggestions[prediction.label.toLowerCase()] ??
          const <String>[]);
    } catch (_) {
      return RuleBasedSymptomSuggestionService.orderedRelatedSymptoms(
        suggestions,
      );
    }

    suggestions.removeAll(request.selectedSymptomIds);
    return RuleBasedSymptomSuggestionService.orderedRelatedSymptoms(
        suggestions);
  }
}
