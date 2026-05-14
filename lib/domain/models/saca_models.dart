import 'saca_catalogs.dart';

part 'saca_analysis_models.dart';
part 'saca_assessment_models.dart';
part 'saca_flow_state.dart';
part 'saca_speech_models.dart';

enum SacaLanguage { english, gurindji }

enum InputMethod { text, voice, visual }

enum SeverityLevel { mild, moderate, severe, emergency }

enum ConfidenceLevel { low, medium, high }

enum VoiceBusyPhase { none, preparing, transcribing }

enum SacaConfirmationType { emptyInput, noClearIllness }

enum SacaStep {
  splash,
  language,
  inputMethod,
  voiceInput,
  textInput,
  visualInput,
  questionSeverity,
  questionDuration,
  questionRelatedSymptoms,
  questionSkinDetails,
  questionMedication,
  questionFood,
  questionAllergies,
  questionHealthChanges,
  reviewInformation,
  settings,
  analysing,
  result,
}

enum BodyView { front, back }
