part of '../saca_controls.dart';

class SacaSeveritySlider extends StatelessWidget {
  const SacaSeveritySlider({
    super.key,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
    required this.descriptor,
    this.minLabel = '1',
    this.maxLabel = '10',
  });

  final int value;
  final ValueChanged<int> onChanged;
  final String semanticLabel;
  final String descriptor;
  final String minLabel;
  final String maxLabel;

  @override
  Widget build(BuildContext context) {
    final clampedValue = value.clamp(1, 10);
    final colors = SacaThemeColors.of(context);
    final theme = SacaThemeContext.of(context);
    final color = _colorFor(clampedValue);
    const sliderHorizontalPadding = 28.0;
    if (theme.useClassic) {
      return Semantics(
        label: semanticLabel,
        value: '$clampedValue',
        increasedValue: '${(clampedValue + 1).clamp(1, 10)}',
        decreasedValue: '${(clampedValue - 1).clamp(1, 10)}',
        child: Material(
          color: Colors.transparent,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceAlt,
              borderRadius:
                  BorderRadius.circular(theme.radius(SacaTheme.radius)),
              border: Border.all(color: colors.border),
              boxShadow: theme.surfaceShadow(),
            ),
            child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '$clampedValue',
                  key: ValueKey<String>('severityValue-$clampedValue'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 46,
                    fontWeight: FontWeight.w800,
                    color: colors.text,
                  ),
                ),
                Text(
                  descriptor,
                  key: ValueKey<String>('severityDescriptor-$descriptor'),
                  textAlign: TextAlign.center,
                  style: SacaTheme.body.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: color,
                    thumbColor: color,
                    inactiveTrackColor: colors.border,
                  ),
                  child: Slider(
                    key: const ValueKey('severityMaterialSlider'),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    value: clampedValue.toDouble(),
                    onChanged: (value) => onChanged(value.round()),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(minLabel,
                        style: SacaTheme.small.copyWith(color: colors.mutedText)),
                    Text(maxLabel,
                        style: SacaTheme.small.copyWith(color: colors.mutedText)),
                  ],
                ),
              ],
            ),
          ),
        ),
        ),
      );
    }

    return Semantics(
      label: semanticLabel,
      value: '$clampedValue',
      increasedValue: '${(clampedValue + 1).clamp(1, 10)}',
      decreasedValue: '${(clampedValue - 1).clamp(1, 10)}',
      child: KeyedSubtree(
        key: const ValueKey('severitySliderInlineControl'),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: colors.surfaceGradient,
                  borderRadius: BorderRadius.circular(SacaTheme.radius + 12),
                  border: Border.all(color: colors.border),
                  boxShadow: [
                    BoxShadow(
                      color: colors.shadow,
                      blurRadius: 24,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 142,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              top: 0,
                              bottom: 88,
                              child: Center(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 140),
                                  child: Text(
                                    '$clampedValue',
                                    key: ValueKey<String>(
                                      'severityValue-$clampedValue',
                                    ),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 52,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0,
                                      height: 1,
                                      color: colors.text,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              top: 58,
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 160),
                                style: SacaTheme.body.copyWith(
                                  color: color,
                                  fontWeight: FontWeight.w800,
                                ),
                                child: Text(
                                  descriptor,
                                  key: ValueKey<String>(
                                    'severityDescriptor-$descriptor',
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            Positioned(
                              left: sliderHorizontalPadding,
                              right: sliderHorizontalPadding,
                              top: 108,
                              child: DecoratedBox(
                                key: const ValueKey('severityGradientTrack'),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      SacaTheme.safe,
                                      SacaTheme.warning,
                                      Color(0xFFFF8A3D),
                                      SacaTheme.emergency,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const SizedBox(height: 8),
                              ),
                            ),
                            Positioned(
                              left: sliderHorizontalPadding,
                              right: sliderHorizontalPadding,
                              top: 82,
                              height: 58,
                              child: _SeverityDragTrack(
                                value: clampedValue,
                                color: color,
                                onChanged: onChanged,
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
                            Text(
                              minLabel,
                              style: SacaTheme.small.copyWith(
                                color: colors.mutedText,
                              ),
                            ),
                            Text(
                              maxLabel,
                              style: SacaTheme.small.copyWith(
                                color: colors.mutedText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Color _colorFor(int value) {
    if (value <= 3) return SacaTheme.safe;
    if (value <= 6) return SacaTheme.warning;
    if (value <= 8) return const Color(0xFFFF8A3D);
    return SacaTheme.emergency;
  }
}

class _SeverityDragTrack extends StatelessWidget {
  const _SeverityDragTrack({
    required this.value,
    required this.color,
    required this.onChanged,
  });

  final int value;
  final Color color;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = SacaThemeColors.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final progress = (value - 1) / 9;
        final thumbX = constraints.maxWidth * progress;

        return GestureDetector(
          key: const ValueKey('severitySlider'),
          behavior: HitTestBehavior.translucent,
          onTapDown: (details) =>
              _updateValue(details.localPosition.dx, constraints.maxWidth),
          onHorizontalDragUpdate: (details) =>
              _updateValue(details.localPosition.dx, constraints.maxWidth),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: thumbX - 14,
                top: 15,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOutCubic,
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: colors.text,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: color.withValues(alpha: 0.18)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _updateValue(double dx, double width) {
    final next = ((dx / width).clamp(0.0, 1.0) * 9).round() + 1;
    if (next != value) {
      unawaited(SacaHaptics.selection());
    }
    onChanged(next);
  }
}
