class SttModelAsset {
  const SttModelAsset({required this.label, required this.path});

  final String label;
  final String path;
}

class SttModelCatalog {
  const SttModelCatalog._();

  static const mobileAssets = <SttModelAsset>[];
  static const desktopAssets = <SttModelAsset>[];
  static const activeAssets = <SttModelAsset>[];
}
