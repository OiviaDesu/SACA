import 'package:flutter/cupertino.dart';

import 'core/theme/saca_theme.dart';
import 'domain/services/clinical_vocabulary_service.dart';
import 'infrastructure/analysis/mock_analysis_service.dart';
import 'infrastructure/localization/asset_lexicon_repository.dart';
import 'infrastructure/speech/voice_prewarm_service.dart';
import 'infrastructure/speech/whisper_speech_input_service.dart';
import 'infrastructure/window/saca_window_configurator.dart';
import 'presentation/controllers/saca_flow_controller.dart';
import 'presentation/localization/saca_localizer.dart';
import 'presentation/screens/saca_flow_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureSacaDesktopWindow();
  final vocabulary = await _loadVocabulary();
  final speechInput = WhisperSpeechInputService();
  runApp(SacaApp(vocabulary: vocabulary, speechInput: speechInput));
  WidgetsBinding.instance.addPostFrameCallback((_) {
    VoicePrewarmService(speechInput: speechInput).prewarm();
  });
}

Future<ClinicalVocabularyService> _loadVocabulary() async {
  try {
    final entries = await const AssetLexiconRepository().loadEntries();
    return ClinicalVocabularyService.fromEntries(entries);
  } catch (error, stackTrace) {
    debugPrint('[SACA] Gurindji lexicon unavailable: $error');
    debugPrintStack(stackTrace: stackTrace);
    return const ClinicalVocabularyService.empty();
  }
}

class SacaApp extends StatelessWidget {
  const SacaApp({
    super.key,
    required this.vocabulary,
    required this.speechInput,
  });

  final ClinicalVocabularyService vocabulary;
  final WhisperSpeechInputService speechInput;

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'SACA',
      debugShowCheckedModeBanner: false,
      theme: SacaTheme.cupertinoTheme,
      home: SacaFlowScreen(
        controller: SacaFlowController(
          speechInput: speechInput,
          analysisService: MockAnalysisService(vocabulary: vocabulary),
        ),
        localizer: SacaLocalizer(vocabulary: vocabulary),
      ),
    );
  }
}
