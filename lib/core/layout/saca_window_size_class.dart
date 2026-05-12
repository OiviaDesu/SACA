enum SacaWindowSizeClass { compact, medium, expanded, large, extraLarge }

extension SacaWindowSizeClassX on SacaWindowSizeClass {
  bool get isCompact => this == SacaWindowSizeClass.compact;
  bool get isMedium => this == SacaWindowSizeClass.medium;
  bool get isExpandedOrLarger => index >= SacaWindowSizeClass.expanded.index;
  bool get isLargeOrLarger => index >= SacaWindowSizeClass.large.index;
  bool get isExtraLarge => this == SacaWindowSizeClass.extraLarge;
}

class SacaWindowSizeClasses {
  const SacaWindowSizeClasses._();

  static const double medium = 600;
  static const double expanded = 840;
  static const double large = 1200;
  static const double extraLarge = 1600;

  static SacaWindowSizeClass fromWidth(double width) {
    if (width < medium) return SacaWindowSizeClass.compact;
    if (width < expanded) return SacaWindowSizeClass.medium;
    if (width < large) return SacaWindowSizeClass.expanded;
    if (width < extraLarge) return SacaWindowSizeClass.large;
    return SacaWindowSizeClass.extraLarge;
  }
}
