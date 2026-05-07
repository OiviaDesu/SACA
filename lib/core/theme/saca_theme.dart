import 'package:flutter/cupertino.dart';

class SacaThemeScope extends InheritedWidget {
  const SacaThemeScope({
    super.key,
    required this.colors,
    required super.child,
  });

  final SacaThemeColors colors;

  @override
  bool updateShouldNotify(SacaThemeScope oldWidget) =>
      colors != oldWidget.colors;
}

class SacaThemeColors {
  const SacaThemeColors({
    required this.background,
    required this.backgroundAlt,
    required this.surface,
    required this.surfaceAlt,
    required this.text,
    required this.mutedText,
    required this.border,
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
  final Color text;
  final Color mutedText;
  final Color border;
  final Color selected;
  final Color selectedBorder;
  final Color accent;
  final Color shadow;
  final LinearGradient shellGradient;
  final LinearGradient surfaceGradient;
  final LinearGradient selectedGradient;

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
      text: Color.lerp(a.text, b.text, t)!,
      mutedText: Color.lerp(a.mutedText, b.mutedText, t)!,
      border: Color.lerp(a.border, b.border, t)!,
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
    return context
            .dependOnInheritedWidgetOfExactType<SacaThemeScope>()
            ?.colors ??
        SacaTheme.lightColors;
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
    text: text,
    mutedText: mutedText,
    border: border,
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
    text: darkText,
    mutedText: darkMutedText,
    border: darkBorder,
    selected: darkSelected,
    selectedBorder: darkSelectedBorder,
    accent: Color(0xFFFF8FA5),
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
}
