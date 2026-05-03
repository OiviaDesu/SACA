import 'package:flutter/cupertino.dart';

import '../../domain/models/saca_models.dart';
import 'saca_controls.dart';

class BodyDiagram extends StatelessWidget {
  const BodyDiagram({
    super.key,
    required this.view,
    required this.selectedIds,
    required this.onToggle,
    required this.labelForArea,
    required this.semanticsPrefix,
  });

  final BodyView view;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;
  final String Function(BodyArea area) labelForArea;
  final String semanticsPrefix;

  @override
  Widget build(BuildContext context) {
    final areas = SacaFlowState.bodyAreas
        .where((area) => area.view == view)
        .toList(growable: false);

    return KeyedSubtree(
      key: ValueKey<String>('bodyDiagram-${view.name}'),
      child: AspectRatio(
        aspectRatio: 0.92,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFEFBFA),
                Color(0xFFF4FBFD),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFD9E7EB)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 26,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Image.asset(
                            view == BodyView.front
                                ? 'assets/Images/Body_front.png'
                                : 'assets/Images/Body_back.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    for (final area in areas)
                      _PositionedAreaChip(
                        area: area,
                        label: labelForArea(area),
                        semanticsPrefix: semanticsPrefix,
                        selected: selectedIds.contains(area.id),
                        size: constraints.biggest,
                        onPressed: () => onToggle(area.id),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _PositionedAreaChip extends StatelessWidget {
  const _PositionedAreaChip({
    required this.area,
    required this.label,
    required this.semanticsPrefix,
    required this.selected,
    required this.size,
    required this.onPressed,
  });

  final BodyArea area;
  final String label;
  final String semanticsPrefix;
  final bool selected;
  final Size size;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final point = _positionFor(area.id);

    return Positioned(
      left: point.dx * size.width,
      top: point.dy * size.height,
      child: Semantics(
        button: true,
        selected: selected,
        label: '$semanticsPrefix ${label.replaceAll('\n', ' ')}',
        child: SizedBox(
          width: label.length > 12 ? 126 : 96,
          child: SacaChipButton(
            label: label,
            selected: selected,
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }

  Offset _positionFor(String id) {
    return switch (id) {
      'head' => const Offset(0.02, 0.06),
      'eyes' => const Offset(0.69, 0.09),
      'throat' => const Offset(0.03, 0.21),
      'heart' => const Offset(0.67, 0.24),
      'chest' => const Offset(0.02, 0.35),
      'stomach' => const Offset(0.02, 0.52),
      'hand' => const Offset(0.70, 0.58),
      'leg' => const Offset(0.03, 0.76),
      'knees' => const Offset(0.68, 0.80),
      'toes' => const Offset(0.64, 0.92),

      'ears' => const Offset(0.68, 0.09),
      'neck' => const Offset(0.03, 0.19),
      'shoulder' => const Offset(0.66, 0.19),
      'back' => const Offset(0.03, 0.34),
      'arm' => const Offset(0.69, 0.39),
      'lower_back' => const Offset(0.03, 0.51),
      'finger' => const Offset(0.68, 0.66),
      'lower_leg' => const Offset(0.03, 0.79),
      'ankle' => const Offset(0.02, 0.93),

      _ => const Offset(0.05, 0.05),
    };
  }
}