import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/errors/app_error.dart';
import '../../domain/models/saca_models.dart';
import '../../domain/services/analysis_service.dart';
import 'saca_backend_serializers.dart';

class HttpAnalysisService implements AnalysisService {
  HttpAnalysisService({required Uri baseUri, http.Client? client})
      : _baseUri = baseUri,
        _client = client ?? http.Client();

  final Uri _baseUri;
  final http.Client _client;

  @override
  Future<AppResult<AnalysisResult>> analyse(AnalysisRequest request) async {
    try {
      final response = await _client
          .post(
            _baseUri.resolve('/analyse'),
            headers: const <String, String>{'content-type': 'application/json'},
            body: jsonEncode(analysisRequestToJson(request)),
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return AppResult<AnalysisResult>.failure(
          AppFailure(
            kind: AppFailureKind.analysisFailed,
            message: 'Diagnosis backend is unavailable. Try again later.',
            debugMessage:
                'POST /analyse ${response.statusCode}: ${response.body}',
          ),
        );
      }
      final json = jsonDecode(response.body) as Map<String, Object?>;
      return AppResult<AnalysisResult>.success(analysisResultFromJson(json));
    } catch (error) {
      return AppResult<AnalysisResult>.failure(
        AppFailure(
          kind: AppFailureKind.analysisFailed,
          message: 'Diagnosis backend is unavailable. Try again later.',
          debugMessage: error,
        ),
      );
    }
  }

  void dispose() => _client.close();
}
