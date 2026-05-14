part of 'saca_models.dart';

class NonSpeechCue {
  const NonSpeechCue({
    required this.kind,
    required this.confidence,
    required this.evidence,
  });

  final String kind;
  final double confidence;
  final String evidence;
}

class SpeechSignalFeatures {
  const SpeechSignalFeatures({
    required this.transcript,
    this.cues = const <NonSpeechCue>[],
    this.confidence,
    this.qualityFlags = const <String>[],
    this.isSupported = true,
  });

  final String transcript;
  final List<NonSpeechCue> cues;
  final double? confidence;
  final List<String> qualityFlags;
  final bool isSupported;

  bool get hasUsableSignals {
    if (!isSupported || qualityFlags.isNotEmpty) return false;
    final value = confidence;
    return value == null || value >= 0.55;
  }
}
