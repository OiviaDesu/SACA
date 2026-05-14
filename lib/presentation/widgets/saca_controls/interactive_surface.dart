part of '../saca_controls.dart';

Key? _controlSurfaceKey(Key? key) {
  if (key is ValueKey<Object?>) {
    return ValueKey('${key.value}-surface');
  }
  return null;
}

class _SacaInteractiveSurface extends StatefulWidget {
  const _SacaInteractiveSurface({
    required this.child,
    required this.enabled,
    required this.selected,
    required this.baseGradient,
    required this.selectedGradient,
    required this.baseBorderColor,
    required this.selectedBorderColor,
    this.autofocus = false,
    this.focusNode,
    this.surfaceKey,
    this.baseShadow = const [
      BoxShadow(
        color: Color(0x12000000),
        blurRadius: 16,
        offset: Offset(0, 6),
      ),
    ],
    this.hoverShadow = const [
      BoxShadow(
        color: Color(0x17000000),
        blurRadius: 22,
        offset: Offset(0, 10),
      ),
    ],
    this.pressedShadow = const [
      BoxShadow(
        color: Color(0x10000000),
        blurRadius: 10,
        offset: Offset(0, 4),
      ),
    ],
  });

  final Key? surfaceKey;
  final Widget child;
  final bool enabled;
  final bool selected;
  final LinearGradient baseGradient;
  final LinearGradient selectedGradient;
  final Color baseBorderColor;
  final Color selectedBorderColor;
  final bool autofocus;
  final FocusNode? focusNode;
  final List<BoxShadow> baseShadow;
  final List<BoxShadow> hoverShadow;
  final List<BoxShadow> pressedShadow;

  @override
  State<_SacaInteractiveSurface> createState() =>
      _SacaInteractiveSurfaceState();
}

class _SacaInteractiveSurfaceState extends State<_SacaInteractiveSurface> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  void _setHovered(bool value) {
    if (!mounted || _hovered == value || !widget.enabled) {
      return;
    }
    setState(() => _hovered = value);
  }

  void _setFocused(bool value) {
    if (!mounted || _focused == value || !widget.enabled) {
      return;
    }
    setState(() => _focused = value);
  }

  void _setPressed(bool value) {
    if (!mounted || _pressed == value || !widget.enabled) {
      return;
    }
    setState(() => _pressed = value);
  }

  @override
  void dispose() {
    _hovered = false;
    _focused = false;
    _pressed = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseGradient =
        widget.selected ? widget.selectedGradient : widget.baseGradient;
    final baseBorder =
        widget.selected ? widget.selectedBorderColor : widget.baseBorderColor;
    final theme = SacaThemeContext.of(context);
    final themedGradient = theme.surfaceGradient(selected: widget.selected);
    final effectiveBaseGradient =
        theme.useGlassStyle || theme.useClassic ? themedGradient : baseGradient;
    final effectiveRadius = theme.radius(SacaTheme.radius);
    final hoverTint =
        widget.selected ? theme.colors.control : theme.colors.selectedBorder;
    final pressedTint =
        widget.selected ? theme.colors.onSurface : theme.colors.control;
    final glassFill = !widget.enabled && widget.selected
        ? theme.colors.disabledControl
        : widget.selected
            ? theme.glassMaterial(SacaGlassMaterial.control)
            : theme.glassMaterial(SacaGlassMaterial.field);
    final glassOpacity = theme.glassOpacity(
      widget.selected ? SacaGlassMaterial.control : SacaGlassMaterial.field,
    );

    final hovered = widget.enabled && _hovered;
    final focused = widget.enabled && _focused;
    final pressed = widget.enabled && _pressed;

    final brightenAmount = hovered ? 0.08 : 0.0;
    final darkenAmount = pressed ? 0.1 : 0.0;
    final borderStrength = pressed
        ? 0.34
        : hovered
            ? 0.2
            : 0.0;

    final boxShadow = pressed
        ? widget.pressedShadow
        : hovered
            ? widget.hoverShadow
            : widget.baseShadow;
    final effectiveShadow = theme.useGlassStyle || theme.useClassic
        ? theme.surfaceShadow(highlighted: widget.selected)
        : boxShadow;
    final effectiveDuration = Duration(
      milliseconds: pressed ? 90 : 150,
    );
    final decoratedChild = AnimatedContainer(
      key: widget.surfaceKey,
      duration: effectiveDuration,
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: _tintGradient(
          effectiveBaseGradient,
          brightenTint: hoverTint,
          brightenAmount: brightenAmount,
          darkenTint: pressedTint,
          darkenAmount: darkenAmount,
        ),
        color: theme.useGlassStyle
            ? glassFill.withValues(alpha: glassOpacity)
            : null,
        borderRadius: BorderRadius.circular(effectiveRadius),
        border: Border.all(
          color: theme.useGlassStyle
              ? theme.colors.glassBorder.withValues(alpha: theme.borderOpacity)
              : _mixBorder(
                  baseColor: baseBorder,
                  hoverTint: hoverTint,
                  pressedTint: pressedTint,
                  hoverAmount: hovered ? borderStrength : 0,
                  pressedAmount: pressed ? borderStrength : 0,
                ),
        ),
        boxShadow: [
          ...effectiveShadow,
          if (focused)
            const BoxShadow(
              color: Color(0x335FADC8),
              blurRadius: 0,
              spreadRadius: 2,
            ),
        ],
      ),
      child: AnimatedOpacity(
        duration: effectiveDuration,
        opacity: widget.enabled ? 1 : (theme.useGlassStyle ? 0.86 : 0.58),
        child: AnimatedContainer(
          duration: effectiveDuration,
          curve: Curves.easeOutCubic,
          transformAlignment: Alignment.center,
          transform: Matrix4.translationValues(
            0,
            pressed
                ? 0
                : hovered
                    ? -2
                    : 0,
            0,
          )..scaleByDouble(
              pressed ? 0.97 : 1.0,
              pressed ? 0.97 : 1.0,
              1,
              1,
            ),
          child: widget.child,
        ),
      ),
    );
    final surface = theme.useGlass
        ? GlassContainer(
            padding: EdgeInsets.zero,
            quality: GlassQuality.standard,
            child: decoratedChild,
          )
        : decoratedChild;

    return FocusableActionDetector(
      enabled: widget.enabled,
      mouseCursor:
          widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      shortcuts: const <ShortcutActivator, Intent>{},
      onShowHoverHighlight: _setHovered,
      onShowFocusHighlight: _setFocused,
      child: MouseRegion(
        cursor: widget.enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => _setHovered(true),
        onExit: (_) {
          _setHovered(false);
          _setPressed(false);
        },
        child: Focus(
          canRequestFocus: widget.enabled,
          autofocus: widget.autofocus,
          focusNode: widget.focusNode,
          onFocusChange: _setFocused,
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => _setPressed(true),
            onPointerUp: (_) => _setPressed(false),
            onPointerCancel: (_) => _setPressed(false),
            child: surface,
          ),
        ),
      ),
    );
  }
}

class _SacaInteractionMotion extends StatefulWidget {
  const _SacaInteractionMotion({
    required this.child,
    required this.enabled,
    required this.borderRadius,
    required this.hoverColor,
    required this.pressedColor,
  });

  final Widget child;
  final bool enabled;
  final BorderRadius borderRadius;
  final Color hoverColor;
  final Color pressedColor;

  @override
  State<_SacaInteractionMotion> createState() => _SacaInteractionMotionState();
}

class _SacaInteractionMotionState extends State<_SacaInteractionMotion> {
  bool _hovered = false;
  bool _pressed = false;

  void _setHovered(bool value) {
    if (!widget.enabled || _hovered == value) return;
    setState(() => _hovered = value);
  }

  void _setPressed(bool value) {
    if (!widget.enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final hovered = widget.enabled && _hovered;
    final pressed = widget.enabled && _pressed;
    final duration = Duration(milliseconds: pressed ? 90 : 150);
    return MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => _setHovered(true),
      onExit: (_) {
        _setHovered(false);
        _setPressed(false);
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _setPressed(true),
        onPointerUp: (_) => _setPressed(false),
        onPointerCancel: (_) => _setPressed(false),
        child: AnimatedContainer(
          duration: duration,
          curve: Curves.easeOutCubic,
          transformAlignment: Alignment.center,
          transform: Matrix4.identity()
            ..scaleByDouble(
              pressed ? 0.97 : 1.0,
              pressed ? 0.97 : 1.0,
              1,
              1,
            ),
          decoration: BoxDecoration(
            color: pressed
                ? widget.pressedColor
                : hovered
                    ? widget.hoverColor
                    : CupertinoColors.transparent,
            borderRadius: widget.borderRadius,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

LinearGradient _tintGradient(
  LinearGradient gradient, {
  required Color brightenTint,
  required double brightenAmount,
  required Color darkenTint,
  required double darkenAmount,
}) {
  return LinearGradient(
    begin: gradient.begin,
    end: gradient.end,
    stops: gradient.stops,
    tileMode: gradient.tileMode,
    transform: gradient.transform,
    colors: gradient.colors
        .map(
          (color) => Color.lerp(
            Color.lerp(color, brightenTint, brightenAmount),
            darkenTint,
            darkenAmount,
          )!,
        )
        .toList(growable: false),
  );
}

Color _mixBorder({
  required Color baseColor,
  required Color hoverTint,
  required Color pressedTint,
  required double hoverAmount,
  required double pressedAmount,
}) {
  return Color.lerp(
    Color.lerp(baseColor, hoverTint, hoverAmount),
    pressedTint,
    pressedAmount,
  )!;
}
