import 'package:flutter/cupertino.dart';

class SacaTheme {
  const SacaTheme._();

  static const background = Color(0xFFFFF4F2);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF1F1F1F);
  static const mutedText = Color(0xFF646464);
  static const border = Color(0xFF8E8E93);
  static const selected = Color(0xFFD9EEF7);
  static const selectedBorder = Color(0xFF8FC8DE);
  static const emergency = Color(0xFFD92D20);
  static const warning = Color(0xFFFFC94A);
  static const safe = Color(0xFF75D05C);

  static const double phoneWidth = 430;
  static const double radius = 8;
  static const double minTapTarget = 52;
  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(20, 12, 20, 24);

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
}
