part of '../saca_flow_screen.dart';

extension _SacaSettingsStepWidgets on _SacaFlowScreenState {
  Widget _settingsStep(
    BuildContext context,
    SacaFlowState state,
    SacaPlatformStyle style,
  ) {
    return _StepLayout(
      style: style,
      state: state,
      showBack: true,
      onBack: _closeSettings,
      onInfo: () => _showPrototypeInfo(context),
      onSettings: null,
      localizer: _localizer,
      children: [
        _title(
          style,
          _localizer.t(state.language, 'settingsTitle'),
          _localizer.t(state.language, 'settingsSubtitle'),
        ),
        const SizedBox(height: 18),
        AnimatedBuilder(
          animation: _settings,
          builder: (context, _) {
            final settingsState = _settings.state;
            final colors = SacaThemeColors.of(context);
            final themeContext = SacaThemeContext.of(context);
            final currentLanguage = state.language ?? SacaLanguage.english;
            final panels = <Widget>[
              _SettingsPanel(
                title: _localizer.t(state.language, 'settingsLanguageTitle'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _localizer.t(state.language, 'settingsLanguageSubtitle'),
                      style: SacaTheme.small
                          .copyWith(color: colors.onSurfaceMuted),
                    ),
                    const SizedBox(height: 12),
                    CupertinoSlidingSegmentedControl<SacaLanguage>(
                      key: const ValueKey('settingsLanguageControl'),
                      groupValue: currentLanguage,
                      children: <SacaLanguage, Widget>{
                        SacaLanguage.english: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(_localizer.t(
                              SacaLanguage.english, 'languageEnglishLabel')),
                        ),
                        SacaLanguage.gurindji: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(_localizer.t(
                              SacaLanguage.gurindji, 'languageGurindjiLabel')),
                        ),
                      },
                      onValueChanged: (value) {
                        if (value != null) {
                          _controller.updateLanguage(value);
                        }
                      },
                    ),
                  ],
                ),
              ),
              _SettingsPanel(
                title: _localizer.t(state.language, 'settingsThemeStyleTitle'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _localizer.t(
                          state.language, 'settingsThemeStyleSubtitle'),
                      style: SacaTheme.small
                          .copyWith(color: colors.onSurfaceMuted),
                    ),
                    const SizedBox(height: 12),
                    _ThemePreviewRow(
                      selected: settingsState.visualThemeStyle,
                      language: state.language,
                      localizer: _localizer,
                      onSelected: _settings.setVisualThemeStyle,
                    ),
                    if (themeContext.glassUnavailable) ...[
                      const SizedBox(height: 10),
                      Text(
                        _localizer.t(
                            state.language, 'settingsThemeGlassFallback'),
                        style: SacaTheme.small
                            .copyWith(color: colors.onSurfaceMuted),
                      ),
                    ],
                    if (themeContext.glassSolidFallback) ...[
                      const SizedBox(height: 10),
                      Text(
                        _localizer.t(state.language,
                            'settingsThemeGlassAccessibilityFallback'),
                        style: SacaTheme.small
                            .copyWith(color: colors.onSurfaceMuted),
                      ),
                    ],
                  ],
                ),
              ),
              _SettingsPanel(
                title: _localizer.t(state.language, 'settingsAppearanceTitle'),
                child: _SettingsChoiceRow<SacaThemePreference>(
                  selected: settingsState.themePreference,
                  values: SacaThemePreference.values,
                  labelFor: (value) => switch (value) {
                    SacaThemePreference.light =>
                      _localizer.t(state.language, 'settingsLight'),
                    SacaThemePreference.dark =>
                      _localizer.t(state.language, 'settingsDark'),
                    SacaThemePreference.system =>
                      _localizer.t(state.language, 'settingsSystem'),
                  },
                  onSelected: _settings.setThemePreference,
                ),
              ),
              _SettingsPanel(
                title: _localizer.t(state.language, 'settingsTextSizeTitle'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _localizer.t(state.language, 'settingsTextScale'),
                            style: SacaTheme.body
                                .copyWith(color: colors.onSurface),
                          ),
                        ),
                        Text(
                          '${(settingsState.textScale * 100).round()}%',
                          key: const ValueKey('settingsTextScaleValue'),
                          style:
                              SacaTheme.body.copyWith(color: colors.onSurface),
                        ),
                      ],
                    ),
                    CupertinoSlider(
                      key: const ValueKey('settingsTextScaleSlider'),
                      min: SacaSettingsController.minTextScale,
                      max: SacaSettingsController.maxTextScale,
                      divisions: 10,
                      value: settingsState.textScale,
                      onChanged: _settings.setTextScale,
                    ),
                    Text(
                      _localizer.t(state.language, 'settingsTextPreview'),
                      style: SacaTheme.body.copyWith(
                        fontSize: 17 * settingsState.textScale,
                        color: colors.onSurfaceMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ResponsivePanelGrid(children: panels),
                const SizedBox(height: 18),
                SacaPrimaryButton(
                  label: _localizer.t(state.language, 'settingsDone'),
                  icon: CupertinoIcons.check_mark_circled,
                  filled: true,
                  onPressed: _closeSettings,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ThemePreviewRow extends StatelessWidget {
  const _ThemePreviewRow({
    required this.selected,
    required this.language,
    required this.localizer,
    required this.onSelected,
  });

  final SacaVisualThemeStyle selected;
  final SacaLanguage? language;
  final SacaLocalizer localizer;
  final ValueChanged<SacaVisualThemeStyle> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final style in SacaVisualThemeStyle.values)
          _ThemePreviewChip(
            style: style,
            label: switch (style) {
              SacaVisualThemeStyle.modern =>
                localizer.t(language, 'settingsThemeModern'),
              SacaVisualThemeStyle.glass =>
                localizer.t(language, 'settingsThemeGlass'),
              SacaVisualThemeStyle.classic =>
                localizer.t(language, 'settingsThemeClassic'),
            },
            selected: selected == style,
            onPressed: () => onSelected(style),
          ),
      ],
    );
  }
}

class _ThemePreviewChip extends StatelessWidget {
  const _ThemePreviewChip({
    required this.style,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final SacaVisualThemeStyle style;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = SacaThemeColors.of(context);
    final previewColors = switch (style) {
      SacaVisualThemeStyle.modern => <Color>[
          colors.surface,
          colors.selected,
        ],
      SacaVisualThemeStyle.glass => <Color>[
          colors.surface.withValues(alpha: 0.72),
          colors.accent.withValues(alpha: 0.28),
        ],
      SacaVisualThemeStyle.classic => <Color>[
          colors.surfaceAlt,
          colors.border.withValues(alpha: 0.72),
        ],
    };
    final radius = switch (style) {
      SacaVisualThemeStyle.modern => SacaTheme.radius,
      SacaVisualThemeStyle.glass => 28.0,
      SacaVisualThemeStyle.classic => 16.0,
    };
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 154,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: previewColors),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: selected ? colors.selectedBorder : colors.border,
            width: selected ? 2 : 1,
          ),
          boxShadow: style == SacaVisualThemeStyle.glass
              ? [
                  BoxShadow(
                    color: colors.accent.withValues(alpha: 0.24),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ]
              : const [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: SacaTheme.small.copyWith(color: colors.onSurface),
                  ),
                ),
                if (selected)
                  Icon(CupertinoIcons.check_mark_circled_solid,
                      color: colors.selectedBorder, size: 18),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: style == SacaVisualThemeStyle.classic ? 6 : 8,
              width: style == SacaVisualThemeStyle.glass ? 82 : 64,
              decoration: BoxDecoration(
                color: colors.accent.withValues(
                    alpha: style == SacaVisualThemeStyle.glass ? 0.78 : 1),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsChoiceRow<T extends Object> extends StatelessWidget {
  const _SettingsChoiceRow({
    required this.selected,
    required this.values,
    required this.labelFor,
    required this.onSelected,
  });

  final T selected;
  final List<T> values;
  final String Function(T value) labelFor;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return CupertinoSlidingSegmentedControl<T>(
      key: const ValueKey('settingsChoiceSegmentedControl'),
      groupValue: selected,
      children: <T, Widget>{
        for (final value in values)
          value: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(labelFor(value)),
          ),
      },
      onValueChanged: (value) {
        if (value != null) {
          onSelected(value);
        }
      },
    );
  }
}

class _ResponsivePanelGrid extends StatelessWidget {
  const _ResponsivePanelGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 920) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                Expanded(child: children[i]),
                if (i != children.length - 1) const SizedBox(width: 14),
              ],
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i != children.length - 1) const SizedBox(height: 14),
            ],
          ],
        );
      },
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = SacaThemeColors.of(context);
    final theme = SacaThemeContext.of(context);
    final panel = DecoratedBox(
      decoration: BoxDecoration(
        gradient: theme.surfaceGradient(),
        color: theme.useGlassStyle
            ? theme
                .glassMaterial(SacaGlassMaterial.panel)
                .withValues(alpha: theme.glassOpacity(SacaGlassMaterial.panel))
            : null,
        borderRadius: BorderRadius.circular(theme.radius(SacaTheme.radius)),
        border: Border.all(
          color: theme.useGlassStyle
              ? colors.glassBorder.withValues(alpha: theme.borderOpacity)
              : colors.border,
        ),
        boxShadow: theme.surfaceShadow(),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style: SacaTheme.body.copyWith(color: colors.onSurface)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
    if (!theme.useGlass) return panel;
    return GlassCard(
      padding: EdgeInsets.zero,
      quality: GlassQuality.standard,
      child: panel,
    );
  }
}
