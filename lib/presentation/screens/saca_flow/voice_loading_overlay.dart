part of '../saca_flow_screen.dart';

class _VoiceLoadingOverlay extends StatelessWidget {
  const _VoiceLoadingOverlay({
    required this.visible,
    required this.title,
    required this.subtitle,
  });

  final bool visible;
  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          final scale = Tween<double>(begin: 0.97, end: 1).animate(curved);
          final slide = Tween<Offset>(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(curved);
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: slide,
              child: ScaleTransition(scale: scale, child: child),
            ),
          );
        },
        child: visible
            ? Stack(
                key: const ValueKey('voiceLoadingOverlay'),
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: Color(0x22000000)),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 280),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: SacaTheme.surfaceGradient,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: SacaTheme.selectedBorder),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x18000000),
                              blurRadius: 24,
                              offset: Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CupertinoActivityIndicator(radius: 14),
                              if (title != null) ...[
                                const SizedBox(height: 14),
                                Text(
                                  title!,
                                  key: const ValueKey('voiceLoadingTitle'),
                                  textAlign: TextAlign.center,
                                  style: SacaTheme.body.copyWith(
                                    color: SacaTheme.text,
                                  ),
                                ),
                              ],
                              if (subtitle != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  subtitle!,
                                  key: const ValueKey('voiceLoadingSubtitle'),
                                  textAlign: TextAlign.center,
                                  style: SacaTheme.small,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
