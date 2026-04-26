import 'package:flutter/foundation.dart';

enum SacaPlatformStyle { windowsDesktop, androidMobile }

class SacaPlatformStyleResolver {
  const SacaPlatformStyleResolver._();

  static const double desktopBreakpoint = 760;

  static SacaPlatformStyle resolve({
    required TargetPlatform platform,
    required double width,
  }) {
    if (platform == TargetPlatform.windows && width >= desktopBreakpoint) {
      return SacaPlatformStyle.windowsDesktop;
    }
    return SacaPlatformStyle.androidMobile;
  }
}
