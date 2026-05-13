import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show LinearProgressIndicator;
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

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
  static final Uri _nativeReleaseUri =
      Uri.parse('https://github.com/OiviaDesu/SACA/releases');

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
        return _SacaConfirmationDialog(
          title: _localizer.t(language, titleKey),
          message: _localizer.t(language, messageKey),
          reviewLabel: _localizer.t(language, 'reviewAnswers'),
          continueLabel: _localizer.t(language, 'continueAnyway'),
          onReview: () {
            Navigator.of(dialogContext).pop();
            _controller.dismissPendingConfirmation();
            _shownConfirmation = null;
          },
          onContinue: () {
            Navigator.of(dialogContext).pop();
            _controller.confirmPendingAction();
            _shownConfirmation = null;
          },
        );
      },
    );
  }

  // ignore: unused_element
  void _showNativeOnlyDialog(BuildContext context) {
    final language = _controller.state.language;
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _SacaConfirmationDialog(
          title: _localizer.t(language, 'nativeOnlyTitle'),
          message: _localizer.t(language, 'nativeOnlyMessage'),
          reviewLabel: _localizer.t(language, 'ok'),
          continueLabel: _localizer.t(language, 'openReleases'),
          onReview: () => Navigator.of(dialogContext).pop(),
          onContinue: () {
            Navigator.of(dialogContext).pop();
            unawaited(
              launchUrl(
                _nativeReleaseUri,
                mode: LaunchMode.externalApplication,
              ),
            );
          },
        );
      },
    );
  }
}

class _SacaConfirmationDialog extends StatelessWidget {
  const _SacaConfirmationDialog({
    required this.title,
    required this.message,
    required this.reviewLabel,
    required this.continueLabel,
    required this.onReview,
    required this.onContinue,
  });

  final String title;
  final String message;
  final String reviewLabel;
  final String continueLabel;
  final VoidCallback onReview;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final colors = SacaThemeColors.of(context);
    final theme = SacaThemeContext.of(context);
    final radius = theme.radius(theme.useClassic ? 18 : 22);
    final background = theme.useGlassStyle
        ? theme.glassMaterial(SacaGlassMaterial.dialog).withValues(
              alpha: theme.glassOpacity(SacaGlassMaterial.dialog),
            )
        : colors.surface;
    final foreground = theme.useGlassStyle
        ? colors.onGlassPrimary
        : theme.foregroundFor(SacaThemeSurfaceRole.surface);
    final muted =
        theme.useGlassStyle ? colors.onGlassMuted : colors.onSurfaceMuted;
    final border = theme.useGlassStyle ? colors.glassBorder : colors.outline;
    final actionForeground = theme.useClassic ? colors.onSurface : foreground;
    final defaultActionForeground = theme.useClassic
        ? colors.onSurface
        : theme.useGlassStyle
            ? colors.onGlassPrimary
            : colors.onSelected;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                  color: border, width: theme.useGlassStyle ? 1.2 : 1),
              boxShadow: theme.surfaceShadow(highlighted: theme.useGlassStyle),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: SacaTheme.title.copyWith(
                            color: foreground,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: SacaTheme.body.copyWith(
                            color: muted,
                            height: 1.32,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _SacaDialogAction(
                    label: reviewLabel,
                    color: actionForeground,
                    borderColor: colors.separator,
                    onPressed: onReview,
                  ),
                  _SacaDialogAction(
                    label: continueLabel,
                    color: defaultActionForeground,
                    borderColor: colors.separator,
                    isDefault: true,
                    onPressed: onContinue,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SacaDialogAction extends StatelessWidget {
  const _SacaDialogAction({
    required this.label,
    required this.color,
    required this.borderColor,
    required this.onPressed,
    this.isDefault = false,
  });

  final String label;
  final Color color;
  final Color borderColor;
  final VoidCallback onPressed;
  final bool isDefault;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: borderColor, width: 0.8)),
      ),
      child: CupertinoButton(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        pressedOpacity: 0.72,
        onPressed: onPressed,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: SacaTheme.body.copyWith(
            color: color,
            fontWeight: isDefault ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _SacaMessageDialog extends StatelessWidget {
  const _SacaMessageDialog({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colors = SacaThemeColors.of(context);
    final theme = SacaThemeContext.of(context);
    final radius = theme.radius(theme.useClassic ? 18 : 22);
    final background = theme.useGlassStyle
        ? theme.glassMaterial(SacaGlassMaterial.dialog).withValues(
              alpha: theme.glassOpacity(SacaGlassMaterial.dialog),
            )
        : colors.surface;
    final foreground = theme.useGlassStyle
        ? colors.onGlassPrimary
        : theme.foregroundFor(SacaThemeSurfaceRole.surface);
    final muted =
        theme.useGlassStyle ? colors.onGlassMuted : colors.onSurfaceMuted;
    final border = theme.useGlassStyle ? colors.glassBorder : colors.outline;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                  color: border, width: theme.useGlassStyle ? 1.2 : 1),
              boxShadow: theme.surfaceShadow(highlighted: theme.useGlassStyle),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: SacaTheme.title.copyWith(
                            color: foreground,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: SacaTheme.body.copyWith(
                            color: muted,
                            height: 1.32,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _SacaDialogAction(
                    label: actionLabel,
                    color: foreground,
                    borderColor: colors.separator,
                    isDefault: true,
                    onPressed: onAction,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
