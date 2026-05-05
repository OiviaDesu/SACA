import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:flutter_onnxruntime/src/flutter_onnxruntime_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:saca_demo/domain/models/saca_models.dart';
import 'package:saca_demo/infrastructure/analysis/mock_analysis_service.dart';
import 'package:saca_demo/infrastructure/analysis/on_device_diagnosis_analysis_service.dart';
import 'package:saca_demo/infrastructure/analysis/xgb_m2cgen_runtime.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OnDeviceDiagnosisAnalysisService', () {
    test('uses classifier disease while keeping safety guidance', () async {
      final service = OnDeviceDiagnosisAnalysisService(
        classifier: const _FakeDiagnosisClassifier('common cold'),
        fallback: MockAnalysisService(),
      );

      final result = await service.analyse(
        const AnalysisRequest(
          language: SacaLanguage.english,
          inputMethod: InputMethod.text,
          transcript: '',
          textInput: 'fever cough sore throat',
          selectedSymptomIds: <String>{},
          selectedBodyAreaIds: <String>{},
          answers: <String, String>{'severity': '4'},
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(result.value?.disease, 'Common Cold');
      expect(result.value?.severity, SeverityLevel.mild);
      expect(result.value?.isEmergency, isFalse);
      expect(result.value?.guidance, isNotEmpty);
    });

    test('red flags override classifier disease', () async {
      final service = OnDeviceDiagnosisAnalysisService(
        classifier: const _FakeDiagnosisClassifier('hypertension'),
        fallback: MockAnalysisService(),
      );

      final result = await service.analyse(
        const AnalysisRequest(
          language: SacaLanguage.english,
          inputMethod: InputMethod.text,
          transcript: '',
          textInput: 'chest pain and cannot breathe',
          selectedSymptomIds: <String>{},
          selectedBodyAreaIds: <String>{},
          answers: <String, String>{'severity': '9'},
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(result.value?.disease, 'Urgent symptoms');
      expect(result.value?.severity, SeverityLevel.emergency);
      expect(result.value?.guidance.first, contains('Call 000'));
    });

    test('healthy input skips classifier prediction', () async {
      final classifier = _CountingDiagnosisClassifier('common cold');
      final service = OnDeviceDiagnosisAnalysisService(
        classifier: classifier,
        fallback: MockAnalysisService(),
      );

      final result = await service.analyse(
        const AnalysisRequest(
          language: SacaLanguage.english,
          inputMethod: InputMethod.text,
          transcript: '',
          textInput: 'I feel fine and have no symptoms',
          selectedSymptomIds: <String>{},
          selectedBodyAreaIds: <String>{},
          answers: <String, String>{},
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(result.value?.disease, 'No clear illness detected');
      expect(classifier.callCount, 0);
    });

    test('falls back when classifier throws', () async {
      final service = OnDeviceDiagnosisAnalysisService(
        classifier: const _ThrowingDiagnosisClassifier(),
        fallback: MockAnalysisService(),
      );

      final result = await service.analyse(
        const AnalysisRequest(
          language: SacaLanguage.english,
          inputMethod: InputMethod.text,
          transcript: '',
          textInput: 'fever',
          selectedSymptomIds: <String>{},
          selectedBodyAreaIds: <String>{},
          answers: <String, String>{'severity': '4'},
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(result.value?.disease, 'Influenza');
    });

    test('falls back when classifier inference times out', () async {
      final service = OnDeviceDiagnosisAnalysisService(
        classifier: const _TimeoutDiagnosisClassifier(),
        fallback: MockAnalysisService(),
      );

      final result = await service.analyse(
        const AnalysisRequest(
          language: SacaLanguage.english,
          inputMethod: InputMethod.text,
          transcript: '',
          textInput: 'fever cough',
          selectedSymptomIds: <String>{},
          selectedBodyAreaIds: <String>{},
          answers: <String, String>{'severity': '4'},
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(result.value?.disease, 'Influenza');
    });

    test('falls back when ONNX model session cannot load', () async {
      final service = OnDeviceDiagnosisAnalysisService(
        classifier: OnnxDiagnosisClassifier(
          runtime: _FailingOnnxRuntime(),
        ),
        fallback: MockAnalysisService(),
      );

      final result = await service.analyse(
        const AnalysisRequest(
          language: SacaLanguage.english,
          inputMethod: InputMethod.text,
          transcript: '',
          textInput: 'fever cough',
          selectedSymptomIds: <String>{},
          selectedBodyAreaIds: <String>{},
          answers: <String, String>{'severity': '4'},
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(result.value?.disease, 'Influenza');
    });

    test('ONNX classifier returns top 3 ranked probabilities', () async {
      final platform = _FakeOnnxPlatform(
        outputs: <String, List<Object?>>{
          'output_label': <Object?>['label', 'int64', <int>[1]],
          'output_probability': <Object?>['probabilities', 'float32', <int>[3]],
        },
        values: <String, List<dynamic>>{
          'label': <int>[1],
          'probabilities': <double>[0.21, 0.72, 0.41],
        },
      );
      FlutterOnnxruntimePlatform.instance = platform;

      final classifier = OnnxDiagnosisClassifier(
        runtime: _FakeOnnxRuntime(),
        labelsAsset: 'assets/models/diagnosis_lr_flutter_labels.json',
      );

      final prediction = await classifier.predict(_analysisRequest());

      expect(prediction.ranked, hasLength(3));
      expect(prediction.ranked[0].confidence, 0.72);
      expect(prediction.ranked[1].confidence, 0.41);
      expect(prediction.ranked[2].confidence, 0.21);
      expect(platform.releasedValueIds, containsAll(<String>[
        'label',
        'probabilities',
      ]));
    });

    test('ONNX classifier falls back to output label when probabilities missing',
        () async {
      FlutterOnnxruntimePlatform.instance = _FakeOnnxPlatform(
        outputs: <String, List<Object?>>{
          'output_label': <Object?>['label', 'int64', <int>[1]],
        },
        values: <String, List<dynamic>>{
          'label': <int>[0],
        },
      );

      final prediction = await OnnxDiagnosisClassifier(
        runtime: _FakeOnnxRuntime(),
      ).predict(_analysisRequest());

      expect(prediction.ranked, hasLength(1));
      expect(prediction.ranked.single.confidence, isNull);
    });

    test('ONNX classifier falls back to output label when probabilities malformed',
        () async {
      FlutterOnnxruntimePlatform.instance = _FakeOnnxPlatform(
        outputs: <String, List<Object?>>{
          'output_label': <Object?>['label', 'int64', <int>[1]],
          'output_probability': <Object?>['probabilities', 'string', <int>[1]],
        },
        values: <String, List<dynamic>>{
          'label': <int>[0],
          'probabilities': <String>['bad'],
        },
      );

      final prediction = await OnnxDiagnosisClassifier(
        runtime: _FakeOnnxRuntime(),
      ).predict(_analysisRequest());

      expect(prediction.ranked, hasLength(1));
      expect(prediction.ranked.single.confidence, isNull);
    });

    test('ONNX classifier throws when output label is missing', () async {
      FlutterOnnxruntimePlatform.instance = _FakeOnnxPlatform(
        outputs: <String, List<Object?>>{
          'output_probability': <Object?>['probabilities', 'float32', <int>[1]],
        },
        values: <String, List<dynamic>>{
          'probabilities': <double>[1],
        },
      );

      expect(
        OnnxDiagnosisClassifier(runtime: _FakeOnnxRuntime())
            .predict(_analysisRequest()),
        throwsA(isA<StateError>()),
      );
    });

    test('ONNX classifier throws when label index is out of range', () async {
      FlutterOnnxruntimePlatform.instance = _FakeOnnxPlatform(
        outputs: <String, List<Object?>>{
          'output_label': <Object?>['label', 'int64', <int>[1]],
        },
        values: <String, List<dynamic>>{
          'label': <int>[999],
        },
      );

      expect(
        OnnxDiagnosisClassifier(runtime: _FakeOnnxRuntime())
            .predict(_analysisRequest()),
        throwsA(isA<RangeError>()),
      );
    });

    test('default classifier factory keeps LR ONNX as active model', () {
      final classifier = DiagnosisClassifierFactory.create();

      expect(classifier, isA<OnnxDiagnosisClassifier>());
    });

    test('XGBoost bundle mode stays staged without injected scorer', () async {
      final classifier = DiagnosisClassifierFactory.create(
        mode: DiagnosisModelMode.xgbBundle,
      );

      expect(classifier, isA<XgbBundleDiagnosisClassifier>());
      expect(
        classifier.predict(
          const AnalysisRequest(
            language: SacaLanguage.english,
            inputMethod: InputMethod.text,
            transcript: '',
            textInput: 'fever cough',
            selectedSymptomIds: <String>{},
            selectedBodyAreaIds: <String>{},
            answers: <String, String>{},
          ),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('XGBoost bundle detects Git LFS pointer assets', () {
      expect(
        isGitLfsPointer(
          'version https://git-lfs.github.com/spec/v1\n'
          'oid sha256:abc\n'
          'size 123\n',
        ),
        isTrue,
      );
      expect(isGitLfsPointer('{"bundle_version":1}'), isFalse);
    });

    test('confidence level maps 70 and 40 percent thresholds', () {
      expect(
        const ConditionPrediction(label: 'a', rank: 1, confidence: 0.70)
            .confidenceLevel,
        ConfidenceLevel.high,
      );
      expect(
        const ConditionPrediction(label: 'b', rank: 2, confidence: 0.40)
            .confidenceLevel,
        ConfidenceLevel.medium,
      );
      expect(
        const ConditionPrediction(label: 'c', rank: 3, confidence: 0.39)
            .confidenceLevel,
        ConfidenceLevel.low,
      );
    });
  });
}

AnalysisRequest _analysisRequest() {
  return const AnalysisRequest(
    language: SacaLanguage.english,
    inputMethod: InputMethod.text,
    transcript: '',
    textInput: 'fever cough',
    selectedSymptomIds: <String>{},
    selectedBodyAreaIds: <String>{},
    answers: <String, String>{'severity': '4'},
  );
}

class _FakeOnnxRuntime extends OnnxRuntime {
  @override
  Future<OrtSession> createSessionFromAsset(
    String assetKey, {
    OrtSessionOptions? options,
  }) async {
    return OrtSession.fromMap(<String, dynamic>{
      'sessionId': 'test-session',
      'inputNames': <String>['combined_text', 'language', 'source'],
      'outputNames': <String>['output_label', 'output_probability'],
    });
  }
}

class _FailingOnnxRuntime extends OnnxRuntime {
  @override
  Future<OrtSession> createSessionFromAsset(
    String assetKey, {
    OrtSessionOptions? options,
  }) {
    throw StateError('model missing');
  }
}

class _FakeOnnxPlatform extends FlutterOnnxruntimePlatform
    with MockPlatformInterfaceMixin {
  _FakeOnnxPlatform({
    required this.outputs,
    required Map<String, List<dynamic>> values,
  }) : _values = Map<String, List<dynamic>>.from(values);

  final Map<String, List<Object?>> outputs;
  final Map<String, List<dynamic>> _values;
  final List<String> releasedValueIds = <String>[];
  int _nextValueId = 0;

  @override
  Future<Map<String, dynamic>> createOrtValue(
    String sourceType,
    dynamic data,
    List<int> shape,
  ) async {
    final id = 'input-${_nextValueId++}';
    _values[id] = data is List<dynamic> ? data : <dynamic>[data];
    return <String, dynamic>{
      'valueId': id,
      'dataType': sourceType,
      'shape': shape,
    };
  }

  @override
  Future<Map<String, dynamic>> runInference(
    String sessionId,
    Map<String, OrtValue> inputs, {
    Map<String, dynamic>? runOptions,
  }) async {
    return outputs;
  }

  @override
  Future<Map<String, dynamic>> getOrtValueData(String valueId) async {
    return <String, dynamic>{'data': _values[valueId] ?? const <dynamic>[]};
  }

  @override
  Future<void> releaseOrtValue(String valueId) async {
    releasedValueIds.add(valueId);
  }
}

class _FakeDiagnosisClassifier implements DiagnosisClassifier {
  const _FakeDiagnosisClassifier(this.label);

  final String label;

  @override
  Future<DiagnosisPrediction> predict(AnalysisRequest request) async {
    return DiagnosisPrediction(label: label, confidence: 0.9);
  }
}

class _CountingDiagnosisClassifier implements DiagnosisClassifier {
  _CountingDiagnosisClassifier(this.label);

  final String label;
  int callCount = 0;

  @override
  Future<DiagnosisPrediction> predict(AnalysisRequest request) async {
    callCount += 1;
    return DiagnosisPrediction(label: label, confidence: 0.9);
  }
}

class _ThrowingDiagnosisClassifier implements DiagnosisClassifier {
  const _ThrowingDiagnosisClassifier();

  @override
  Future<DiagnosisPrediction> predict(AnalysisRequest request) {
    throw StateError('classifier unavailable');
  }
}

class _TimeoutDiagnosisClassifier implements DiagnosisClassifier {
  const _TimeoutDiagnosisClassifier();

  @override
  Future<DiagnosisPrediction> predict(AnalysisRequest request) {
    throw TimeoutException('timed out');
  }
}
