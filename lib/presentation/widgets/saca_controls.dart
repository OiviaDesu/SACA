import 'package:flutter/cupertino.dart';

import '../../core/theme/saca_theme.dart';

class SacaPrimaryButton extends StatelessWidget {
  const SacaPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.filled = false,
    this.autofocus = false,
    this.focusNode,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool filled;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final foreground = filled ? SacaTheme.surface : SacaTheme.text;

    return CupertinoButton(
      minimumSize: const Size(0, SacaTheme.minTapTarget),
      padding: EdgeInsets.zero,
      pressedOpacity: 1,
      onPressed: onPressed,
      child: _SacaInteractiveSurface(
        surfaceKey: _controlSurfaceKey(key),
        enabled: enabled,
        selected: filled,
        baseGradient: SacaTheme.surfaceGradient,
        selectedGradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            SacaTheme.accent,
            SacaTheme.selectedBorder,
          ],
        ),
        baseBorderColor: SacaTheme.border,
        selectedBorderColor: SacaTheme.accent,
        autofocus: autofocus,
        focusNode: focusNode,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: SacaTheme.minTapTarget,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 22, color: foreground),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: SacaTheme.body.copyWith(color: foreground),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SacaOptionButton extends StatelessWidget {
  const SacaOptionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.description,
    this.icon,
    this.selected = false,
    this.autofocus = false,
    this.focusNode,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? description;
  final IconData? icon;
  final bool selected;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      minimumSize: const Size(0, SacaTheme.minTapTarget),
      padding: EdgeInsets.zero,
      pressedOpacity: 1,
      onPressed: onPressed,
      child: _SacaInteractiveSurface(
        surfaceKey: _controlSurfaceKey(key),
        enabled: onPressed != null,
        selected: selected,
        baseGradient: SacaTheme.surfaceGradient,
        selectedGradient: SacaTheme.selectedGradient,
        baseBorderColor: SacaTheme.border,
        selectedBorderColor: SacaTheme.selectedBorder,
        autofocus: autofocus,
        focusNode: focusNode,
        child: SizedBox(
          width: double.infinity,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: SacaTheme.minTapTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: SacaTheme.body,
                          overflow: TextOverflow.visible,
                        ),
                        if (description != null) ...[
                          const SizedBox(height: 5),
                          Text(
                            description!,
                            style: SacaTheme.small,
                            overflow: TextOverflow.visible,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (icon != null) Icon(icon, size: 24, color: SacaTheme.text),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SacaChipButton extends StatelessWidget {
  const SacaChipButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.autofocus = false,
    this.focusNode,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      minimumSize: const Size(0, 42),
      padding: EdgeInsets.zero,
      pressedOpacity: 1,
      onPressed: onPressed,
      child: _SacaInteractiveSurface(
        surfaceKey: _controlSurfaceKey(key),
        enabled: true,
        selected: selected,
        baseGradient: SacaTheme.surfaceGradient,
        selectedGradient: SacaTheme.selectedGradient,
        baseBorderColor: SacaTheme.border,
        selectedBorderColor: SacaTheme.selectedBorder,
        autofocus: autofocus,
        focusNode: focusNode,
        baseShadow: const [],
        hoverShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
        pressedShadow: const [],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 22),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.visible,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
                color: SacaTheme.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
    if (_hovered == value || !widget.enabled) {
      return;
    }
    setState(() => _hovered = value);
  }

  void _setFocused(bool value) {
    if (_focused == value || !widget.enabled) {
      return;
    }
    setState(() => _focused = value);
  }

  void _setPressed(bool value) {
    if (_pressed == value || !widget.enabled) {
      return;
    }
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final baseGradient =
        widget.selected ? widget.selectedGradient : widget.baseGradient;
    final baseBorder =
        widget.selected ? widget.selectedBorderColor : widget.baseBorderColor;
    final hoverTint =
        widget.selected ? SacaTheme.accent : SacaTheme.selectedBorder;
    final pressedTint = widget.selected ? SacaTheme.text : SacaTheme.accent;

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
    final effectiveDuration = Duration(
      milliseconds: pressed ? 90 : 150,
    );

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
            child: AnimatedContainer(
              key: widget.surfaceKey,
              duration: effectiveDuration,
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                gradient: _tintGradient(
                  baseGradient,
                  brightenTint: hoverTint,
                  brightenAmount: brightenAmount,
                  darkenTint: pressedTint,
                  darkenAmount: darkenAmount,
                ),
                borderRadius: BorderRadius.circular(SacaTheme.radius),
                border: Border.all(
                  color: _mixBorder(
                    baseColor: baseBorder,
                    hoverTint: hoverTint,
                    pressedTint: pressedTint,
                    hoverAmount: hovered ? borderStrength : 0,
                    pressedAmount: pressed ? borderStrength : 0,
                  ),
                ),
                boxShadow: [
                  ...boxShadow,
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
                opacity: widget.enabled ? 1 : 0.44,
                child: AnimatedContainer(
                  duration: effectiveDuration,
                  curve: Curves.easeOutCubic,
                  transform: Matrix4.translationValues(
                    0,
                    pressed
                        ? 0
                        : hovered
                            ? -2
                            : 0,
                    0,
                  ),
                  child: widget.child,
                ),
              ),
            ),
          ),
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

class SacaSeveritySlider extends StatelessWidget {
  const SacaSeveritySlider({
    super.key,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
    this.minLabel = '1',
    this.maxLabel = '10',
  });

  final int value;
  final ValueChanged<int> onChanged;
  final String semanticLabel;
  final String minLabel;
  final String maxLabel;

  @override
  Widget build(BuildContext context) {
    final clampedValue = value.clamp(1, 10);
    const labelWidth = 74.0;
    const sliderHorizontalPadding = 28.0;

    return Semantics(
      label: semanticLabel,
      value: '$clampedValue',
      increasedValue: '${(clampedValue + 1).clamp(1, 10)}',
      decreasedValue: '${(clampedValue - 1).clamp(1, 10)}',
      child: KeyedSubtree(
        key: const ValueKey('severitySliderInlineControl'),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            final trackWidth =
                (availableWidth - sliderHorizontalPadding * 2).clamp(
              1.0,
              double.infinity,
            );
            final progress = (clampedValue - 1) / 9;
            final thumbCenter = sliderHorizontalPadding + trackWidth * progress;
            final labelLeft = (thumbCenter - labelWidth / 2).clamp(
              0.0,
              (availableWidth - labelWidth).clamp(0.0, double.infinity),
            );

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 116,
                    child: Stack(
                      children: [
                        Positioned(
                          left: labelLeft,
                          top: 0,
                          width: labelWidth,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 140),
                            child: Text(
                              '$clampedValue',
                              key: ValueKey<String>(
                                'severityValue-$clampedValue',
                              ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 52,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                                height: 1,
                                color: SacaTheme.text,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: sliderHorizontalPadding,
                          right: sliderHorizontalPadding,
                          top: 82,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xFFE7F2F6),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const SizedBox(height: 10),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 58,
                          child: SizedBox(
                            height: 58,
                            child: CupertinoSlider(
                              key: const ValueKey('severitySlider'),
                              value: clampedValue.toDouble(),
                              min: 1,
                              max: 10,
                              divisions: 9,
                              activeColor: SacaTheme.selectedBorder,
                              thumbColor: SacaTheme.text,
                              onChanged: (nextValue) =>
                                  onChanged(nextValue.round()),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: sliderHorizontalPadding,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(minLabel, style: SacaTheme.small),
                        Text(maxLabel, style: SacaTheme.small),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class SacaErrorBanner extends StatelessWidget {
  const SacaErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFE7E4),
        borderRadius: BorderRadius.circular(SacaTheme.radius),
        border: Border.all(color: const Color(0xFFE9A09A)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: SacaTheme.small.copyWith(color: SacaTheme.emergency),
        ),
      ),
    );
  }
}
