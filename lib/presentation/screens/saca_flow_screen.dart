import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/theme/saca_theme.dart';
import '../../domain/models/saca_models.dart';
import '../adaptive/saca_platform_style.dart';
import '../controllers/saca_flow_controller.dart';
import '../localization/saca_localizer.dart';
import '../widgets/body_diagram.dart';
import '../widgets/desktop_window_chrome.dart';
import '../widgets/saca_controls.dart';
import '../widgets/saca_logo_header.dart';

part 'saca_flow/layout_widgets.dart';
part 'saca_flow/desktop_shell_widgets.dart';
part 'saca_flow/shared_layout_widgets.dart';
part 'saca_flow/voice_loading_overlay.dart';
part 'saca_flow/input_widgets.dart';
part 'saca_flow/result_widgets.dart';
part 'saca_flow/step_widgets.dart';

enum _VisualInputStage { symptoms, front, back }

class SacaFlowScreen extends StatefulWidget {
  const SacaFlowScreen({
    super.key,
    required this.controller,
    this.styleOverride,
    this.localizer,
  });

  final SacaFlowController controller;
  final SacaPlatformStyle? styleOverride;
  final SacaLocalizer? localizer;

  @override
  State<SacaFlowScreen> createState() => _SacaFlowScreenState();
}

class _SacaFlowScreenState extends State<SacaFlowScreen> {
  late final SacaFlowController _controller;
  late final SacaLocalizer _localizer;
  _VisualInputStage _visualStage = _VisualInputStage.symptoms;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _localizer = widget.localizer ?? SacaLocalizer();
    Future<void>.delayed(const Duration(milliseconds: 650), () {
      if (mounted && _controller.state.step == SacaStep.splash) {
        _controller.showLanguage();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setVisualStage(_VisualInputStage stage) {
    setState(() {
      _visualStage = stage;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: SacaTheme.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const _ShellBackdrop(),
          SafeArea(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final state = _controller.state;
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final style = widget.styleOverride ??
                        SacaPlatformStyleResolver.resolve(
                          platform: defaultTargetPlatform,
                          width: constraints.maxWidth,
                        );
                    final content = AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        final slide = Tween<Offset>(
                          begin: const Offset(0, 0.04),
                          end: Offset.zero,
                        ).animate(animation);
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(position: slide, child: child),
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey<String>(
                          '${state.step.name}-${_visualStage.name}',
                        ),
                        child: _contentFor(context, state, style),
                      ),
                    );
                    final shellChild = style == SacaPlatformStyle.windowsDesktop
                        ? _DesktopShell(
                            state: state,
                            localizer: _localizer,
                            onBack: _canGoBack(state.step)
                                ? _controller.goBack
                                : null,
                            onInfo: () => _showPrototypeInfo(context),
                            child: content,
                          )
                        : _MobileShell(child: content);

                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        shellChild,
                        _VoiceLoadingOverlay(
                          visible: state.voiceBusyPhase != VoiceBusyPhase.none,
                          title: _localizer.voiceBusyTitle(
                            state.language,
                            state.voiceBusyPhase,
                          ),
                          subtitle: _localizer.voiceBusySubtitle(
                            state.language,
                            state.voiceBusyPhase,
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
