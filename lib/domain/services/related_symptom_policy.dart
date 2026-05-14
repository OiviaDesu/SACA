import '../models/saca_catalogs.dart';
import '../models/saca_models.dart';
import 'symptom_suggestion_service.dart';

class RelatedSymptomPolicy {
  const RelatedSymptomPolicy();

  List<String> knownFilteredSuggestions(
    Iterable<String> ids,
    AnalysisRequest request,
  ) {
    final known = RuleBasedSymptomSuggestionService.knownSymptomIds(request);
    return RuleBasedSymptomSuggestionService.orderedRelatedSymptoms(
      ids.where((id) => !known.contains(id)),
    );
  }

  List<String> mergeOrdered(Iterable<String> current, Iterable<String> next) {
    return RuleBasedSymptomSuggestionService.orderedRelatedSymptoms(
      <String>{...current, ...next},
    );
  }

  Map<String, Symptom> relatedById() {
    return {for (final symptom in SacaCatalogs.relatedSymptoms) symptom.id: symptom};
  }
}
