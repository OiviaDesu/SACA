part of '../saca_flow_screen.dart';

class _VoiceLoadingOverlay extends StatefulWidget {
  const _VoiceLoadingOverlay({
    required this.visible,
    required this.title,
    required this.subtitle,
  });

  final bool visible;
  final String? title;
  final String? subtitle;

  @override
  State<_VoiceLoadingOverlay> createState() => _VoiceLoadingOverlayState();
}

class _VoiceLoadingOverlayState extends State<_VoiceLoadingOverlay> {
  double _progress = 0;

  @override
  void didUpdateWidget(covariant _VoiceLoadingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) {
      _progress = 0.08;
      _tickProgress();
    }
    if (!widget.visible && oldWidget.visible) {
      _progress = 0;
    }
  }

  void _tickProgress() {
    Future<void>.delayed(const Duration(milliseconds: 180), () {
      if (!mounted || !widget.visible) return;
      setState(() {
        _progress = (_progress + (0.95 - _progress) * 0.16).clamp(0, 0.95);
      });
      if (_progress < 0.95) _tickProgress();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = SacaThemeColors.of(context);
    final theme = SacaThemeContext.of(context);
    return IgnorePointer(
      ignoring: !widget.visible,
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
        child: widget.visible
            ? Stack(
                key: const ValueKey('voiceLoadingOverlay'),
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.glassScrim.withValues(
                        alpha: theme.useGlassStyle ? 0.38 : 0.18,
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colors.glassHighlight.withValues(
                            alpha:
                                theme.useGlassStyle ? theme.glowOpacity : 0.16,
                          ),
                          colors.background.withValues(alpha: 0.62),
                          colors.onSurface.withValues(alpha: 0.20),
                        ],
                      ),
                    ),
                  ),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: theme.surfaceGradient(),
                          color: theme.useGlassStyle
                              ? theme
                                  .glassMaterial(SacaGlassMaterial.dialog)
                                  .withValues(
                                    alpha: theme
                                        .glassOpacity(SacaGlassMaterial.dialog),
                                  )
                              : null,
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                            color: theme.useGlassStyle
                                ? colors.glassBorder.withValues(
                                    alpha: theme.borderOpacity,
                                  )
                                : colors.selectedBorder,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colors.shadow,
                              blurRadius: 34,
                              offset: const Offset(0, 18),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: colors.selectedGradient,
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          colors.accent.withValues(alpha: 0.28),
                                      blurRadius: 18,
                                    ),
                                  ],
                                ),
                                child: const SizedBox(
                                  width: 54,
                                  height: 54,
                                  child: Center(
                                    child:
                                        CupertinoActivityIndicator(radius: 14),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: _progress,
                                  minHeight: 8,
                                  backgroundColor:
                                      colors.border.withValues(alpha: 0.45),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    colors.accent,
                                  ),
                                ),
                              ),
                              if (widget.title != null) ...[
                                const SizedBox(height: 14),
                                Text(
                                  widget.title!,
                                  key: const ValueKey('voiceLoadingTitle'),
                                  textAlign: TextAlign.center,
                                  style: SacaTheme.body.copyWith(
                                    color: colors.onSurface,
                                  ),
                                ),
                              ],
                              if (widget.subtitle != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  widget.subtitle!,
                                  key: const ValueKey('voiceLoadingSubtitle'),
                                  textAlign: TextAlign.center,
                                  style: SacaTheme.small.copyWith(
                                    color: colors.onSurfaceMuted,
                                  ),
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
