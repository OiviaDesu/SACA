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
    final isTablet = width >= 600;
    final contentMaxWidth = width >= 900
        ? 980.0
        : width >= 600
            ? 640.0
            : SacaTheme.phoneWidth;
    final horizontalPadding = width >= 600 ? 32.0 : 20.0;
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
              constraints: BoxConstraints(maxWidth: isTablet ? 1100 : 720),
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    isTablet ? 24 : 12,
                    horizontalPadding,
                    28,
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
