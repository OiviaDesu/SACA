part of '../saca_flow_screen.dart';

class _ShellBackdrop extends StatelessWidget {
  const _ShellBackdrop();

  @override
  Widget build(BuildContext context) {
    final colors = SacaThemeColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(gradient: colors.shellGradient),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              height: 220,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x26A9D5E7),
                    Color(0x00A9D5E7),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 180,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x00F3D7CF),
                    Color(0x2AF3D7CF),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepLayout extends StatelessWidget {
  const _StepLayout({
    required this.style,
    required this.state,
    required this.localizer,
    required this.children,
    this.onBack,
    this.onInfo,
    this.onSettings,
    this.showBack = true,
  });

  final SacaPlatformStyle style;
  final SacaFlowState state;
  final SacaLocalizer localizer;
  final List<Widget> children;
  final VoidCallback? onBack;
  final VoidCallback? onInfo;
  final VoidCallback? onSettings;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.errorMessage != null) ...[
          const SizedBox(height: 8),
          SacaErrorBanner(
            message:
                localizer.errorMessage(state.language, state.errorMessage!),
          ),
          const SizedBox(height: 12),
        ],
        ...children,
      ],
    );
  }
}

class _MobileTopBar extends StatelessWidget {
  const _MobileTopBar({
    required this.state,
    required this.localizer,
    required this.canBack,
    this.onBack,
    this.onInfo,
    this.onSettings,
  });

  final SacaFlowState state;
  final SacaLocalizer localizer;
  final bool canBack;
  final VoidCallback? onBack;
  final VoidCallback? onInfo;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: canBack
                ? SacaIconButton(
                    semanticLabel: localizer.t(state.language, 'back'),
                    icon: CupertinoIcons.chevron_left,
                    onPressed: onBack,
                  )
                : const SizedBox.shrink(),
          ),
          const Spacer(),
          SacaIconButton(
            semanticLabel: localizer.t(state.language, 'infoLabel'),
            icon: CupertinoIcons.info,
            onPressed: onInfo,
          ),
          SacaIconButton(
            semanticLabel: localizer.t(state.language, 'settingsLabel'),
            icon: CupertinoIcons.gear_alt,
            onPressed: onSettings,
          ),
        ],
      ),
    );
  }
}

class _SplashStep extends StatelessWidget {
  const _SplashStep({required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 60),
        const SacaLogoHeader(),
        const SizedBox(height: 12),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: SacaTheme.body,
        ),
        const SizedBox(height: 60),
      ],
    );
  }
}

class _StepTitle extends StatelessWidget {
  const _StepTitle({
    required this.title,
    required this.subtitle,
    required this.align,
  });

  final String title;
  final String subtitle;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final colors = SacaThemeColors.of(context);
    return Column(
      crossAxisAlignment: align == TextAlign.left
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.stretch,
      children: [
        Text(title,
            textAlign: align,
            style: SacaTheme.title.copyWith(color: colors.text)),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: align,
          style: SacaTheme.body.copyWith(color: colors.mutedText),
        ),
      ],
    );
  }
}

class _Footnote extends StatelessWidget {
  const _Footnote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = SacaThemeColors.of(context);
    return Text(
      text,
      textAlign: TextAlign.center,
      style: SacaTheme.small.copyWith(color: colors.mutedText),
    );
  }
}

class _LanguageCarouselText extends StatefulWidget {
  const _LanguageCarouselText();

  @override
  State<_LanguageCarouselText> createState() => _LanguageCarouselTextState();
}

class _LanguageCarouselTextState extends State<_LanguageCarouselText>
    with SingleTickerProviderStateMixin {
  static const _messages = <String>[
    'Choose language',
    'Yawu nyawa',
  ];
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = SacaThemeColors.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final index = _controller.value < 0.5 ? 0 : 1;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            _messages[index],
            key: ValueKey<int>(index),
            textAlign: TextAlign.center,
            style: SacaTheme.body.copyWith(color: colors.mutedText),
          ),
        );
      },
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.isReady,
    required this.onPressed,
  });

  final String label;
  final bool isReady;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = SacaThemeColors.of(context);
    final borderColor = isReady
        ? colors.border.withValues(alpha: 0.72)
        : SacaTheme.emergency.withValues(alpha: 0.44);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onPressed,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isReady
              ? colors.selected.withValues(alpha: 0.72)
              : SacaTheme.emergency.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: borderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            label,
            style: SacaTheme.small.copyWith(
              color: isReady ? colors.text : SacaTheme.emergency,
            ),
          ),
        ),
      ),
    );
  }
}
