import 'package:flutter/foundation.dart';

class PartialTranscriptPolicy {
  const PartialTranscriptPolicy({
    TargetPlatform? platform,
  }) : _platform = platform;

  final TargetPlatform? _platform;

  TargetPlatform get platform => _platform ?? defaultTargetPlatform;

  bool get supportsPcmStreamRecording {
    return switch (platform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.macOS ||
      TargetPlatform.windows =>
        true,
      TargetPlatform.fuchsia || TargetPlatform.linux => false,
    };
  }

  bool get isMobile {
    return platform == TargetPlatform.android || platform == TargetPlatform.iOS;
  }

  Duration get pollingInterval {
    return isMobile
        ? const Duration(milliseconds: 3000)
        : const Duration(milliseconds: 1800);
  }

  Duration get rollingWindow {
    return isMobile ? const Duration(seconds: 8) : const Duration(seconds: 12);
  }

  Duration get slowDecodeThreshold {
    return Duration(
        milliseconds: (pollingInterval.inMilliseconds * 1.5).round());
  }
}
