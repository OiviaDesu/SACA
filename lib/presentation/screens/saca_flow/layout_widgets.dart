part of '../saca_flow_screen.dart';

class _MobileShell extends StatelessWidget {
  const _MobileShell({
    required this.state,
    required this.localizer,
    required this.child,
    this.onBack,
    this.onInfo,
    this.onSettings,
  });

  final SacaFlowState state;
  final SacaLocalizer localizer;
  final Widget child;
  final VoidCallback? onBack;
  final VoidCallback? onInfo;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final height = MediaQuery.sizeOf(context).height;
    final windowClass = SacaWindowSizeClasses.fromWidth(width);
    final isMediumOrLarger = !windowClass.isCompact;
    final isShortWindow = height < 820;
    final contentMaxWidth = switch (windowClass) {
      SacaWindowSizeClass.compact => SacaTheme.phoneWidth,
      SacaWindowSizeClass.medium => 640.0,
      SacaWindowSizeClass.expanded => 980.0,
      SacaWindowSizeClass.large => 1040.0,
      SacaWindowSizeClass.extraLarge => 1100.0,
    };
    final horizontalPadding = isMediumOrLarger ? 32.0 : 20.0;
    return Column(
      children: [
        _MobileTopBar(
          state: state,
          localizer: localizer,
          canBack: onBack != null,
          onBack: onBack,
          onInfo: onInfo,
          onSettings: onSettings,
        ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isMediumOrLarger ? 1100 : 720,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    isMediumOrLarger && !isShortWindow ? 24 : 12,
                    horizontalPadding,
                    isShortWindow ? 20 : 28,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: contentMaxWidth),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
