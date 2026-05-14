import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/models/saca_models.dart';
import '../../domain/services/analysis_service.dart';
import '../../domain/services/clinical_vocabulary_service.dart';
import '../../domain/services/speech_input_service.dart';
import '../analysis/on_device_diagnosis_analysis_service.dart';
import '../web/web_speech_input_service.dart';

const String _apiBase = String.fromEnvironment(
  'SACA_API_BASE',
  defaultValue: 'http://127.0.0.1:8787',
);

class SacaRuntimeServices {
  SacaRuntimeServices(
      {required this.speechInput, required this.analysisService});

  final SpeechInputService speechInput;
  final AnalysisService analysisService;
}

Future<SacaRuntimeServices> createSacaRuntimeServices({
  required ClinicalVocabularyService vocabulary,
}) async {
  final baseUri = Uri.parse(_apiBase);
  debugPrint('[SACA] Web backend: $baseUri');
  return SacaRuntimeServices(
    speechInput: WebSpeechInputService(baseUri: baseUri),
    analysisService: OnDeviceDiagnosisAnalysisService(vocabulary: vocabulary),
  );
}

void prewarmSacaRuntimeServices(SacaRuntimeServices services) {
  unawaited(services.speechInput.prepare(SacaLanguage.english));
}
