import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saca_demo/core/theme/saca_theme.dart';
import 'package:saca_demo/presentation/settings/saca_settings_controller.dart';

void main() {
  group('SacaSettingsController', () {
    test('defaults to light theme and larger readable text', () {
      final controller = SacaSettingsController(store: _MemorySettingsStore());

      expect(controller.state.themePreference, SacaThemePreference.light);
      expect(controller.state.textScale, 1.15);
    });

    test('loads saved theme and clamps text scale', () async {
      final store = _MemorySettingsStore(<String, Object?>{
        'saca.themePreference': 'dark',
        'saca.textScale': 2.0,
      });
      final controller = SacaSettingsController(store: store);

      await controller.load();

      expect(controller.state.themePreference, SacaThemePreference.dark);
      expect(controller.state.textScale, 1.40);
    });

    test('saves theme and text scale changes', () async {
      final store = _MemorySettingsStore();
      final controller = SacaSettingsController(store: store);

      await controller.setThemePreference(SacaThemePreference.system);
      await controller.setTextScale(0.5);

      expect(store.values['saca.themePreference'], 'system');
      expect(store.values['saca.textScale'], 0.90);
    });

    test('resolves brightness from preference', () {
      final controller = SacaSettingsController(store: _MemorySettingsStore());

      expect(controller.resolveBrightness(Brightness.dark), Brightness.light);
    });

    test('system theme follows platform brightness', () async {
      final controller = SacaSettingsController(store: _MemorySettingsStore());

      await controller.setThemePreference(SacaThemePreference.system);

      expect(controller.resolveBrightness(Brightness.dark), Brightness.dark);
      expect(controller.resolveBrightness(Brightness.light), Brightness.light);
    });

    test('dark palette uses neutral app background and surface', () {
      expect(SacaTheme.darkBackground, const Color(0xFF181818));
      expect(SacaTheme.darkColors.surfaceAlt, const Color(0xFF202020));
      expect(SacaTheme.darkColors.surfaceGradient.colors.first,
          const Color(0xFF202020));
    });
  });
}

class _MemorySettingsStore implements SacaSettingsStore {
  _MemorySettingsStore([Map<String, Object?>? values])
      : values = Map<String, Object?>.from(values ?? const <String, Object?>{});

  final Map<String, Object?> values;

  @override
  Future<String?> getString(String key) async => values[key] as String?;

  @override
  Future<double?> getDouble(String key) async => values[key] as double?;

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> setDouble(String key, double value) async {
    values[key] = value;
  }
}
