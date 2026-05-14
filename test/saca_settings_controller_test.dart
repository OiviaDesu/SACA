import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saca/core/theme/saca_theme.dart';
import 'package:saca/presentation/settings/saca_settings_controller.dart';

void main() {
  group('SacaSettingsController', () {
    test('defaults to light theme, modern style, and larger readable text', () {
      final controller = SacaSettingsController(store: _MemorySettingsStore());

      expect(controller.state.themePreference, SacaThemePreference.light);
      expect(controller.state.visualThemeStyle, SacaVisualThemeStyle.modern);
      expect(controller.state.textScale, 1.15);
    });

    test('loads saved theme style and clamps text scale', () async {
      final store = _MemorySettingsStore(<String, Object?>{
        'saca.themePreference': 'dark',
        'saca.visualThemeStyle': 'classic',
        'saca.textScale': 2.0,
      });
      final controller = SacaSettingsController(store: store);

      await controller.load();

      expect(controller.state.themePreference, SacaThemePreference.dark);
      expect(controller.state.visualThemeStyle, SacaVisualThemeStyle.classic);
      expect(controller.state.textScale, 1.40);
    });

    test('saves theme style and text scale changes', () async {
      final store = _MemorySettingsStore();
      final controller = SacaSettingsController(store: store);

      await controller.setThemePreference(SacaThemePreference.system);
      await controller.setVisualThemeStyle(SacaVisualThemeStyle.glass);
      await controller.setTextScale(0.5);

      expect(store.values['saca.themePreference'], 'system');
      expect(store.values['saca.visualThemeStyle'], 'glass');
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
      expect(SacaTheme.darkColors.surface, const Color(0xFF202020));
      expect(SacaTheme.darkColors.surfaceAlt, const Color(0xFF202020));
      expect(SacaTheme.darkColors.surfaceGradient.colors.first,
          const Color(0xFF202020));
    });

    test('classic material theme uses Material 3', () {
      final theme = SacaTheme.materialTheme(
        SacaTheme.lightColors,
        Brightness.light,
      );

      expect(theme.useMaterial3, isTrue);
      expect(theme.scaffoldBackgroundColor, SacaTheme.lightColors.background);
    });

    test('theme style renderer resolves distinct style adapters', () {
      final modern = SacaThemeStyleRenderer.resolve(
        surfaceStyle: SacaThemeSurfaceStyle.modern,
        glassUnavailable: false,
        glassSolidFallback: false,
      );
      final glass = SacaThemeStyleRenderer.resolve(
        surfaceStyle: SacaThemeSurfaceStyle.glass,
        glassUnavailable: false,
        glassSolidFallback: false,
      );
      final classic = SacaThemeStyleRenderer.resolve(
        surfaceStyle: SacaThemeSurfaceStyle.classic,
        glassUnavailable: false,
        glassSolidFallback: false,
      );

      expect(modern.useGlassStyle, isFalse);
      expect(glass.useGlassStyle, isTrue);
      expect(classic.flattenGradients, isTrue);
      expect(glass.surfaceOpacity, lessThan(modern.surfaceOpacity));
      expect(classic.radiusScale, isNot(modern.radiusScale));
    });

    test('visual styles resolve distinct theme tokens', () {
      const modern = SacaThemeContext(
        colors: SacaTheme.lightColors,
        surfaceStyle: SacaThemeSurfaceStyle.modern,
        glassUnavailable: false,
        glassSolidFallback: false,
      );
      const glass = SacaThemeContext(
        colors: SacaTheme.lightColors,
        surfaceStyle: SacaThemeSurfaceStyle.glass,
        glassUnavailable: false,
        glassSolidFallback: false,
      );
      const classic = SacaThemeContext(
        colors: SacaTheme.lightColors,
        surfaceStyle: SacaThemeSurfaceStyle.classic,
        glassUnavailable: false,
        glassSolidFallback: false,
      );

      expect(glass.surfaceOpacity, lessThan(modern.surfaceOpacity));
      expect(glass.radiusScale, greaterThan(modern.radiusScale));
      expect(classic.flattenGradients, isTrue);
      expect(classic.radiusScale, isNot(modern.radiusScale));
    });

    test('semantic color roles keep compatibility aliases', () {
      expect(SacaTheme.lightColors.text, SacaTheme.lightColors.onSurface);
      expect(
        SacaTheme.lightColors.mutedText,
        SacaTheme.lightColors.onSurfaceMuted,
      );
      expect(SacaTheme.darkColors.text, SacaTheme.darkColors.onSurface);
      expect(
        SacaTheme.darkColors.mutedText,
        SacaTheme.darkColors.onSurfaceMuted,
      );
      expect(SacaTheme.lightColors.control, isNot(SacaTheme.emergency));
      expect(SacaTheme.darkColors.control, isNot(SacaTheme.emergency));
    });

    test('glass colors prioritize neutral readability', () {
      expect(SacaTheme.lightColors.glassPanel, const Color(0xFFFFFFFF));
      expect(SacaTheme.lightColors.glassField, const Color(0xFFFFFBFC));
      expect(SacaTheme.lightColors.glassControl, SacaTheme.lightColors.control);
      expect(SacaTheme.darkColors.background, const Color(0xFF181818));
      expect(SacaTheme.darkColors.glassScrim, const Color(0xFF000000));
      expect(SacaTheme.darkColors.glassPanel, const Color(0xFF101010));
      expect(SacaTheme.darkColors.glassControl, const Color(0xFF8A2746));
      expect(
        _contrastRatio(
          SacaTheme.darkColors.glassControl,
          SacaTheme.darkColors.onControl,
        ),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('modern baseline tokens remain stable', () {
      expect(SacaTheme.lightColors.background, SacaTheme.background);
      expect(SacaTheme.lightColors.surface, SacaTheme.surface);
      expect(SacaTheme.lightColors.surfaceAlt, SacaTheme.surfaceAlt);
      expect(SacaTheme.lightColors.selected, SacaTheme.selected);
      expect(SacaTheme.lightColors.selectedBorder, SacaTheme.selectedBorder);
      expect(SacaTheme.lightColors.control, SacaTheme.vividAccent);
      expect(SacaTheme.lightColors.onControl, SacaTheme.surface);
    });

    test('glass material tokens are component specific', () {
      const glass = SacaThemeContext(
        colors: SacaTheme.lightColors,
        surfaceStyle: SacaThemeSurfaceStyle.glass,
        glassUnavailable: false,
        glassSolidFallback: false,
      );
      const solidGlass = SacaThemeContext(
        colors: SacaTheme.lightColors,
        surfaceStyle: SacaThemeSurfaceStyle.glass,
        glassUnavailable: false,
        glassSolidFallback: true,
      );

      expect(glass.useGlass, isTrue);
      expect(glass.useGlassStyle, isTrue);
      expect(solidGlass.useGlass, isFalse);
      expect(solidGlass.useGlassStyle, isTrue);
      expect(
        glass.glassMaterial(SacaGlassMaterial.nav),
        isNot(glass.glassMaterial(SacaGlassMaterial.field)),
      );
      expect(
        glass.glassOpacity(SacaGlassMaterial.field),
        greaterThan(glass.glassOpacity(SacaGlassMaterial.panel)),
      );
      expect(solidGlass.glassOpacity(SacaGlassMaterial.panel), 1);
      expect(solidGlass.blurSigma, 0);
    });

    test('semantic foreground pairs keep readable contrast', () {
      final pairs = <(Color, Color)>[
        (SacaTheme.lightColors.surface, SacaTheme.lightColors.onSurface),
        (SacaTheme.lightColors.selected, SacaTheme.lightColors.onSelected),
        (SacaTheme.lightColors.accent, SacaTheme.lightColors.onAccent),
        (SacaTheme.lightColors.control, SacaTheme.lightColors.onControl),
        (
          SacaTheme.lightColors.disabledControl,
          SacaTheme.lightColors.onDisabledControl,
        ),
        (
          SacaTheme.lightColors.fieldSurface,
          SacaTheme.lightColors.onFieldSurface,
        ),
        (SacaTheme.lightColors.onWarning, SacaTheme.warning),
        (SacaTheme.darkColors.surface, SacaTheme.darkColors.onSurface),
        (SacaTheme.darkColors.selected, SacaTheme.darkColors.onSelected),
        (SacaTheme.darkColors.accent, SacaTheme.darkColors.onAccent),
        (SacaTheme.darkColors.control, SacaTheme.darkColors.onControl),
        (
          SacaTheme.darkColors.disabledControl,
          SacaTheme.darkColors.onDisabledControl,
        ),
        (
          SacaTheme.darkColors.fieldSurface,
          SacaTheme.darkColors.onFieldSurface,
        ),
        (SacaTheme.darkColors.onWarning, SacaTheme.warning),
      ];

      for (final (background, foreground) in pairs) {
        expect(
          _contrastRatio(background, foreground),
          greaterThanOrEqualTo(4.5),
          reason: '$foreground on $background should be readable',
        );
      }
    });

    test('dynamic foreground helper follows runtime background brightness', () {
      expect(
        SacaTheme.contrastTextFor(const Color(0xFF101010)),
        const Color(0xFFFFFFFF),
      );
      expect(
        SacaTheme.contrastTextFor(const Color(0xFFFFFDFB)),
        const Color(0xFF111111),
      );
    });

    test('classic material scheme uses vivid non-emergency control accent', () {
      final theme = SacaTheme.materialTheme(
        SacaTheme.lightColors,
        Brightness.light,
      );

      expect(theme.colorScheme.primary, SacaTheme.lightColors.control);
      expect(theme.colorScheme.primary, isNot(SacaTheme.accent));
      expect(theme.colorScheme.primary, isNot(SacaTheme.emergency));
      expect(theme.colorScheme.onPrimary, SacaTheme.lightColors.onControl);
    });

    test('store readiness docs are linked and scoped to supported platforms',
        () {
      final readme = File('README.md').readAsStringSync();
      final storeReadiness = File('docs/store_readiness.md').readAsStringSync();
      final fallbackMatrix =
          File('docs/permissions_fallback_matrix.md').readAsStringSync();

      expect(readme, contains('docs/store_readiness.md'));
      expect(readme, contains('docs/permissions_fallback_matrix.md'));
      expect(storeReadiness, contains('Windows, macOS, iOS, and Android'));
      expect(storeReadiness, contains('not a guarantee'));
      expect(fallbackMatrix, contains('No speech detected'));
      expect(fallbackMatrix, contains('No clear illness match'));
    });
  });
}

double _contrastRatio(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  final lighter = l1 > l2 ? l1 : l2;
  final darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
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
