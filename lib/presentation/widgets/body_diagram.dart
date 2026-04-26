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

    return SizedBox(
      height: 470,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _BodyPainter(view: view)),
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
          width: label.length > 12 ? 118 : 92,
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
      'head' => const Offset(0.03, 0.04),
      'eyes' => const Offset(0.74, 0.04),
      'throat' => const Offset(0.03, 0.18),
      'heart' => const Offset(0.74, 0.18),
      'chest' => const Offset(0.03, 0.31),
      'stomach' => const Offset(0.03, 0.50),
      'hand' => const Offset(0.74, 0.52),
      'leg' => const Offset(0.03, 0.68),
      'knees' => const Offset(0.74, 0.70),
      'toes' => const Offset(0.74, 0.88),
      'ears' => const Offset(0.74, 0.04),
      'neck' => const Offset(0.03, 0.16),
      'shoulder' => const Offset(0.72, 0.16),
      'back' => const Offset(0.03, 0.31),
      'arm' => const Offset(0.74, 0.31),
      'lower_back' => const Offset(0.03, 0.48),
      'finger' => const Offset(0.72, 0.58),
      'lower_leg' => const Offset(0.03, 0.70),
      'ankle' => const Offset(0.03, 0.87),
      _ => const Offset(0.05, 0.05),
    };
  }
}

class _BodyPainter extends CustomPainter {
  const _BodyPainter({required this.view});

  final BodyView view;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0xFF98B6BD)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = const Color(0x33D9EEF7)
      ..style = PaintingStyle.fill;

    final centerX = size.width * 0.52;
    final top = size.height * 0.08;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX, top + 46),
        width: 58,
        height: 76,
      ),
      fill,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX, top + 46),
        width: 58,
        height: 76,
      ),
      line,
    );

    final torso = Path()
      ..moveTo(centerX - 46, top + 86)
      ..quadraticBezierTo(centerX - 58, top + 160, centerX - 44, top + 236)
      ..quadraticBezierTo(centerX, top + 264, centerX + 44, top + 236)
      ..quadraticBezierTo(centerX + 58, top + 160, centerX + 46, top + 86)
      ..close();
    canvas.drawPath(torso, fill);
    canvas.drawPath(torso, line);

    canvas.drawLine(
      Offset(centerX - 46, top + 110),
      Offset(centerX - 96, top + 245),
      line,
    );
    canvas.drawLine(
      Offset(centerX + 46, top + 110),
      Offset(centerX + 96, top + 245),
      line,
    );
    canvas.drawLine(
      Offset(centerX - 18, top + 254),
      Offset(centerX - 32, top + 390),
      line,
    );
    canvas.drawLine(
      Offset(centerX + 18, top + 254),
      Offset(centerX + 32, top + 390),
      line,
    );
    canvas.drawLine(
      Offset(centerX, top + 260),
      Offset(centerX, top + 388),
      line,
    );

    if (view == BodyView.front) {
      canvas.drawLine(
        Offset(centerX - 10, top + 145),
        Offset(centerX + 24, top + 145),
        line,
      );
      canvas.drawCircle(Offset(centerX + 26, top + 136), 5, line);
    } else {
      canvas.drawLine(
        Offset(centerX, top + 110),
        Offset(centerX, top + 238),
        line,
      );
      canvas.drawLine(
        Offset(centerX - 38, top + 150),
        Offset(centerX + 38, top + 150),
        line,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BodyPainter oldDelegate) {
    return oldDelegate.view != view;
  }
}
