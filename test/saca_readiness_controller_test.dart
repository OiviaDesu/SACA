import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saca_demo/infrastructure/speech/whisper_service_io.dart';
import 'package:saca_demo/presentation/readiness/saca_readiness_controller.dart';

void main() {
  test('ready state passes when active assets exist', () async {
    final controller = SacaReadinessController(
      bundle: _FakeAssetBundle(
        bytes: <String, ByteData>{
          SacaSttModelAssets.rc1MobileAssetPath: ByteData.sublistView(
            Uint8List.fromList(<int>[1]),
          ),
          '${SacaSttModelAssets.rc1WindowsAssetBase}/encoder.onnx':
              ByteData.sublistView(Uint8List.fromList(<int>[1])),
          '${SacaSttModelAssets.rc1WindowsAssetBase}/decoder.onnx':
              ByteData.sublistView(Uint8List.fromList(<int>[1])),
          '${SacaSttModelAssets.rc1WindowsAssetBase}/tokens.txt':
              ByteData.sublistView(Uint8List.fromList(<int>[1])),
        },
        strings: <String, String>{
          'AssetManifest.json': jsonEncode(<String, List<String>>{
            SacaSttModelAssets.rc1MobileAssetPath: <String>[],
            '${SacaSttModelAssets.rc1WindowsAssetBase}/encoder.onnx':
                <String>[],
            '${SacaSttModelAssets.rc1WindowsAssetBase}/decoder.onnx':
                <String>[],
            '${SacaSttModelAssets.rc1WindowsAssetBase}/tokens.txt': <String>[],
          }),
          'assets/models/classifier-xgb-best/bundle.json': jsonEncode(
            <String, Object>{
              'classes': <String>['a', 'b'],
              'model': <String, Object>{
                'trees': <Object>[<String, Object>{}],
              },
            },
          ),
        },
      ),
    );

    final state = await controller.check();

    expect(state.isReady, isTrue);
  });

  test('not ready when RC1 STT assets are missing', () async {
    final controller = SacaReadinessController(
      bundle: _FakeAssetBundle(
        bytes: <String, ByteData>{},
        strings: <String, String>{
          'assets/models/classifier-xgb-best/bundle.json': jsonEncode(
            <String, Object>{
              'classes': <String>['a', 'b'],
              'model': <String, Object>{
                'trees': <Object>[<String, Object>{}],
              },
            },
          ),
        },
      ),
    );

    final state = await controller.check();

    expect(state.isReady, isFalse);
    expect(
      state.messages,
      containsAll(<String>[
        'RC1 mobile STT model is missing.',
        'RC1 desktop STT encoder.onnx is missing.',
        'RC1 desktop STT decoder.onnx is missing.',
        'RC1 desktop STT tokens.txt is missing.',
      ]),
    );
  });

  test('not ready when active assets missing', () async {
    final controller = SacaReadinessController(bundle: _FakeAssetBundle());

    final state = await controller.check();

    expect(state.isReady, isFalse);
    expect(state.messages, isNotEmpty);
  });
}

class _FakeAssetBundle extends CachingAssetBundle {
  _FakeAssetBundle({
    this.bytes = const <String, ByteData>{},
    this.strings = const <String, String>{},
  });

  final Map<String, ByteData> bytes;
  final Map<String, String> strings;

  @override
  Future<ByteData> load(String key) async {
    final value = bytes[key];
    if (value == null) throw Exception('missing $key');
    return value;
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final value = strings[key];
    if (value == null) throw Exception('missing $key');
    return value;
  }
}
