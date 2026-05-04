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
                                ? 'assets/Images/Body-front.png'
                                : 'assets/Images/Body-back.png',
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
          width: 126,
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
  const leftX = 0.05;
  const rightX = 0.75;

  return switch (id) {
    // Front view
    'head' => Offset(leftX, 0.06),
    'throat' => Offset(leftX, 0.20),
    'chest' => Offset(leftX, 0.34),
    'stomach' => Offset(leftX, 0.50),
    'leg' => Offset(leftX, 0.74),

    'eyes' => Offset(rightX, 0.09),
    'heart' => Offset(rightX, 0.23),
    'hand' => Offset(rightX, 0.55),
    'knees' => Offset(rightX, 0.76),
    'toes' => Offset(rightX, 0.88),

    // Back view
    'neck' => Offset(leftX, 0.18),
    'back' => Offset(leftX, 0.34),
    'lower_back' => Offset(leftX, 0.50),
    'lower_leg' => Offset(leftX, 0.74),
    'ankle' => Offset(leftX, 0.87),

    'ears' => Offset(rightX, 0.09),
    'shoulder' => Offset(rightX, 0.20),
    'arm' => Offset(rightX, 0.34),
    'finger' => Offset(rightX, 0.58),

    _ => Offset(leftX, 0.05),
  };
}
}