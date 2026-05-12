import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show LinearProgressIndicator;
import 'package:flutter/services.dart';

import '../../core/theme/saca_theme.dart';
import '../../core/layout/saca_window_size_class.dart';
import '../../domain/models/saca_models.dart';
import '../../domain/services/duration_interpreter.dart';
import '../../infrastructure/platform/desktop_shell_policy.dart';
import '../adaptive/saca_platform_style.dart';
import '../controllers/saca_flow_controller.dart';
import '../localization/saca_localizer.dart';
import '../readiness/saca_readiness_controller.dart';
import '../settings/saca_settings_controller.dart';
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
part 'saca_flow/settings_widgets.dart';

enum _VisualInputStage { symptoms, front, back }

class SacaFlowScreen extends StatefulWidget {
  const SacaFlowScreen({
    super.key,
    required this.controller,
    required this.settings,
    required this.readiness,
    this.styleOverride,
    this.localizer,
  });

  final SacaFlowController controller;
  final SacaSettingsController settings;
  final SacaReadinessState readiness;
  final SacaPlatformStyle? styleOverride;
  final SacaLocalizer? localizer;

  @override
  State<SacaFlowScreen> createState() => _SacaFlowScreenState();
}

class _SacaFlowScreenState extends State<SacaFlowScreen> {
  late final SacaFlowController _controller;
  late final SacaLocalizer _localizer;
  late final SacaSettingsController _settings;
  _VisualInputStage _visualStage = _VisualInputStage.symptoms;
  SacaConfirmationType? _shownConfirmation;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _settings = widget.settings;
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
    final colors = SacaThemeColors.of(context);
    return CupertinoPageScaffold(
      backgroundColor: colors.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const _ShellBackdrop(),
          SafeArea(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final state = _controller.state;
                _scheduleConfirmationDialog(context, state);
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final contentStyle = widget.styleOverride ??
                        SacaPlatformStyleResolver.resolve(
                          platform: defaultTargetPlatform,
                          width: constraints.maxWidth,
                        );
                    final usesDesktopShell = widget.styleOverride ==
                            SacaPlatformStyle.windowsDesktop ||
                        (widget.styleOverride == null &&
                            DesktopShellPolicy.usesDesktopLayout(
                              platform: defaultTargetPlatform,
                              width: constraints.maxWidth,
                            ));
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
                        child: _contentFor(context, state, contentStyle),
                      ),
                    );
                    final shellChild = usesDesktopShell
                        ? _DesktopShell(
                            state: state,
                            localizer: _localizer,
                            readiness: widget.readiness,
                            onBack: state.step == SacaStep.settings
                                ? _controller.goBack
                                : _canGoBack(state.step)
                                    ? _controller.goBack
                                    : null,
                            onInfo: () => _showPrototypeInfo(context),
                            onSettings: _showSettings,
                            child: content,
                          )
                        : _MobileShell(
                            state: state,
                            localizer: _localizer,
                            onBack: state.step == SacaStep.settings
                                ? _controller.goBack
                                : _canGoBack(state.step)
                                    ? _controller.goBack
                                    : null,
                            onInfo: () => _showPrototypeInfo(context),
                            onSettings: _showSettings,
                            child: content,
                          );

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

  void _scheduleConfirmationDialog(BuildContext context, SacaFlowState state) {
    final pending = state.pendingConfirmation;
    if (pending == null || pending == _shownConfirmation) return;
    _shownConfirmation = pending;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _controller.state.pendingConfirmation != pending) {
        return;
      }
      _showConfirmationDialog(context, pending);
    });
  }

  void _showConfirmationDialog(
    BuildContext context,
    SacaConfirmationType type,
  ) {
    final language = _controller.state.language;
    final titleKey = switch (type) {
      SacaConfirmationType.emptyInput => 'emptyInputConfirmTitle',
      SacaConfirmationType.noClearIllness => 'noClearIllnessConfirmTitle',
    };
    final messageKey = switch (type) {
      SacaConfirmationType.emptyInput => 'emptyInputConfirmMessage',
      SacaConfirmationType.noClearIllness => 'noClearIllnessConfirmMessage',
    };
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: Text(_localizer.t(language, titleKey)),
          content: Text(_localizer.t(language, messageKey)),
          actions: [
            CupertinoDialogAction(
              child: Text(_localizer.t(language, 'reviewAnswers')),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _controller.dismissPendingConfirmation();
                _shownConfirmation = null;
              },
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: Text(_localizer.t(language, 'continueAnyway')),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _controller.confirmPendingAction();
                _shownConfirmation = null;
              },
            ),
          ],
        );
      },
    );
  }
}
