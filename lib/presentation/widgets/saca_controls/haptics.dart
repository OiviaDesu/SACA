part of '../saca_controls.dart';

class SacaHaptics {
  const SacaHaptics._();

  static Future<void> selection() => _mobileOnly(HapticFeedback.selectionClick);

  static Future<void> tap() => _mobileOnly(HapticFeedback.lightImpact);

  static Future<void> confirm() => _mobileOnly(HapticFeedback.mediumImpact);

  static Future<void> warning() => _mobileOnly(HapticFeedback.heavyImpact);

  static Future<void> _mobileOnly(Future<void> Function() feedback) async {
    if (kIsWeb || !SacaAdaptivePolicy.isMobilePlatform(defaultTargetPlatform)) {
      return;
    }
    await feedback();
  }
}
