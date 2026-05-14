import '../../domain/services/analysis_service.dart';
import '../../domain/services/clinical_vocabulary_service.dart';
import '../../domain/services/speech_input_service.dart';
import '../analysis/mock_analysis_service.dart';
import '../analysis/on_device_diagnosis_analysis_service.dart';
import '../speech/voice_prewarm_service.dart';
import '../speech/whisper_speech_input_service.dart';

class SacaRuntimeServices {
  SacaRuntimeServices(
      {required this.speechInput, required this.analysisService});

  final SpeechInputService speechInput;
  final AnalysisService analysisService;
}

Future<SacaRuntimeServices> createSacaRuntimeServices({
  required ClinicalVocabularyService vocabulary,
}) async {
  final speechInput = WhisperSpeechInputService();
  return SacaRuntimeServices(
    speechInput: speechInput,
    analysisService: OnDeviceDiagnosisAnalysisService(
      fallback: MockAnalysisService(vocabulary: vocabulary),
      vocabulary: vocabulary,
    ),
  );
}

void prewarmSacaRuntimeServices(SacaRuntimeServices services) {
  VoicePrewarmService(speechInput: services.speechInput).prewarm();
}
