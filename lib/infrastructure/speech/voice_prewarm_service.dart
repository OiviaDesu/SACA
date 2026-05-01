import 'package:flutter/foundation.dart';

import '../../domain/models/saca_models.dart';
import '../../domain/services/speech_input_service.dart';

class VoicePrewarmService {
  const VoicePrewarmService({required SpeechInputService speechInput})
      : _speechInput = speechInput;

  final SpeechInputService _speechInput;

  Future<void> prewarm({
    SacaLanguage language = SacaLanguage.english,
  }) async {
    if (!_speechInput.supportsOnDeviceStt) {
      return;
    }

    final result = await _speechInput.prepare(language);
    if (!result.isSuccess) {
      debugPrint('[SACA] Voice prewarm skipped: ${result.failure?.message}');
    }
  }
}
