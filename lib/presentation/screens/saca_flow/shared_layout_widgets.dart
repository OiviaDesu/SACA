part of '../saca_flow_screen.dart';

class _ShellBackdrop extends StatelessWidget {
  const _ShellBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: SacaTheme.shellGradient),
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
    this.showBack = true,
  });

  final SacaPlatformStyle style;
  final SacaFlowState state;
  final SacaLocalizer localizer;
  final List<Widget> children;
  final VoidCallback? onBack;
  final VoidCallback? onInfo;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (style == SacaPlatformStyle.androidMobile)
          _MobileTopBar(
            canBack: showBack && onBack != null,
            onBack: onBack,
            onInfo: onInfo,
          ),
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
    required this.canBack,
    this.onBack,
    this.onInfo,
  });

  final bool canBack;
  final VoidCallback? onBack;
  final VoidCallback? onInfo;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: canBack
                ? CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size.square(44),
                    onPressed: onBack,
                    child: const Icon(
                      CupertinoIcons.chevron_left,
                      color: SacaTheme.text,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const Spacer(),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size.square(44),
            onPressed: onInfo,
            child: const Icon(
              CupertinoIcons.info,
              color: SacaTheme.text,
              size: 24,
            ),
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
    return Column(
      crossAxisAlignment: align == TextAlign.left
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.stretch,
      children: [
        Text(title, textAlign: align, style: SacaTheme.title),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: align,
          style: SacaTheme.body.copyWith(color: SacaTheme.mutedText),
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
    return Text(text, textAlign: TextAlign.center, style: SacaTheme.small);
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SacaTheme.selected,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: SacaTheme.selectedBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child:
            Text(label, style: SacaTheme.small.copyWith(color: SacaTheme.text)),
      ),
    );
  }
}
