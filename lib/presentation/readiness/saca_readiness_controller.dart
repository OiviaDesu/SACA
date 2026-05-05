import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:saca_demo/infrastructure/speech/whisper_service_io.dart';

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

  final AssetBundle _bundle;
  Set<String>? _assetManifestKeys;

  Future<SacaReadinessState> check() async {
    final issues = <String>[];
    try {
      final source = await _bundle
          .loadString('assets/models/classifier-xgb-best/bundle.json');
      final bundle = jsonDecode(source) as Map<String, dynamic>;
      final classes = bundle['classes'] as List<dynamic>? ?? const <dynamic>[];
      final model = bundle['model'] as Map<String, dynamic>?;
      final trees = model?['trees'] as List<dynamic>? ?? const <dynamic>[];
      if (classes.isEmpty || trees.isEmpty) {
        issues.add('XGB diagnosis bundle is empty.');
      }
    } catch (_) {
      issues.add('XGB diagnosis bundle is missing or invalid.');
    }

    await _checkSttAssets(issues);

    if (issues.isEmpty) return SacaReadinessState.ready;
    return SacaReadinessState(isReady: false, messages: issues);
  }

  Future<void> _checkSttAssets(List<String> issues) async {
    final hasMobileRc1 = await _hasAssetManifestEntry(
      SacaSttModelAssets.rc1MobileAssetPath,
    );
    if (!hasMobileRc1) {
      issues.add('RC1 mobile STT model is missing.');
    }

    for (final fileName in SacaSttModelAssets.windowsRequiredFiles) {
      final hasWindowsAsset = await _hasAssetManifestEntry(
        '${SacaSttModelAssets.rc1WindowsAssetBase}/$fileName',
      );
      if (!hasWindowsAsset) {
        issues.add('RC1 Windows STT $fileName is missing.');
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
      return null;
    }
  }
}
