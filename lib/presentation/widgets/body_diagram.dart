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

  static const double chipWidth = 150;
  static const double chipHeight = 60;

  @override
  Widget build(BuildContext context) {
    final y = _verticalPositionFor(area.id);

    // Controls the distance between the labels and the card edges.
    // The same sidePadding is used on both sides to keep the layout symmetrical.
    final sidePadding = size.width * 0.08;

    final left = _isRightColumn(area.id)
        ? size.width - sidePadding - chipWidth
        : sidePadding;

    return Positioned(
      left: left,
      top: y * size.height,
      child: Semantics(
        button: true,
        selected: selected,
        label: '$semanticsPrefix ${label.replaceAll('\n', ' ')}',
        child: SizedBox(
          width: chipWidth,
          height: chipHeight,
          child: SacaChipButton(
            label: label,
            selected: selected,
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }

  bool _isRightColumn(String id) {
    return switch (id) {
      // Front view - right column
      'eyes' || 'heart' || 'hand' || 'knees' || 'toes' => true,

      // Back view - right column
      'ears' || 'shoulder' || 'arm' || 'finger' || 'ankle' => true,

      _ => false,
    };
  }

  double _verticalPositionFor(String id) {
    return switch (id) {
      // Front view - left column
      'head' => 0.06,
      'throat' => 0.21,
      'chest' => 0.36,
      'stomach' => 0.51,
      'leg' => 0.73,

      // Front view - right column
      'eyes' => 0.06,
      'heart' => 0.21,
      'hand' => 0.51,
      'knees' => 0.73,
      'toes' => 0.86,

      // Back view - left column
      'neck' => 0.06,
      'back' => 0.21,
      'lower_back' => 0.36,
      'lower_leg' => 0.73,

      // Back view - right column
      'ears' => 0.06,
      'shoulder' => 0.21,
      'arm' => 0.36,
      'finger' => 0.51,
      'ankle' => 0.86,

      _ => 0.06,
    };
  }
}