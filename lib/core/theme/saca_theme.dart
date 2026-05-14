import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ColorScheme, ThemeData;

enum SacaThemeSurfaceStyle { modern, glass, classic }

class SacaThemeStyleRenderer {
  const SacaThemeStyleRenderer._({
    required this.surfaceStyle,
    required this.glassUnavailable,
    required this.glassSolidFallback,
  });

  factory SacaThemeStyleRenderer.resolve({
    required SacaThemeSurfaceStyle surfaceStyle,
    required bool glassUnavailable,
    required bool glassSolidFallback,
  }) {
    return SacaThemeStyleRenderer._(
      surfaceStyle: surfaceStyle,
      glassUnavailable: glassUnavailable,
      glassSolidFallback: glassSolidFallback,
    );
  }

  final SacaThemeSurfaceStyle surfaceStyle;
  final bool glassUnavailable;
  final bool glassSolidFallback;

  bool get useGlass =>
      surfaceStyle == SacaThemeSurfaceStyle.glass &&
      !glassUnavailable &&
      !glassSolidFallback;
  bool get useGlassStyle =>
      surfaceStyle == SacaThemeSurfaceStyle.glass && !glassUnavailable;
  bool get useClassic => surfaceStyle == SacaThemeSurfaceStyle.classic;
  double get surfaceOpacity => switch (surfaceStyle) {
        SacaThemeSurfaceStyle.modern => 1.0,
        SacaThemeSurfaceStyle.glass => glassUnavailable ? 1.0 : 0.30,
        SacaThemeSurfaceStyle.classic => 1.0,
      };
  double get radiusScale => switch (surfaceStyle) {
        SacaThemeSurfaceStyle.modern => 1.0,
        SacaThemeSurfaceStyle.glass => 2.4,
        SacaThemeSurfaceStyle.classic => 1.6,
      };
  double get elevation => switch (surfaceStyle) {
        SacaThemeSurfaceStyle.modern => 1.0,
        SacaThemeSurfaceStyle.glass => glassUnavailable ? 1.0 : 2.8,
        SacaThemeSurfaceStyle.classic => 0.25,
      };
  bool get flattenGradients => useClassic;
  double get blurSigma => glassSolidFallback ? 0 : 18;
  double get scrimOpacity => glassSolidFallback ? 1 : 0.28;
  double get borderOpacity => glassSolidFallback ? 0.92 : 0.64;
  double get glowOpacity => glassSolidFallback ? 0.06 : 0.22;
}

enum SacaGlassMaterial { nav, panel, field, control, dialog }

enum SacaThemeSurfaceRole {
  surface,
  selected,
  accent,
  control,
  disabledControl,
  fieldSurface,
  warning,
  emergency,
  glassSurface,
  dynamic,
}

class SacaThemeScope extends InheritedWidget {
  const SacaThemeScope({
    super.key,
    required this.colors,
    this.surfaceStyle = SacaThemeSurfaceStyle.modern,
    this.glassUnavailable = false,
    this.glassSolidFallback = false,
    required super.child,
  });

  final SacaThemeColors colors;
  final SacaThemeSurfaceStyle surfaceStyle;
  final bool glassUnavailable;
  final bool glassSolidFallback;

  @override
  bool updateShouldNotify(SacaThemeScope oldWidget) =>
      colors != oldWidget.colors ||
      surfaceStyle != oldWidget.surfaceStyle ||
      glassUnavailable != oldWidget.glassUnavailable ||
      glassSolidFallback != oldWidget.glassSolidFallback;
}

class SacaThemeContext {
  const SacaThemeContext({
    required this.colors,
    required this.surfaceStyle,
    required this.glassUnavailable,
    required this.glassSolidFallback,
  });

  final SacaThemeColors colors;
  final SacaThemeSurfaceStyle surfaceStyle;
  final bool glassUnavailable;
  final bool glassSolidFallback;

  SacaThemeStyleRenderer get renderer => SacaThemeStyleRenderer.resolve(
        surfaceStyle: surfaceStyle,
        glassUnavailable: glassUnavailable,
        glassSolidFallback: glassSolidFallback,
      );

  bool get useGlass => renderer.useGlass;
  bool get useGlassStyle => renderer.useGlassStyle;
  bool get useClassic => renderer.useClassic;
  double get surfaceOpacity => renderer.surfaceOpacity;
  double get radiusScale => renderer.radiusScale;
  double get elevation => renderer.elevation;
  bool get flattenGradients => renderer.flattenGradients;
  double get blurSigma => renderer.blurSigma;
  double get scrimOpacity => renderer.scrimOpacity;
  double get borderOpacity => renderer.borderOpacity;
  double get glowOpacity => renderer.glowOpacity;

  double radius(double base) => base * radiusScale;

  Color foregroundFor(SacaThemeSurfaceRole role, {Color? background}) {
    return switch (role) {
      SacaThemeSurfaceRole.surface => colors.onSurface,
      SacaThemeSurfaceRole.selected => colors.onSelected,
      SacaThemeSurfaceRole.accent => colors.onAccent,
      SacaThemeSurfaceRole.control => colors.onControl,
      SacaThemeSurfaceRole.disabledControl => colors.onDisabledControl,
      SacaThemeSurfaceRole.fieldSurface => colors.onFieldSurface,
      SacaThemeSurfaceRole.warning => colors.onWarning,
      SacaThemeSurfaceRole.emergency => colors.onEmergency,
      SacaThemeSurfaceRole.glassSurface => colors.onGlassSurface,
      SacaThemeSurfaceRole.dynamic =>
        SacaTheme.contrastTextFor(background ?? colors.surface),
    };
  }

  Color glassMaterial(SacaGlassMaterial material) {
    if (glassSolidFallback) {
      return switch (material) {
        SacaGlassMaterial.nav => colors.surfaceAlt,
        SacaGlassMaterial.panel => colors.surface,
        SacaGlassMaterial.field => colors.fieldSurface,
        SacaGlassMaterial.control => colors.control,
        SacaGlassMaterial.dialog => colors.surface,
      };
    }
    return switch (material) {
      SacaGlassMaterial.nav => colors.glassNav,
      SacaGlassMaterial.panel => colors.glassPanel,
      SacaGlassMaterial.field => colors.glassField,
      SacaGlassMaterial.control => colors.glassControl,
      SacaGlassMaterial.dialog => colors.glassDialog,
    };
  }

  double glassOpacity(SacaGlassMaterial material) {
    if (glassSolidFallback) return 1;
    return switch (material) {
      SacaGlassMaterial.nav => 0.72,
      SacaGlassMaterial.panel => 0.58,
      SacaGlassMaterial.field => 0.84,
      SacaGlassMaterial.control => 0.88,
      SacaGlassMaterial.dialog => 0.9,
    };
  }

  LinearGradient surfaceGradient({bool selected = false}) {
    if (useGlassStyle) {
      final base =
          selected ? colors.control : glassMaterial(SacaGlassMaterial.panel);
      final end = selected ? colors.accent : colors.glassScrim;
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          base.withValues(
            alpha: selected ? 0.96 : glassOpacity(SacaGlassMaterial.panel),
          ),
          end.withValues(alpha: selected ? 0.88 : scrimOpacity),
        ],
      );
    }
    if (useClassic) {
      final base = selected ? colors.selected : colors.surfaceAlt;
      return LinearGradient(colors: [base, base]);
    }
    return selected ? colors.selectedGradient : colors.surfaceGradient;
  }

  List<BoxShadow> surfaceShadow({bool highlighted = false}) {
    if (useGlassStyle) {
      return <BoxShadow>[
        BoxShadow(
          color: colors.glassHighlight.withValues(
            alpha: highlighted ? glowOpacity + 0.10 : glowOpacity,
          ),
          blurRadius: highlighted ? 34 : 26,
          spreadRadius: highlighted ? 2 : 0,
          offset: const Offset(0, 16),
        ),
      ];
    }
    if (useClassic) {
      return <BoxShadow>[
        BoxShadow(
          color: colors.shadow.withValues(alpha: 0.35),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ];
    }
    return <BoxShadow>[
      BoxShadow(
        color: highlighted
            ? colors.selectedBorder.withValues(alpha: 0.18)
            : colors.shadow,
        blurRadius: highlighted ? 14 : 16,
        spreadRadius: highlighted ? 1 : 0,
        offset: highlighted ? Offset.zero : const Offset(0, 6),
      ),
    ];
  }

  static SacaThemeContext of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SacaThemeScope>();
    return SacaThemeContext(
      colors: scope?.colors ?? SacaTheme.lightColors,
      surfaceStyle: scope?.surfaceStyle ?? SacaThemeSurfaceStyle.modern,
      glassUnavailable: scope?.glassUnavailable ?? false,
      glassSolidFallback: scope?.glassSolidFallback ?? false,
    );
  }
}

class SacaThemeColors {
  const SacaThemeColors({
    required this.background,
    required this.backgroundAlt,
    required this.surface,
    required this.surfaceAlt,
    required this.onSurface,
    required this.onSurfaceMuted,
    required this.onSelected,
    required this.onAccent,
    required this.control,
    required this.onControl,
    required this.disabledControl,
    required this.onDisabledControl,
    required this.fieldSurface,
    required this.onFieldSurface,
    required this.fieldOutline,
    required this.onWarning,
    required this.onEmergency,
    required this.onGlassSurface,
    required this.glassNav,
    required this.glassPanel,
    required this.glassField,
    required this.glassControl,
    required this.glassDialog,
    required this.onGlassPrimary,
    required this.onGlassMuted,
    required this.glassBorder,
    required this.glassHighlight,
    required this.glassScrim,
    required this.border,
    required this.outline,
    required this.separator,
    required this.selected,
    required this.selectedBorder,
    required this.accent,
    required this.shadow,
    required this.shellGradient,
    required this.surfaceGradient,
    required this.selectedGradient,
  });

  final Color background;
  final Color backgroundAlt;
  final Color surface;
  final Color surfaceAlt;
  final Color onSurface;
  final Color onSurfaceMuted;
  final Color onSelected;
  final Color onAccent;
  final Color control;
  final Color onControl;
  final Color disabledControl;
  final Color onDisabledControl;
  final Color fieldSurface;
  final Color onFieldSurface;
  final Color fieldOutline;
  final Color onWarning;
  final Color onEmergency;
  final Color onGlassSurface;
  final Color glassNav;
  final Color glassPanel;
  final Color glassField;
  final Color glassControl;
  final Color glassDialog;
  final Color onGlassPrimary;
  final Color onGlassMuted;
  final Color glassBorder;
  final Color glassHighlight;
  final Color glassScrim;
  final Color border;
  final Color outline;
  final Color separator;
  final Color selected;
  final Color selectedBorder;
  final Color accent;
  final Color shadow;
  final LinearGradient shellGradient;
  final LinearGradient surfaceGradient;
  final LinearGradient selectedGradient;

  Color get text => onSurface;
  Color get mutedText => onSurfaceMuted;

  static SacaThemeColors lerp(
    SacaThemeColors a,
    SacaThemeColors b,
    double t,
  ) {
    return SacaThemeColors(
      background: Color.lerp(a.background, b.background, t)!,
      backgroundAlt: Color.lerp(a.backgroundAlt, b.backgroundAlt, t)!,
      surface: Color.lerp(a.surface, b.surface, t)!,
      surfaceAlt: Color.lerp(a.surfaceAlt, b.surfaceAlt, t)!,
      onSurface: Color.lerp(a.onSurface, b.onSurface, t)!,
      onSurfaceMuted: Color.lerp(a.onSurfaceMuted, b.onSurfaceMuted, t)!,
      onSelected: Color.lerp(a.onSelected, b.onSelected, t)!,
      onAccent: Color.lerp(a.onAccent, b.onAccent, t)!,
      control: Color.lerp(a.control, b.control, t)!,
      onControl: Color.lerp(a.onControl, b.onControl, t)!,
      disabledControl: Color.lerp(a.disabledControl, b.disabledControl, t)!,
      onDisabledControl:
          Color.lerp(a.onDisabledControl, b.onDisabledControl, t)!,
      fieldSurface: Color.lerp(a.fieldSurface, b.fieldSurface, t)!,
      onFieldSurface: Color.lerp(a.onFieldSurface, b.onFieldSurface, t)!,
      fieldOutline: Color.lerp(a.fieldOutline, b.fieldOutline, t)!,
      onWarning: Color.lerp(a.onWarning, b.onWarning, t)!,
      onEmergency: Color.lerp(a.onEmergency, b.onEmergency, t)!,
      onGlassSurface: Color.lerp(a.onGlassSurface, b.onGlassSurface, t)!,
      glassNav: Color.lerp(a.glassNav, b.glassNav, t)!,
      glassPanel: Color.lerp(a.glassPanel, b.glassPanel, t)!,
      glassField: Color.lerp(a.glassField, b.glassField, t)!,
      glassControl: Color.lerp(a.glassControl, b.glassControl, t)!,
      glassDialog: Color.lerp(a.glassDialog, b.glassDialog, t)!,
      onGlassPrimary: Color.lerp(a.onGlassPrimary, b.onGlassPrimary, t)!,
      onGlassMuted: Color.lerp(a.onGlassMuted, b.onGlassMuted, t)!,
      glassBorder: Color.lerp(a.glassBorder, b.glassBorder, t)!,
      glassHighlight: Color.lerp(a.glassHighlight, b.glassHighlight, t)!,
      glassScrim: Color.lerp(a.glassScrim, b.glassScrim, t)!,
      border: Color.lerp(a.border, b.border, t)!,
      outline: Color.lerp(a.outline, b.outline, t)!,
      separator: Color.lerp(a.separator, b.separator, t)!,
      selected: Color.lerp(a.selected, b.selected, t)!,
      selectedBorder: Color.lerp(a.selectedBorder, b.selectedBorder, t)!,
      accent: Color.lerp(a.accent, b.accent, t)!,
      shadow: Color.lerp(a.shadow, b.shadow, t)!,
      shellGradient: LinearGradient.lerp(a.shellGradient, b.shellGradient, t)!,
      surfaceGradient:
          LinearGradient.lerp(a.surfaceGradient, b.surfaceGradient, t)!,
      selectedGradient:
          LinearGradient.lerp(a.selectedGradient, b.selectedGradient, t)!,
    );
  }

  static SacaThemeColors of(BuildContext context) {
    return SacaThemeContext.of(context).colors;
  }
}

class SacaTheme {
  const SacaTheme._();

  static const background = Color(0xFFFFF3F5);
  static const backgroundAlt = Color(0xFFFFF8F7);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFFFF7F5);
  static const text = Color(0xFF1F1F1F);
  static const mutedText = Color(0xFF646464);
  static const border = Color(0xFFE5D2D4);
  static const selected = Color(0xFFFFDDE2);
  static const selectedBorder = Color(0xFFE46E83);
  static const accent = Color(0xFFC23355);
  static const vividAccent = Color(0xFFC2185B);
  static const emergency = Color(0xFFD92D20);
  static const warning = Color(0xFFFFC94A);
  static const safe = Color(0xFF75D05C);

  static const darkBackground = Color(0xFF181818);
  static const darkSurface = Color(0xFF202020);
  static const darkText = Color(0xFFFFF7F7);
  static const darkMutedText = Color(0xFFE2C9CF);
  static const darkBorder = Color(0xFF3A3A3A);
  static const darkSelected = Color(0xFF633043);
  static const darkSelectedBorder = Color(0xFFFF8FA5);

  static const double phoneWidth = 430;
  static const double radius = 8;
  static const double minTapTarget = 52;
  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(20, 12, 20, 24);

  static const LinearGradient shellGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFFF6F4),
      Color(0xFFFFEEF3),
    ],
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFFFF7F5),
    ],
  );

  static const LinearGradient selectedGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFE4E9),
      Color(0xFFFFC7D1),
    ],
  );

  static const lightColors = SacaThemeColors(
    background: background,
    backgroundAlt: backgroundAlt,
    surface: surface,
    surfaceAlt: surfaceAlt,
    onSurface: text,
    onSurfaceMuted: mutedText,
    onSelected: text,
    onAccent: surface,
    control: vividAccent,
    onControl: surface,
    disabledControl: Color(0xFFF4DDE4),
    onDisabledControl: Color(0xFF5C2332),
    fieldSurface: Color(0xFFFFF7F9),
    onFieldSurface: text,
    fieldOutline: Color(0xFFD27B91),
    onWarning: Color(0xFF332400),
    onEmergency: surface,
    onGlassSurface: text,
    glassNav: Color(0xFFFFFFFF),
    glassPanel: Color(0xFFFFFFFF),
    glassField: Color(0xFFFFFBFC),
    glassControl: vividAccent,
    glassDialog: Color(0xFFFFFFFF),
    onGlassPrimary: text,
    onGlassMuted: Color(0xFF5A4A50),
    glassBorder: Color(0xFFD8A8B7),
    glassHighlight: Color(0xFFFFFFFF),
    glassScrim: Color(0xFFFFFFFF),
    border: border,
    outline: border,
    separator: Color(0xFFEAD8DA),
    selected: selected,
    selectedBorder: selectedBorder,
    accent: accent,
    shadow: Color(0x12000000),
    shellGradient: shellGradient,
    surfaceGradient: surfaceGradient,
    selectedGradient: selectedGradient,
  );

  static const darkShellGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF202020), Color(0xFF181818)],
  );

  static const darkSurfaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF202020), Color(0xFF181818)],
  );

  static const darkSelectedGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6D3348), Color(0xFF8A4058)],
  );

  static const darkColors = SacaThemeColors(
    background: darkBackground,
    backgroundAlt: Color(0xFF202020),
    surface: darkSurface,
    surfaceAlt: Color(0xFF202020),
    onSurface: darkText,
    onSurfaceMuted: darkMutedText,
    onSelected: darkText,
    onAccent: Color(0xFFFFFFFF),
    control: Color(0xFF8A2746),
    onControl: Color(0xFFFFFFFF),
    disabledControl: Color(0xFF2A1D22),
    onDisabledControl: Color(0xFFF8DDE4),
    fieldSurface: Color(0xFF151515),
    onFieldSurface: darkText,
    fieldOutline: Color(0xFF6D4B56),
    onWarning: Color(0xFF2D2300),
    onEmergency: Color(0xFFFFFFFF),
    onGlassSurface: Color(0xFFFFFFFF),
    glassNav: Color(0xFF080808),
    glassPanel: Color(0xFF101010),
    glassField: Color(0xFF151515),
    glassControl: Color(0xFF8A2746),
    glassDialog: Color(0xFF121212),
    onGlassPrimary: darkText,
    onGlassMuted: Color(0xFFD9D0D3),
    glassBorder: Color(0xFF5F414B),
    glassHighlight: Color(0xFFB45A75),
    glassScrim: Color(0xFF000000),
    border: darkBorder,
    outline: darkBorder,
    separator: Color(0xFF383238),
    selected: darkSelected,
    selectedBorder: darkSelectedBorder,
    accent: Color(0xFF8A2746),
    shadow: Color(0x66000000),
    shellGradient: darkShellGradient,
    surfaceGradient: darkSurfaceGradient,
    selectedGradient: darkSelectedGradient,
  );

  static const TextStyle logoText = TextStyle(
    fontSize: 52,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    color: text,
    fontStyle: FontStyle.italic,
  );

  static const TextStyle title = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    color: text,
  );

  static const TextStyle body = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    color: text,
    height: 1.15,
  );

  static const TextStyle small = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    color: mutedText,
  );

  static const CupertinoThemeData cupertinoTheme = CupertinoThemeData(
    brightness: Brightness.light,
    primaryColor: text,
    scaffoldBackgroundColor: background,
    textTheme: CupertinoTextThemeData(
      textStyle: body,
      navTitleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: text,
      ),
      navActionTextStyle: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: text,
      ),
    ),
  );

  static const CupertinoThemeData darkCupertinoTheme = CupertinoThemeData(
    brightness: Brightness.dark,
    primaryColor: darkText,
    scaffoldBackgroundColor: darkBackground,
    barBackgroundColor: darkSurface,
    textTheme: CupertinoTextThemeData(
      textStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        color: darkText,
        height: 1.15,
      ),
      navTitleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: darkText,
      ),
      navActionTextStyle: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: darkText,
      ),
    ),
  );

  static ThemeData materialTheme(
      SacaThemeColors colors, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: colors.control,
      brightness: brightness,
    ).copyWith(
      primary: colors.control,
      onPrimary: colors.onControl,
      surface: colors.surface,
      onSurface: colors.onSurface,
      outline: colors.outline,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.background,
    );
  }

  static Color contrastTextFor(Color background) {
    final brightness = ThemeData.estimateBrightnessForColor(background);
    return brightness == Brightness.dark
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF111111);
  }
}
