part of '../saca_controls.dart';

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
