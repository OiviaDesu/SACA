part of '../saca_flow_screen.dart';

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({
    required this.result,
    required this.language,
    required this.localizer,
  });

  final AnalysisResult result;
  final SacaLanguage? language;
  final SacaLocalizer localizer;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: SacaTheme.surfaceGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: result.isEmergency ? SacaTheme.emergency : SacaTheme.border,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x16000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (result.isEmergency) ...[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0x14D92D20),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x33D92D20)),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Text(
                    localizer.t(language, 'call000Now'),
                    textAlign: TextAlign.center,
                    style: SacaTheme.title.copyWith(color: SacaTheme.emergency),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            Text(
              localizer.t(language, 'possiblePattern'),
              textAlign: TextAlign.center,
              style: SacaTheme.small,
            ),
            const SizedBox(height: 4),
            Text(
              localizer.resultDiseaseLabel(language, result.disease),
              textAlign: TextAlign.center,
              style: SacaTheme.title,
            ),
            const SizedBox(height: 18),
            _SeverityMeter(
              severity: result.severity,
              language: language,
              localizer: localizer,
            ),
            const SizedBox(height: 18),
            for (final item in localizer.guidance(language, result))
              _GuidanceLine(text: item),
            const SizedBox(height: 10),
            Text(
              localizer.disclaimer(language, result.disclaimer),
              textAlign: TextAlign.center,
              style: SacaTheme.small,
            ),
          ],
        ),
      ),
    );
  }
}

class _GuidanceLine extends StatelessWidget {
  const _GuidanceLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Icon(
              CupertinoIcons.check_mark_circled,
              size: 18,
              color: SacaTheme.text,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: SacaTheme.body)),
        ],
      ),
    );
  }
}

class _SeverityMeter extends StatelessWidget {
  const _SeverityMeter({
    required this.severity,
    required this.language,
    required this.localizer,
  });

  final SeverityLevel severity;
  final SacaLanguage? language;
  final SacaLocalizer localizer;

  @override
  Widget build(BuildContext context) {
    final label = localizer.severityLabel(language, severity);
    final position = switch (severity) {
      SeverityLevel.mild => 0.18,
      SeverityLevel.moderate => 0.44,
      SeverityLevel.severe => 0.68,
      SeverityLevel.emergency => 0.92,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${localizer.t(language, 'severity')}: $label',
          textAlign: TextAlign.center,
          style: SacaTheme.body,
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 34,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Positioned.fill(
                    top: 12,
                    bottom: 12,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: const LinearGradient(
                          colors: [
                            SacaTheme.safe,
                            SacaTheme.warning,
                            SacaTheme.emergency,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: (constraints.maxWidth - 18) * position,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        color: SacaTheme.text,
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox(width: 18, height: 18),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
