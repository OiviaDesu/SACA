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
          'Settings',
          'Adjust appearance for comfort and readability.',
        ),
        const SizedBox(height: 18),
        AnimatedBuilder(
          animation: _settings,
          builder: (context, _) {
            final settingsState = _settings.state;
            final colors = SacaThemeColors.of(context);
            final panels = <Widget>[
              _SettingsPanel(
                title: 'Appearance',
                child: CupertinoSlidingSegmentedControl<SacaThemePreference>(
                  groupValue: settingsState.themePreference,
                  children: const <SacaThemePreference, Widget>{
                    SacaThemePreference.light: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('Light'),
                    ),
                    SacaThemePreference.dark: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('Dark'),
                    ),
                    SacaThemePreference.system: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('System'),
                    ),
                  },
                  onValueChanged: (value) {
                    if (value != null) {
                      _settings.setThemePreference(value);
                    }
                  },
                ),
              ),
              _SettingsPanel(
                title: 'Text size',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Text scale',
                            style: SacaTheme.body.copyWith(color: colors.text),
                          ),
                        ),
                        Text(
                          '${(settingsState.textScale * 100).round()}%',
                          key: const ValueKey('settingsTextScaleValue'),
                          style: SacaTheme.body.copyWith(color: colors.text),
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
                      'Preview: larger text helps patients read instructions clearly.',
                      style: SacaTheme.body.copyWith(
                        fontSize: 17 * settingsState.textScale,
                        color: colors.mutedText,
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
                  label: 'Done',
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
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: colors.surfaceGradient,
        borderRadius: BorderRadius.circular(SacaTheme.radius),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: SacaTheme.body.copyWith(color: colors.text)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
