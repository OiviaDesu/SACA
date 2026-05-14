import '../models/saca_models.dart';
import 'safety_rule_service.dart';

class ClinicalRiskPolicy {
  const ClinicalRiskPolicy({SafetyRuleService safetyRules = const SafetyRuleService()})
      : _safetyRules = safetyRules;

  final SafetyRuleService _safetyRules;

  bool hasRedFlag(AnalysisRequest request) => _safetyRules.hasRedFlag(request);

  AnalysisResult apply(AnalysisRequest request, AnalysisResult result) {
    return _safetyRules.apply(request, result);
  }
}
