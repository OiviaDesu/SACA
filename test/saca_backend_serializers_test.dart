import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saca/core/errors/app_error.dart';
import 'package:saca/domain/models/saca_models.dart';
import 'package:saca/infrastructure/web/http_analysis_service.dart';
import 'package:saca/infrastructure/web/saca_backend_serializers.dart';

void main() {
  group('SACA web backend serializers', () {
    test('maps analysis request to backend json', () {
      const request = AnalysisRequest(
        language: SacaLanguage.english,
        inputMethod: InputMethod.voice,
        transcript: 'cough',
        textInput: '',
        selectedSymptomIds: <String>{'fever'},
        selectedBodyAreaIds: <String>{'chest'},
        answers: <String, String>{'severity': '5'},
        speechSignalFeatures: SpeechSignalFeatures(
          transcript: 'cough',
          confidence: 0.8,
          cues: <NonSpeechCue>[
            NonSpeechCue(kind: 'cough', confidence: 0.7, evidence: 'audio'),
          ],
        ),
      );

      final json = analysisRequestToJson(request);

      expect(json['language'], 'english');
      expect(json['inputMethod'], 'voice');
      expect(json['selectedSymptomIds'], <String>['fever']);
      expect(json['selectedBodyAreaIds'], <String>['chest']);
      expect(json['answers'], <String, String>{'severity': '5'});
      expect(json['speechSignalFeatures'], isA<Map<String, Object?>>());
    });

    test('maps analysis result from backend json', () {
      final result = analysisResultFromJson(<String, Object?>{
        'disease': 'Flu',
        'severity': 'moderate',
        'guidance': <String>['Rest', 'Hydrate'],
        'isEmergency': false,
        'disclaimer': 'Prototype only',
        'predictions': <Map<String, Object?>>[
          <String, Object?>{'label': 'Flu', 'rank': 1, 'confidence': 0.82},
        ],
      });

      expect(result.disease, 'Flu');
      expect(result.severity, SeverityLevel.moderate);
      expect(result.guidance, <String>['Rest', 'Hydrate']);
      expect(result.predictions.single.confidencePercent, 82);
    });

    test('maps speech input result from backend json', () {
      final result = speechInputResultFromJson(<String, Object?>{
        'text': 'coughing',
        'confidence': 0.74,
        'qualityFlags': <String>[],
        'cues': <Map<String, Object?>>[
          <String, Object?>{
            'kind': 'cough',
            'confidence': 0.65,
            'evidence': 'backend-cue',
          },
        ],
      });

      expect(result.text, 'coughing');
      expect(result.signalFeatures?.confidence, 0.74);
      expect(result.signalFeatures?.cues.single.kind, 'cough');
    });
  });

  group('HttpAnalysisService', () {
    test('returns result on success', () async {
      final service = HttpAnalysisService(
        baseUri: Uri.parse('http://localhost:8787'),
        client: MockClient((request) async {
          expect(request.url.path, '/analyse');
          return http.Response(
            jsonEncode(<String, Object?>{
              'disease': 'Flu',
              'severity': 'mild',
              'guidance': <String>['Rest'],
              'isEmergency': false,
              'disclaimer': 'Prototype only',
            }),
            200,
          );
        }),
      );

      final result = await service.analyse(_request());

      expect(result.isSuccess, isTrue);
      expect(result.value?.disease, 'Flu');
    });

    test('returns recoverable failure when backend is down', () async {
      final service = HttpAnalysisService(
        baseUri: Uri.parse('http://localhost:8787'),
        client: MockClient((request) async => http.Response('down', 503)),
      );

      final result = await service.analyse(_request());

      expect(result.isSuccess, isFalse);
      expect(result.failure?.kind, AppFailureKind.analysisFailed);
    });
  });
}

AnalysisRequest _request() {
  return const AnalysisRequest(
    language: SacaLanguage.english,
    inputMethod: InputMethod.text,
    transcript: '',
    textInput: 'fever',
    selectedSymptomIds: <String>{},
    selectedBodyAreaIds: <String>{},
    answers: <String, String>{},
  );
}
