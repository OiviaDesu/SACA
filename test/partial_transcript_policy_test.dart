import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saca/infrastructure/speech/partial_transcript_policy.dart';

void main() {
  group('PartialTranscriptPolicy', () {
    test('enables PCM pseudo-streaming on desktop and mobile platforms', () {
      for (final platform in <TargetPlatform>[
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
        TargetPlatform.windows,
      ]) {
        expect(
          PartialTranscriptPolicy(platform: platform)
              .supportsPcmStreamRecording,
          isTrue,
          reason: platform.name,
        );
      }
    });

    test('uses slower and shorter partial decode policy on mobile', () {
      const android = PartialTranscriptPolicy(
        platform: TargetPlatform.android,
      );
      const desktop = PartialTranscriptPolicy(
        platform: TargetPlatform.windows,
      );

      expect(android.isMobile, isTrue);
      expect(android.pollingInterval, const Duration(milliseconds: 3000));
      expect(android.rollingWindow, const Duration(seconds: 8));
      expect(android.slowDecodeThreshold, const Duration(milliseconds: 4500));

      expect(desktop.isMobile, isFalse);
      expect(desktop.pollingInterval, const Duration(milliseconds: 1800));
      expect(desktop.rollingWindow, const Duration(seconds: 12));
      expect(desktop.slowDecodeThreshold, const Duration(milliseconds: 2700));
    });
  });
}
