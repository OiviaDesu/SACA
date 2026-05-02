part of '../saca_controls.dart';

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
    final color = _colorFor(clampedValue);
    final descriptor = _descriptorFor(clampedValue);
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
                    height: 142,
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
                                  'severityDescriptor-$descriptor'),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        Positioned(
                          left: sliderHorizontalPadding,
                          right: sliderHorizontalPadding,
                          top: 108,
                          child: DecoratedBox(
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
                            child: const SizedBox(height: 10),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 84,
                          child: SizedBox(
                            height: 58,
                            child: CupertinoSlider(
                              key: const ValueKey('severitySlider'),
                              value: clampedValue.toDouble(),
                              min: 1,
                              max: 10,
                              divisions: 9,
                              activeColor: color,
                              thumbColor: SacaTheme.text,
                              onChanged: (nextValue) {
                                final next = nextValue.round();
                                if (next != clampedValue) {
                                  HapticFeedback.selectionClick();
                                }
                                onChanged(next);
                              },
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

  Color _colorFor(int value) {
    if (value <= 3) return SacaTheme.safe;
    if (value <= 6) return SacaTheme.warning;
    if (value <= 8) return const Color(0xFFFF8A3D);
    return SacaTheme.emergency;
  }

  String _descriptorFor(int value) {
    if (value <= 3) return 'Low pain';
    if (value <= 6) return 'Moderate pain';
    if (value <= 8) return 'High pain';
    return 'Emergency level';
  }
}
