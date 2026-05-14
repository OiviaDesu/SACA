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
    final colors = SacaThemeColors.of(context);
    return DecoratedBox(
      decoration: _sacaPanelDecoration(context, baseRadius: 24),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              localizer.t(language, 'possiblePattern'),
              textAlign: TextAlign.center,
              style: SacaTheme.body.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              localizer.t(language, 'possiblePatternHelper'),
              textAlign: TextAlign.center,
              style: SacaTheme.small.copyWith(color: colors.onSurfaceMuted),
            ),
            const SizedBox(height: 12),
            _PredictionList(
              predictions: _predictions(result),
              language: language,
              localizer: localizer,
            ),
            if (_showLowConfidenceWarning(result)) ...[
              const SizedBox(height: 12),
              _ConfidenceWarning(
                text: localizer.t(language, 'confidenceWarning'),
              ),
            ],
            const SizedBox(height: 18),
            _SeverityMeter(
              severity: result.severity,
              language: language,
              localizer: localizer,
            ),
            const SizedBox(height: 18),
            Text(
              localizer.t(language, 'resultNextStepNote'),
              textAlign: TextAlign.center,
              style: SacaTheme.small.copyWith(color: colors.onSurfaceMuted),
            ),
            const SizedBox(height: 12),
            Text(
              localizer.t(language, 'recommendations'),
              style: SacaTheme.body.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            for (final item in localizer.guidance(language, result))
              _GuidanceLine(text: item),
            const SizedBox(height: 10),
            Text(
              localizer.disclaimer(language, result.disclaimer),
              textAlign: TextAlign.center,
              style: SacaTheme.small.copyWith(color: colors.onSurfaceMuted),
            ),
            if (result.isEmergency) ...[
              const SizedBox(height: 18),
              _EmergencyAction(label: localizer.t(language, 'call000Now')),
            ],
          ],
        ),
      ),
    );
  }

  List<ConditionPrediction> _predictions(AnalysisResult result) {
    if (result.predictions.isNotEmpty) {
      return result.predictions.take(3).toList();
    }
    return <ConditionPrediction>[
      ConditionPrediction(label: result.disease, rank: 1),
    ];
  }

  bool _showLowConfidenceWarning(AnalysisResult result) {
    if (result.isEmergency || result.predictions.isEmpty) return false;
    return result.predictions.first.confidenceLevel == ConfidenceLevel.low;
  }
}

class _PredictionList extends StatelessWidget {
  const _PredictionList({
    required this.predictions,
    required this.language,
    required this.localizer,
  });

  final List<ConditionPrediction> predictions;
  final SacaLanguage? language;
  final SacaLocalizer localizer;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (predictions.isNotEmpty)
          _PredictionCard(
            prediction: predictions.first,
            primary: true,
            language: language,
            localizer: localizer,
          ),
        if (predictions.length > 1) ...[
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              localizer.t(language, 'otherPossibilities'),
              style: SacaTheme.small.copyWith(
                color: SacaThemeColors.of(context).onSurfaceMuted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final prediction in predictions.skip(1)) ...[
            _PredictionCard(
              prediction: prediction,
              primary: false,
              language: language,
              localizer: localizer,
            ),
            if (prediction != predictions.last) const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }
}

class _PredictionCard extends StatelessWidget {
  const _PredictionCard({
    required this.prediction,
    required this.primary,
    required this.language,
    required this.localizer,
  });

  final ConditionPrediction prediction;
  final bool primary;
  final SacaLanguage? language;
  final SacaLocalizer localizer;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: _sacaPanelDecoration(
        context,
        selected: primary,
        baseRadius: primary ? 20 : 16,
      ),
      child: Padding(
        padding: EdgeInsets.all(primary ? 16 : 13),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 360;
            final rankBadge = _PredictionRankBadge(
              rank: prediction.rank,
              primary: primary,
            );
            final textBlock = _PredictionTextBlock(
              prediction: prediction,
              primary: primary,
              language: language,
              localizer: localizer,
            );
            final chip = _ConfidenceChip(
              prediction: prediction,
              primary: primary,
              language: language,
              localizer: localizer,
            );

            if (isCompact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      rankBadge,
                      const SizedBox(width: 12),
                      Expanded(child: textBlock),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: chip,
                  ),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                rankBadge,
                const SizedBox(width: 12),
                Expanded(child: textBlock),
                const SizedBox(width: 10),
                Flexible(
                  flex: 0,
                  child: chip,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PredictionRankBadge extends StatelessWidget {
  const _PredictionRankBadge({required this.rank, required this.primary});

  final int rank;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final colors = SacaThemeColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        shape: BoxShape.circle,
      ),
      child: SizedBox(
        width: primary ? 38 : 32,
        height: primary ? 38 : 32,
        child: Center(
          child: Text(
            '$rank',
            style: SacaTheme.body.copyWith(
              color: colors.accent,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _PredictionTextBlock extends StatelessWidget {
  const _PredictionTextBlock({
    required this.prediction,
    required this.primary,
    required this.language,
    required this.localizer,
  });

  final ConditionPrediction prediction;
  final bool primary;
  final SacaLanguage? language;
  final SacaLocalizer localizer;

  @override
  Widget build(BuildContext context) {
    final colors = SacaThemeColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizer.resultDiseaseLabel(language, prediction.label),
          softWrap: true,
          overflow: TextOverflow.visible,
          style: (primary ? SacaTheme.title : SacaTheme.body).copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          localizer.conditionExplanation(language, prediction.label),
          softWrap: true,
          maxLines: primary ? null : 2,
          overflow: primary ? TextOverflow.visible : TextOverflow.ellipsis,
          style: SacaTheme.small.copyWith(color: colors.onSurfaceMuted),
        ),
      ],
    );
  }
}

class _ConfidenceChip extends StatelessWidget {
  const _ConfidenceChip({
    required this.prediction,
    required this.primary,
    required this.language,
    required this.localizer,
  });

  final ConditionPrediction prediction;
  final bool primary;
  final SacaLanguage? language;
  final SacaLocalizer localizer;

  @override
  Widget build(BuildContext context) {
    final label = switch (prediction.rank) {
      1 => primary
          ? localizer.t(language, 'bestMatchFromAnswers')
          : localizer.t(language, 'bestMatch'),
      2 => localizer.t(language, 'alsoPossible'),
      _ => localizer.t(language, 'lessLikely'),
    };
    final color = switch (prediction.rank) {
      1 => SacaTheme.safe,
      2 => const Color(0xFFB87000),
      _ => SacaThemeColors.of(context).accent,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: SacaTheme.small.copyWith(
            color: color == SacaTheme.safe ? const Color(0xFF2F6D1E) : color,
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
        ),
      ),
    );
  }
}

class _ConfidenceWarning extends StatelessWidget {
  const _ConfidenceWarning({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SacaThemeColors.of(context).selected.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: SacaThemeColors.of(context)
              .selectedBorder
              .withValues(alpha: 0.45),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: SacaTheme.small.copyWith(
            color: SacaThemeColors.of(context).onSurface,
          ),
        ),
      ),
    );
  }
}

class _EmergencyAction extends StatelessWidget {
  const _EmergencyAction({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x14D92D20),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x33D92D20)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.phone_fill,
              color: SacaTheme.emergency,
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: SacaTheme.title.copyWith(
                color: SacaTheme.emergency,
                fontSize: 23,
              ),
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
    final colors = SacaThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 3),
            child: Icon(
              CupertinoIcons.check_mark_circled,
              size: 18,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: SacaTheme.body.copyWith(color: colors.onSurface))),
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
    final colors = SacaThemeColors.of(context);
    final label = localizer.severityLabel(language, severity);
    final color = switch (severity) {
      SeverityLevel.mild => SacaTheme.safe,
      SeverityLevel.moderate => SacaTheme.warning,
      SeverityLevel.severe => const Color(0xFFFF8A3D),
      SeverityLevel.emergency => SacaTheme.emergency,
    };
    final position = switch (severity) {
      SeverityLevel.mild => 0.18,
      SeverityLevel.moderate => 0.44,
      SeverityLevel.severe => 0.68,
      SeverityLevel.emergency => 0.92,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              '${localizer.t(language, 'severity')}: $label',
              textAlign: TextAlign.center,
              style: SacaTheme.body.copyWith(
                color: severity == SeverityLevel.moderate
                    ? colors.onSurface
                    : color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
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
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.onSurface,
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
