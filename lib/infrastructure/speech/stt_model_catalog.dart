import 'whisper_service_io.dart';

class SttModelAsset {
  const SttModelAsset({required this.label, required this.path});

  final String label;
  final String path;
}

class SttModelCatalog {
  const SttModelCatalog._();

  static const mobileAssets = <SttModelAsset>[
    SttModelAsset(
      label: 'RC1 mobile STT model',
      path: SacaSttModelAssets.rc1MobileAssetPath,
    ),
  ];

  static List<SttModelAsset> get desktopAssets {
    return SacaSttModelAssets.windowsRequiredFiles
        .map(
          (fileName) => SttModelAsset(
            label: 'RC1 desktop STT $fileName',
            path: '${SacaSttModelAssets.rc1WindowsAssetBase}/$fileName',
          ),
        )
        .toList(growable: false);
  }

  static List<SttModelAsset> get activeAssets => <SttModelAsset>[
    ...mobileAssets,
    ...desktopAssets,
  ];
}
