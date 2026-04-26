import '../../core/errors/app_error.dart';
import '../models/saca_models.dart';

abstract interface class AnalysisService {
  Future<AppResult<AnalysisResult>> analyse(AnalysisRequest request);
}
