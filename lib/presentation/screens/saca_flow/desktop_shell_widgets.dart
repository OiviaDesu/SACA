part of '../saca_flow_screen.dart';

class _DesktopShell extends StatelessWidget {
  const _DesktopShell({
    required this.state,
    required this.localizer,
    required this.child,
    required this.onInfo,
    this.onBack,
  });

  final SacaFlowState state;
  final SacaLocalizer localizer;
  final Widget child;
  final VoidCallback? onBack;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          onBack?.call();
        },
      },
      child: FocusTraversalGroup(
        child: DecoratedBox(
          key: const ValueKey('windowsFramelessShell'),
          decoration: const BoxDecoration(color: SacaTheme.background),
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
                      onBack: onBack,
                      onInfo: onInfo,
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(36, 30, 36, 40),
                          child: Center(
                            child: ConstrainedBox(
                              key: const ValueKey('windowsContentColumn'),
                              constraints: const BoxConstraints(maxWidth: 760),
                              child: child,
                            ),
                          ),
                        ),
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
    required this.onInfo,
    this.onBack,
  });

  final SacaFlowState state;
  final SacaLocalizer localizer;
  final VoidCallback? onBack;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    final language = switch (state.language) {
      SacaLanguage.gurindji => 'Gurindji',
      SacaLanguage.english => 'English',
      null => localizer.t(null, 'notSelected'),
    };

    return DecoratedBox(
      key: const ValueKey('windowsCustomTitleBar'),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFAF9),
        border: Border(bottom: BorderSide(color: Color(0xFFE8DEDC))),
      ),
      child: SizedBox(
        height: 64,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size.square(44),
                onPressed: onBack,
                child: Icon(
                  CupertinoIcons.chevron_left,
                  color: onBack == null ? SacaTheme.border : SacaTheme.text,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DesktopDragArea(
                  child: SizedBox(
                    key: const ValueKey('windowsDragRegion'),
                    height: double.infinity,
                    child: Row(
                      children: [
                        Text(
                          'SACA',
                          style: SacaTheme.logoText.copyWith(fontSize: 28),
                        ),
                        const SizedBox(width: 14),
                        _StatusPill(
                          label: localizer.t(state.language, 'offlineReady'),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            '${localizer.t(state.language, 'languageStatus')}: '
                            '$language',
                            textAlign: TextAlign.right,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: SacaTheme.small,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size.square(44),
                onPressed: onInfo,
                child: const Icon(
                  CupertinoIcons.info,
                  color: SacaTheme.text,
                  size: 22,
                ),
              ),
              const _DesktopWindowControls(),
            ],
          ),
        ),
      ),
    );
  }
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
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(46, 44),
      onPressed: onPressed,
      child: Semantics(
        label: semanticLabel,
        button: true,
        child: Icon(
          icon,
          color: destructive ? SacaTheme.emergency : SacaTheme.text,
          size: 18,
        ),
      ),
    );
  }
}
