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
