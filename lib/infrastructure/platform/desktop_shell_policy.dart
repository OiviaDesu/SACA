import 'package:flutter/foundation.dart';

class DesktopShellPolicy {
  const DesktopShellPolicy._();

  static const double desktopBreakpoint = 760;

  static bool supportsDesktopShell(TargetPlatform platform) {
    return platform == TargetPlatform.windows ||
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.linux;
  }

  static bool usesDesktopLayout({
    required TargetPlatform platform,
    required double width,
  }) {
    return supportsDesktopShell(platform) && width >= desktopBreakpoint;
  }

  static bool supportsManagedWindow(TargetPlatform platform) {
    return platform == TargetPlatform.windows ||
        platform == TargetPlatform.macOS;
  }
}
