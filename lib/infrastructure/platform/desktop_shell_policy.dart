import 'package:flutter/foundation.dart';

import '../../core/layout/saca_adaptive_policy.dart';
import '../../core/layout/saca_window_size_class.dart';

class DesktopShellPolicy {
  const DesktopShellPolicy._();

  static const double desktopBreakpoint = SacaWindowSizeClasses.expanded;

  static bool supportsDesktopShell(TargetPlatform platform) {
    return SacaAdaptivePolicy.isDesktopPlatform(platform);
  }

  static bool usesDesktopLayout({
    required TargetPlatform platform,
    required double width,
  }) {
    return supportsDesktopShell(platform) && width >= desktopBreakpoint;
  }

  static bool supportsManagedWindow(TargetPlatform platform) {
    return SacaAdaptivePolicy.supportsManagedWindow(platform);
  }
}
