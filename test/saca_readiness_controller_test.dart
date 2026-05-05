import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saca_demo/presentation/readiness/saca_readiness_controller.dart';

void main() {
  test('ready state passes when active assets exist', () async {
    final controller = SacaReadinessController(
      bundle: _FakeAssetBundle(
        bytes: <String, ByteData>{
          'assets/models/diagnosis_lr_flutter.onnx':
              ByteData.sublistView(Uint8List.fromList(<int>[1, 2, 3])),
        },
        strings: <String, String>{
          'assets/models/diagnosis_lr_flutter_labels.json':
              jsonEncode(<String, Object>{
            'classes': <String>['a', 'b']
          }),
        },
      ),
    );

    final state = await controller.check();

    expect(state.isReady, isTrue);
  });

  test('not ready when active assets missing', () async {
    final controller = SacaReadinessController(
      bundle: _FakeAssetBundle(),
    );

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
