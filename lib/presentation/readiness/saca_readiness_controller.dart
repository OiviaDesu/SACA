import 'dart:convert';

import 'package:flutter/services.dart';

class SacaReadinessState {
  const SacaReadinessState({required this.isReady, required this.messages});

  final bool isReady;
  final List<String> messages;

  static const ready = SacaReadinessState(
    isReady: true,
    messages: <String>['Active diagnosis model is available.'],
  );
}

class SacaReadinessController {
  SacaReadinessController({AssetBundle? bundle})
      : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  Future<SacaReadinessState> check() async {
    final issues = <String>[];
    try {
      final model =
          await _bundle.load('assets/models/diagnosis_lr_flutter.onnx');
      if (model.lengthInBytes == 0) {
        issues.add('Diagnosis model is empty.');
      }
    } catch (_) {
      issues.add('Diagnosis model is missing.');
    }

    try {
      final labelsSource = await _bundle
          .loadString('assets/models/diagnosis_lr_flutter_labels.json');
      final labels = jsonDecode(labelsSource) as Map<String, dynamic>;
      final classes = labels['classes'] as List<dynamic>? ?? const <dynamic>[];
      if (classes.isEmpty) {
        issues.add('Diagnosis labels are empty.');
      }
    } catch (_) {
      issues.add('Diagnosis labels are missing or invalid.');
    }

    if (issues.isEmpty) return SacaReadinessState.ready;
    return SacaReadinessState(isReady: false, messages: issues);
  }
}
