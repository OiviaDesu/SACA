import 'package:flutter/cupertino.dart';

import '../../core/theme/saca_theme.dart';

class SacaPrimaryButton extends StatelessWidget {
  const SacaPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.filled = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final background = filled ? SacaTheme.text : SacaTheme.surface;
    final foreground = filled ? SacaTheme.surface : SacaTheme.text;

    return CupertinoButton(
      minimumSize: const Size(0, SacaTheme.minTapTarget),
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Opacity(
        opacity: enabled ? 1 : 0.42,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(SacaTheme.radius),
            border: Border.all(color: SacaTheme.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
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
  });

  final String label;
  final VoidCallback? onPressed;
  final String? description;
  final IconData? icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      minimumSize: const Size(0, SacaTheme.minTapTarget),
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? SacaTheme.selected : SacaTheme.surface,
          borderRadius: BorderRadius.circular(SacaTheme.radius),
          border: Border.all(
            color: selected ? SacaTheme.selectedBorder : SacaTheme.border,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
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
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      minimumSize: const Size(0, 42),
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? SacaTheme.selected : SacaTheme.surface,
          borderRadius: BorderRadius.circular(SacaTheme.radius),
          border: Border.all(
            color: selected ? SacaTheme.selectedBorder : SacaTheme.border,
          ),
        ),
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
