import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'core/theme/saca_theme.dart';
import 'domain/services/clinical_vocabulary_service.dart';
import 'infrastructure/analysis/hybrid_symptom_suggestion_service.dart';
import 'infrastructure/analysis/mock_analysis_service.dart';
import 'infrastructure/analysis/on_device_diagnosis_analysis_service.dart';
import 'infrastructure/localization/asset_lexicon_repository.dart';
import 'infrastructure/speech/voice_prewarm_service.dart';
import 'infrastructure/speech/whisper_speech_input_service.dart';
import 'infrastructure/window/saca_window_configurator.dart';
import 'presentation/controllers/saca_flow_controller.dart';
import 'presentation/localization/saca_localizer.dart';
import 'presentation/readiness/saca_readiness_controller.dart';
import 'presentation/screens/saca_flow_screen.dart';
import 'presentation/settings/saca_settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _configureWindow();
  final vocabulary = await _loadVocabulary();
  final speechInput = WhisperSpeechInputService();
  final settings = SacaSettingsController();
  final glassAvailable = await _initializeGlassTheme();
  unawaited(_loadSettings(settings));
  final app = SacaApp(
    vocabulary: vocabulary,
    speechInput: speechInput,
    settings: settings,
    glassAvailable: glassAvailable,
  );
  runApp(
    glassAvailable
        ? LiquidGlassWidgets.wrap(
            child: app,
            adaptiveQuality: true,
            respectSystemAccessibility: true,
          )
        : app,
  );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    VoicePrewarmService(speechInput: speechInput).prewarm();
  });
}

Future<bool> _initializeGlassTheme() async {
  try {
    await LiquidGlassWidgets.initialize();
    return true;
  } catch (error, stackTrace) {
    debugPrint('[SACA] Glass theme unavailable: $error');
    debugPrintStack(stackTrace: stackTrace);
    return false;
  }
}

Future<void> _configureWindow() async {
  try {
    await configureSacaDesktopWindow();
  } catch (error, stackTrace) {
    debugPrint('[SACA] Window setup unavailable: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

Future<void> _loadSettings(SacaSettingsController settings) async {
  try {
    await settings.load();
  } catch (error, stackTrace) {
    debugPrint('[SACA] Settings unavailable: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

Future<ClinicalVocabularyService> _loadVocabulary() async {
  try {
    final entries = await const AssetLexiconRepository()
        .loadEntries()
        .timeout(const Duration(seconds: 3));
    return ClinicalVocabularyService.fromEntries(entries);
  } catch (error, stackTrace) {
    debugPrint('[SACA] Gurindji lexicon unavailable: $error');
    debugPrintStack(stackTrace: stackTrace);
    return const ClinicalVocabularyService.empty();
  }
}

class SacaApp extends StatelessWidget {
  SacaApp({
    super.key,
    required this.vocabulary,
    required this.speechInput,
    this.readiness = SacaReadinessState.ready,
    this.glassAvailable = false,
    SacaSettingsController? settings,
  }) : settings = settings ?? SacaSettingsController();

  final ClinicalVocabularyService vocabulary;
  final WhisperSpeechInputService speechInput;
  final SacaSettingsController settings;
  final SacaReadinessState readiness;
  final bool glassAvailable;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        final brightness = settings.resolveBrightness(
          WidgetsBinding.instance.platformDispatcher.platformBrightness,
        );
        final colors = brightness == Brightness.dark
            ? SacaTheme.darkColors
            : SacaTheme.lightColors;
        final requestedStyle = settings.state.visualThemeStyle;
        final surfaceStyle = _surfaceStyleFor(
          requestedStyle,
          glassAvailable: glassAvailable,
        );
        final glassUnavailable = requestedStyle == SacaVisualThemeStyle.glass &&
            !glassAvailable;
        final home = SacaFlowScreen(
          controller: SacaFlowController(
            speechInput: speechInput,
            analysisService: OnDeviceDiagnosisAnalysisService(
              fallback: MockAnalysisService(vocabulary: vocabulary),
              vocabulary: vocabulary,
            ),
            symptomSuggestionService: HybridSymptomSuggestionService(),
          ),
          localizer: SacaLocalizer(vocabulary: vocabulary),
          settings: settings,
          readiness: readiness,
        );
        return CupertinoApp(
          title: 'SACA',
          debugShowCheckedModeBanner: false,
          theme: brightness == Brightness.dark
              ? SacaTheme.darkCupertinoTheme
              : SacaTheme.cupertinoTheme,
          builder: (context, child) {
            return _AnimatedSacaTheme(
              colors: colors,
              surfaceStyle: surfaceStyle,
              glassUnavailable: glassUnavailable,
              brightness: brightness,
              textScale: settings.state.textScale,
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: home,
        );
      },
    );
  }

  SacaThemeSurfaceStyle _surfaceStyleFor(
    SacaVisualThemeStyle style, {
    required bool glassAvailable,
  }) {
    return switch (style) {
      SacaVisualThemeStyle.modern => SacaThemeSurfaceStyle.modern,
      SacaVisualThemeStyle.glass => glassAvailable
          ? SacaThemeSurfaceStyle.glass
          : SacaThemeSurfaceStyle.modern,
      SacaVisualThemeStyle.classic => SacaThemeSurfaceStyle.classic,
    };
  }
}

class _AnimatedSacaTheme extends ImplicitlyAnimatedWidget {
  const _AnimatedSacaTheme({
    required this.colors,
    required this.surfaceStyle,
    required this.glassUnavailable,
    required this.brightness,
    required this.textScale,
    required this.child,
  }) : super(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );

  final SacaThemeColors colors;
  final SacaThemeSurfaceStyle surfaceStyle;
  final bool glassUnavailable;
  final Brightness brightness;
  final double textScale;
  final Widget child;

  @override
  AnimatedWidgetBaseState<_AnimatedSacaTheme> createState() =>
      _AnimatedSacaThemeState();
}

class _AnimatedSacaThemeState
    extends AnimatedWidgetBaseState<_AnimatedSacaTheme> {
  _SacaThemeColorsTween? _colors;
  Tween<double>? _textScale;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _colors = visitor(
      _colors,
      widget.colors,
      (value) => _SacaThemeColorsTween(begin: value as SacaThemeColors),
    ) as _SacaThemeColorsTween?;
    _textScale = visitor(
      _textScale,
      widget.textScale,
      (value) => Tween<double>(begin: value as double),
    ) as Tween<double>?;
  }

  @override
  Widget build(BuildContext context) {
    final scoped = SacaThemeScope(
      colors: _colors!.evaluate(animation),
      surfaceStyle: widget.surfaceStyle,
      glassUnavailable: widget.glassUnavailable,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(_textScale!.evaluate(animation)),
        ),
        child: widget.child,
      ),
    );
    if (widget.surfaceStyle != SacaThemeSurfaceStyle.classic) {
      return scoped;
    }
    return Theme(
      data: SacaTheme.materialTheme(_colors!.evaluate(animation), widget.brightness),
      child: scoped,
    );
  }
}

class _SacaThemeColorsTween extends Tween<SacaThemeColors> {
  _SacaThemeColorsTween({required SacaThemeColors begin}) : super(begin: begin);

  @override
  SacaThemeColors lerp(double t) {
    return SacaThemeColors.lerp(begin!, end!, t);
  }
}
