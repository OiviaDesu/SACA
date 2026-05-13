part of '../saca_flow_screen.dart';

class _DesktopShell extends StatelessWidget {
  const _DesktopShell({
    required this.state,
    required this.localizer,
    required this.readiness,
    required this.child,
    required this.onInfo,
    required this.onSettings,
    this.onBack,
  });

  final SacaFlowState state;
  final SacaLocalizer localizer;
  final SacaReadinessState readiness;
  final Widget child;
  final VoidCallback? onBack;
  final VoidCallback onInfo;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final colors = SacaThemeColors.of(context);
    final theme = SacaThemeContext.of(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          onBack?.call();
        },
      },
      child: FocusTraversalGroup(
        child: DecoratedBox(
          key: const ValueKey('windowsFramelessShell'),
          decoration: BoxDecoration(
            color: theme.useGlassStyle
                ? theme.glassMaterial(SacaGlassMaterial.panel)
                : colors.background,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                key: const ValueKey('windowsRoundedShellClip'),
                borderRadius: BorderRadius.circular(18),
                child: Column(
                  children: [
                    _DesktopToolbar(
                      state: state,
                      localizer: localizer,
                      readiness: readiness,
                      onBack: onBack,
                      onInfo: onInfo,
                      onSettings: onSettings,
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final maxContentWidth =
                              (constraints.maxWidth - 72).clamp(760.0, 1480.0);
                          return SingleChildScrollView(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight,
                              ),
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(36, 30, 36, 40),
                                child: Center(
                                  child: ConstrainedBox(
                                    key: const ValueKey('windowsContentColumn'),
                                    constraints: BoxConstraints(
                                      maxWidth: maxContentWidth,
                                    ),
                                    child: child,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const _DesktopResizeOverlay(),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopResizeOverlay extends StatelessWidget {
  const _DesktopResizeOverlay();

  static const double _edge = 8;
  static const double _corner = 18;

  @override
  Widget build(BuildContext context) {
    return const Stack(
      key: ValueKey('windowsResizeOverlay'),
      fit: StackFit.expand,
      children: [
        Positioned(
          top: 0,
          left: _corner,
          right: _corner,
          height: _edge,
          child: _DesktopResizeZone(
            edge: DesktopResizeEdge.top,
            cursor: SystemMouseCursors.resizeUpDown,
          ),
        ),
        Positioned(
          right: 0,
          top: _corner,
          bottom: _corner,
          width: _edge,
          child: _DesktopResizeZone(
            edge: DesktopResizeEdge.right,
            cursor: SystemMouseCursors.resizeLeftRight,
          ),
        ),
        Positioned(
          bottom: 0,
          left: _corner,
          right: _corner,
          height: _edge,
          child: _DesktopResizeZone(
            edge: DesktopResizeEdge.bottom,
            cursor: SystemMouseCursors.resizeUpDown,
          ),
        ),
        Positioned(
          left: 0,
          top: _corner,
          bottom: _corner,
          width: _edge,
          child: _DesktopResizeZone(
            edge: DesktopResizeEdge.left,
            cursor: SystemMouseCursors.resizeLeftRight,
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          width: _corner,
          height: _corner,
          child: _DesktopResizeZone(
            edge: DesktopResizeEdge.topLeft,
            cursor: SystemMouseCursors.resizeUpLeftDownRight,
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          width: _corner,
          height: _corner,
          child: _DesktopResizeZone(
            edge: DesktopResizeEdge.topRight,
            cursor: SystemMouseCursors.resizeUpRightDownLeft,
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          width: _corner,
          height: _corner,
          child: _DesktopResizeZone(
            edge: DesktopResizeEdge.bottomRight,
            cursor: SystemMouseCursors.resizeUpLeftDownRight,
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          width: _corner,
          height: _corner,
          child: _DesktopResizeZone(
            edge: DesktopResizeEdge.bottomLeft,
            cursor: SystemMouseCursors.resizeUpRightDownLeft,
          ),
        ),
      ],
    );
  }
}

class _DesktopResizeZone extends StatelessWidget {
  const _DesktopResizeZone({
    required this.edge,
    required this.cursor,
  });

  final DesktopResizeEdge edge;
  final MouseCursor cursor;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: cursor,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => resizeDesktopWindow(edge),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _DesktopToolbar extends StatelessWidget {
  const _DesktopToolbar({
    required this.state,
    required this.localizer,
    required this.readiness,
    required this.onInfo,
    required this.onSettings,
    this.onBack,
  });

  final SacaFlowState state;
  final SacaLocalizer localizer;
  final SacaReadinessState readiness;
  final VoidCallback? onBack;
  final VoidCallback onInfo;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final colors = SacaThemeColors.of(context);
    final theme = SacaThemeContext.of(context);
    final language = switch (state.language) {
      SacaLanguage.gurindji => 'Gurindji',
      SacaLanguage.english => 'English',
      null => localizer.t(null, 'notSelected'),
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        return DecoratedBox(
          key: const ValueKey('windowsCustomTitleBar'),
          decoration: BoxDecoration(
            color: theme.useGlassStyle
                ? theme.glassMaterial(SacaGlassMaterial.nav).withValues(
                    alpha: theme.glassOpacity(SacaGlassMaterial.nav))
                : colors.surfaceAlt,
            border: Border(
              bottom: BorderSide(
                color: theme.useGlassStyle
                    ? colors.glassBorder.withValues(alpha: theme.borderOpacity)
                    : colors.border,
              ),
            ),
          ),
          child: SizedBox(
            height: 64,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 18),
              child: Row(
                children: [
                  SacaIconButton(
                    semanticLabel: localizer.t(state.language, 'back'),
                    icon: CupertinoIcons.chevron_left,
                    onPressed: onBack,
                  ),
                  SizedBox(width: compact ? 4 : 8),
                  Expanded(
                    child: DesktopDragArea(
                      child: SizedBox(
                        key: const ValueKey('windowsDragRegion'),
                        height: double.infinity,
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                'SACA',
                                overflow: TextOverflow.ellipsis,
                                style: SacaTheme.logoText.copyWith(
                                  fontSize: compact ? 24 : 28,
                                  color: colors.onSurface,
                                ),
                              ),
                            ),
                            if (!compact) ...[
                              const SizedBox(width: 14),
                              _StatusPill(
                                label: readiness.isReady
                                    ? localizer.t(
                                        state.language, 'offlineReady')
                                    : localizer.t(
                                        state.language,
                                        'offlineNotReady',
                                      ),
                                isReady: readiness.isReady,
                                onPressed: () => _showReadinessDialog(
                                  context,
                                  readiness,
                                  localizer,
                                  state.language,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  '${localizer.t(state.language, 'languageStatus')}: '
                                  '$language',
                                  textAlign: TextAlign.right,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: SacaTheme.small
                                      .copyWith(color: colors.onSurfaceMuted),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: compact ? 4 : 12),
                  if (!compact)
                    SacaIconButton(
                      semanticLabel: localizer.t(state.language, 'infoLabel'),
                      icon: CupertinoIcons.info,
                      onPressed: onInfo,
                    ),
                  SacaIconButton(
                    semanticLabel: localizer.t(state.language, 'settingsLabel'),
                    icon: CupertinoIcons.gear_alt,
                    selected: state.step == SacaStep.settings,
                    onPressed: onSettings,
                  ),
                  const _DesktopWindowControls(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

void _showReadinessDialog(
  BuildContext context,
  SacaReadinessState readiness,
  SacaLocalizer localizer,
  SacaLanguage? language,
) {
  showCupertinoDialog<void>(
    context: context,
    builder: (dialogContext) {
      return _SacaMessageDialog(
        title: readiness.isReady
            ? localizer.t(language, 'offlineReady')
            : localizer.t(language, 'offlineNotReady'),
        message: readiness.messages.join('\n'),
        actionLabel: localizer.t(language, 'ok'),
        onAction: () => Navigator.of(dialogContext).pop(),
      );
    },
  );
}

class _DesktopWindowControls extends StatelessWidget {
  const _DesktopWindowControls();

  @override
  Widget build(BuildContext context) {
    return const Row(
      key: ValueKey('windowsWindowControls'),
      children: [
        _DesktopWindowButton(
          icon: CupertinoIcons.minus,
          semanticLabel: 'Minimize window',
          onPressed: minimizeDesktopWindow,
        ),
        _DesktopWindowButton(
          icon: CupertinoIcons.square_on_square,
          semanticLabel: 'Maximize window',
          onPressed: toggleMaximizeDesktopWindow,
        ),
        _DesktopWindowButton(
          icon: CupertinoIcons.xmark,
          semanticLabel: 'Close window',
          destructive: true,
          onPressed: closeDesktopWindow,
        ),
      ],
    );
  }
}

class _DesktopWindowButton extends StatelessWidget {
  const _DesktopWindowButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.destructive = false,
  });

  final IconData icon;
  final String semanticLabel;
  final Future<void> Function() onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return SacaIconButton(
      semanticLabel: semanticLabel,
      icon: icon,
      destructive: destructive,
      minimumSize: const Size(46, 44),
      onPressed: onPressed,
    );
  }
}
