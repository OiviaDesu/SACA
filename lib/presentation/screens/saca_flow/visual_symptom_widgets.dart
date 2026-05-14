part of '../saca_flow_screen.dart';

class _CompactSelectedSummary extends StatelessWidget {
  const _CompactSelectedSummary({
    required this.title,
    required this.emptyText,
    required this.values,
  });

  final String title;
  final String emptyText;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    final colors = SacaThemeColors.of(context);
    final text = values.isEmpty ? emptyText : values.join(', ');
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: colors.surfaceGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style: SacaTheme.small.copyWith(color: colors.onSurface)),
            const SizedBox(height: 3),
            Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SacaTheme.body.copyWith(color: colors.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisualSymptomCard extends StatelessWidget {
  const _VisualSymptomCard({
    required this.label,
    required this.imagePath,
    required this.selected,
    required this.onPressed,
    this.secondaryLabel,
  });

  final String label;
  final String? secondaryLabel;
  final String imagePath;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: secondaryLabel == null ? label : '$label, $secondaryLabel',
      child: SizedBox(
        width: double.infinity,
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(
            SacaTheme.minTapTarget,
            SacaTheme.minTapTarget,
          ),
          onPressed: onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            width: double.infinity,
            height: 210,
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              gradient: selected
                  ? SacaTheme.selectedGradient
                  : SacaTheme.surfaceGradient,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? SacaTheme.selectedBorder : SacaTheme.border,
                width: selected ? 2 : 1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Center(
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOutCubic,
                      scale: selected ? 1.04 : 1,
                      child: Image.asset(
                        imagePath,
                        width: 140,
                        height: 140,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            CupertinoIcons.photo,
                            size: 48,
                            color: SacaTheme.text,
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SacaTheme.body.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (secondaryLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    secondaryLabel!,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SacaTheme.small,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
