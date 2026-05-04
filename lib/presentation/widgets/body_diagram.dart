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

    final visibleIds = areas.map((area) => area.id).toSet();

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

                    // Red highlight points for selected body parts
                    // on the current view only.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _BodyHighlightPainter(
                            selectedIds: selectedIds,
                            visibleIds: visibleIds,
                          ),
                        ),
                      ),
                    ),

                    // Connector lines between labels and body parts.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _BodyConnectorPainter(
                            areas: areas,
                            view: view,
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
    final y = _BodyDiagramLayout.verticalPositionFor(area.id);
    final sidePadding = size.width * _BodyDiagramLayout.sidePaddingRatio;

    final left = _BodyDiagramLayout.isRightColumn(area.id)
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
}

class _BodyHighlightPainter extends CustomPainter {
  const _BodyHighlightPainter({
    required this.selectedIds,
    required this.visibleIds,
  });

  final Set<String> selectedIds;
  final Set<String> visibleIds;

  @override
  void paint(Canvas canvas, Size size) {
    if (selectedIds.isEmpty) return;

    for (final id in selectedIds) {
      // Only draw highlight points for body parts visible
      // in the current Front or Back view.
      if (!visibleIds.contains(id)) continue;

      final center = _BodyTargetPoints.positionFor(id, size);
      if (center == null) continue;

      final outerPaint = Paint()
        ..color = const Color(0x44E85B5B)
        ..style = PaintingStyle.fill;

      final middlePaint = Paint()
        ..color = const Color(0x77E85B5B)
        ..style = PaintingStyle.fill;

      final innerPaint = Paint()
        ..color = const Color(0xFFE85B5B)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(center, 24, outerPaint);
      canvas.drawCircle(center, 14, middlePaint);
      canvas.drawCircle(center, 6, innerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BodyHighlightPainter oldDelegate) {
    return oldDelegate.selectedIds != selectedIds ||
        oldDelegate.visibleIds != visibleIds;
  }
}

class _BodyConnectorPainter extends CustomPainter {
  const _BodyConnectorPainter({
    required this.areas,
    required this.view,
  });

  final List<BodyArea> areas;
  final BodyView view;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF5F7F91)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final area in areas) {
      final start = _labelAnchorFor(area.id, size);
      final end = _BodyTargetPoints.positionFor(area.id, size);

      if (start == null || end == null) continue;

      canvas.drawLine(start, end, paint);
    }
  }

  Offset? _labelAnchorFor(String id, Size size) {
    final y = _BodyDiagramLayout.verticalPositionFor(id);
    final sidePadding = size.width * _BodyDiagramLayout.sidePaddingRatio;
    final isRight = _BodyDiagramLayout.isRightColumn(id);

    final chipLeft = isRight
        ? size.width - sidePadding - _PositionedAreaChip.chipWidth
        : sidePadding;

    final chipTop = y * size.height;

    // Left column lines start from right edge of chip.
    // Right column lines start from left edge of chip.
    final x = isRight
        ? chipLeft
        : chipLeft + _PositionedAreaChip.chipWidth;

    final centerY = chipTop + _PositionedAreaChip.chipHeight / 2;

    return Offset(x, centerY);
  }

  @override
  bool shouldRepaint(covariant _BodyConnectorPainter oldDelegate) {
    return oldDelegate.areas != areas || oldDelegate.view != view;
  }
}

class _BodyTargetPoints {
  static Offset? positionFor(String id, Size size) {
    final point = switch (id) {
      // Front view target points
      'head' => const Offset(0.50, 0.06),
      'eyes' => const Offset(0.54, 0.10),
      'throat' => const Offset(0.50, 0.17),
      'chest' => const Offset(0.48, 0.29),
      'heart' => const Offset(0.54, 0.29),
      'stomach' => const Offset(0.50, 0.43),
      'hand' => const Offset(0.66, 0.52),
      'leg' => const Offset(0.45, 0.60),
      'knees' => const Offset(0.54, 0.68),
      'toes' => const Offset(0.52, 0.94),

      // Back view target points
      'neck' => const Offset(0.50, 0.16),
      'ears' => const Offset(0.55, 0.10),
      'back' => const Offset(0.50, 0.28),
      'shoulder' => const Offset(0.61, 0.20),
      'elbow' => const Offset(0.37, 0.35),
      'lower_back' => const Offset(0.50, 0.42),
      'arm' => const Offset(0.63,0.31),
      'finger' => const Offset(0.65, 0.53),
      'lower_leg' => const Offset(0.47, 0.78),
      'ankle' => const Offset(0.53, 0.91),

      _ => null,
    };

    if (point == null) return null;

    return Offset(point.dx * size.width, point.dy * size.height);
  }
}

class _BodyDiagramLayout {
  static const double sidePaddingRatio = 0.08;

  static bool isRightColumn(String id) {
    return switch (id) {
      // Front view - right column
      'eyes' || 'heart' || 'hand' || 'knees' || 'toes' => true,

      // Back view - right column
      'ears' || 'shoulder' || 'arm' || 'finger' || 'ankle' => true,

      _ => false,
    };
  }

  static double verticalPositionFor(String id) {
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
      'lower_back' => 0.51,
      'lower_leg' => 0.73,
      'elbow' => 0.36,


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