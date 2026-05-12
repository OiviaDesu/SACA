import 'package:flutter/foundation.dart';

import 'saca_window_size_class.dart';

class SacaAdaptivePolicy {
  const SacaAdaptivePolicy._();

  static bool isDesktopPlatform(TargetPlatform platform) {
    return platform == TargetPlatform.windows ||
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.linux;
  }

  static bool isMobilePlatform(TargetPlatform platform) {
    return platform == TargetPlatform.android || platform == TargetPlatform.iOS;
  }

  static bool isDesktopInput(TargetPlatform platform) {
    return isDesktopPlatform(platform);
  }

  static bool supportsManagedWindow(TargetPlatform platform) {
    return platform == TargetPlatform.windows || platform == TargetPlatform.macOS;
  }

  static bool supportsHover(TargetPlatform platform) {
    return isDesktopPlatform(platform);
  }

  static bool supportsKeyboardShortcuts(TargetPlatform platform) {
    return isDesktopPlatform(platform);
  }

  static bool usesCompactFlow(double width) {
    final windowClass = SacaWindowSizeClasses.fromWidth(width);
    return windowClass == SacaWindowSizeClass.compact ||
        windowClass == SacaWindowSizeClass.medium;
  }

  static bool usesExpandedFlow(double width) {
    return !usesCompactFlow(width);
  }
}
