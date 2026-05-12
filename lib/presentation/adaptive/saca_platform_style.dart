import 'package:flutter/foundation.dart';

import '../../infrastructure/platform/desktop_shell_policy.dart';

enum SacaPlatformStyle { windowsDesktop, androidMobile }

class SacaPlatformStyleResolver {
  const SacaPlatformStyleResolver._();

  static SacaPlatformStyle resolve({
    required TargetPlatform platform,
    required double width,
  }) {
    if (DesktopShellPolicy.usesDesktopLayout(
      platform: platform,
      width: width,
    )) {
      return SacaPlatformStyle.windowsDesktop;
    }
    return SacaPlatformStyle.androidMobile;
  }
}
