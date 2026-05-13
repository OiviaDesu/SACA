import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:saca/infrastructure/speech/stt_model_catalog.dart';

class SacaReadinessState {
  const SacaReadinessState({required this.isReady, required this.messages});

  final bool isReady;
  final List<String> messages;

  static const ready = SacaReadinessState(
    isReady: true,
    messages: <String>['Active diagnosis and STT models are available.'],
  );
}

class SacaReadinessController {
  SacaReadinessController({AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  static const _diagnosisBundleAsset =
      'assets/models/saca-hybrid-logreg-v1/bundle.json';

  final AssetBundle _bundle;
  Set<String>? _assetManifestKeys;

  Future<SacaReadinessState> check() async {
    final issues = <String>[];
    final hasDiagnosisBundle = await _hasAssetManifestEntry(_diagnosisBundleAsset);
    if (!hasDiagnosisBundle) {
      issues.add('Hybrid LogReg diagnosis bundle is missing or invalid.');
    }

    await _checkSttAssets(issues);

    if (issues.isEmpty) return SacaReadinessState.ready;
    return SacaReadinessState(isReady: false, messages: issues);
  }

  Future<void> _checkSttAssets(List<String> issues) async {
    for (final asset in SttModelCatalog.activeAssets) {
      final exists = await _hasAssetManifestEntry(asset.path);
      if (!exists) {
        issues.add('${asset.label} is missing.');
      }
    }
  }

  Future<bool> _hasNonEmptyAsset(String key) async {
    try {
      final data = await _bundle.load(key);
      return data.lengthInBytes > 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _hasAssetManifestEntry(String key) async {
    final manifestKeys = await _loadAssetManifestKeys();
    if (manifestKeys != null) {
      return manifestKeys.contains(key);
    }
    return _hasNonEmptyAsset(key);
  }

  Future<Set<String>?> _loadAssetManifestKeys() async {
    if (_assetManifestKeys != null) {
      return _assetManifestKeys;
    }

    try {
      final manifest = await _bundle.loadString('AssetManifest.json');
      final decoded = jsonDecode(manifest) as Map<String, dynamic>;
      _assetManifestKeys = decoded.keys.toSet();
      return _assetManifestKeys;
    } catch (_) {
      try {
        final manifest = await _bundle.loadString('AssetManifest.bin.json');
        final decoded = jsonDecode(manifest) as Map<String, dynamic>;
        _assetManifestKeys = decoded.keys.toSet();
        return _assetManifestKeys;
      } catch (_) {
        return null;
      }
    }
  }
}
