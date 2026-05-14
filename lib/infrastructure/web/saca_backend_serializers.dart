import '../../domain/models/saca_models.dart';
import '../../domain/services/speech_input_service.dart';

Map<String, Object?> analysisRequestToJson(AnalysisRequest request) {
  return <String, Object?>{
    'language': request.language.name,
    'inputMethod': request.inputMethod.name,
    'transcript': request.transcript,
    'textInput': request.textInput,
    'selectedSymptomIds': request.selectedSymptomIds.toList(),
    'selectedBodyAreaIds': request.selectedBodyAreaIds.toList(),
    'answers': request.answers,
    if (request.speechSignalFeatures != null)
      'speechSignalFeatures': speechSignalFeaturesToJson(
        request.speechSignalFeatures!,
      ),
  };
}

Map<String, Object?> speechSignalFeaturesToJson(SpeechSignalFeatures value) {
  return <String, Object?>{
    'transcript': value.transcript,
    'confidence': value.confidence,
    'isSupported': value.isSupported,
    'qualityFlags': value.qualityFlags,
    'cues': [
      for (final cue in value.cues)
        <String, Object?>{
          'kind': cue.kind,
          'confidence': cue.confidence,
          'evidence': cue.evidence,
        },
    ],
  };
}

AnalysisResult analysisResultFromJson(Map<String, Object?> json) {
  return AnalysisResult(
    disease: _string(json['disease'], fallback: 'No clear illness detected'),
    severity: _enumValue(
      SeverityLevel.values,
      json['severity'],
      SeverityLevel.mild,
    ),
    guidance: _stringList(json['guidance']),
    isEmergency: json['isEmergency'] == true,
    disclaimer:
        _string(json['disclaimer'], fallback: 'Prototype guidance only.'),
    predictions: [
      for (final item in _mapList(json['predictions']))
        ConditionPrediction(
          label: _string(item['label'], fallback: 'Unknown'),
          rank: _int(item['rank'], fallback: 0),
          confidence: _doubleOrNull(item['confidence']),
        ),
    ],
  );
}

SpeechInputResult speechInputResultFromJson(Map<String, Object?> json) {
  final text = _string(json['text'] ?? json['transcript']);
  return SpeechInputResult(
    text: text,
    signalFeatures: SpeechSignalFeatures(
      transcript: text,
      confidence: _doubleOrNull(json['confidence']),
      isSupported: json['isSupported'] != false,
      qualityFlags: _stringList(json['qualityFlags']),
      cues: [
        for (final item in _mapList(json['cues']))
          NonSpeechCue(
            kind: _string(item['kind']),
            confidence: _doubleOrNull(item['confidence']) ?? 0,
            evidence: _string(item['evidence']),
          ),
      ],
    ),
  );
}

T _enumValue<T extends Enum>(List<T> values, Object? raw, T fallback) {
  final name = raw?.toString();
  return values.firstWhere((value) => value.name == name,
      orElse: () => fallback);
}

String _string(Object? value, {String fallback = ''}) {
  final text = value?.toString();
  return text == null || text.isEmpty ? fallback : text;
}

int _int(Object? value, {required int fallback}) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double? _doubleOrNull(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

List<String> _stringList(Object? value) {
  if (value is List) return value.map((item) => item.toString()).toList();
  return const <String>[];
}

List<Map<String, Object?>> _mapList(Object? value) {
  if (value is! List) return const <Map<String, Object?>>[];
  return [
    for (final item in value)
      if (item is Map)
        item.map((key, value) => MapEntry(key.toString(), value)),
  ];
}
