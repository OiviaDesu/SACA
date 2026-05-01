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
                      child: CustomPaint(
                        painter: _BodyPanelPainter(view: view),
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

class _BodyPanelPainter extends CustomPainter {
  const _BodyPanelPainter({required this.view});

  final BodyView view;

  @override
  void paint(Canvas canvas, Size size) {
    final panel = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFDF8F6),
          Color(0xFFF2FBFD),
        ],
      ).createShader(Offset.zero & size);
    final guide = Paint()
      ..color = const Color(0xFFD9E7EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final frame = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(22),
    );
    canvas.drawRRect(frame, panel);
    canvas.drawRRect(frame, guide);

    final silhouetteFill = Paint()
      ..color = const Color(0x22B9DCEA)
      ..style = PaintingStyle.fill;
    final silhouetteLine = Paint()
      ..color = const Color(0xFF8FAAB0)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final centerX = size.width * 0.52;
    final top = size.height * 0.06;

    final head = Rect.fromCenter(
      center: Offset(centerX, top + size.height * 0.10),
      width: size.width * 0.16,
      height: size.height * 0.14,
    );
    canvas.drawOval(head, silhouetteFill);
    canvas.drawOval(head, silhouetteLine);

    final shoulderY = top + size.height * 0.18;
    final hipY = top + size.height * 0.54;
    final legEndY = top + size.height * 0.90;
    final bodyWidth = size.width * 0.18;
    final armReach = size.width * 0.13;

    final torso = Path()
      ..moveTo(centerX - bodyWidth, shoulderY)
      ..quadraticBezierTo(
        centerX - bodyWidth * 1.25,
        shoulderY + size.height * 0.08,
        centerX - bodyWidth * 0.92,
        hipY,
      )
      ..quadraticBezierTo(
        centerX - bodyWidth * 0.15,
        hipY + size.height * 0.03,
        centerX,
        hipY,
      )
      ..quadraticBezierTo(
        centerX + bodyWidth * 0.15,
        hipY + size.height * 0.03,
        centerX + bodyWidth * 0.92,
        hipY,
      )
      ..quadraticBezierTo(
        centerX + bodyWidth * 1.25,
        shoulderY + size.height * 0.08,
        centerX + bodyWidth,
        shoulderY,
      )
      ..close();
    canvas.drawPath(torso, silhouetteFill);
    canvas.drawPath(torso, silhouetteLine);

    final leftArm = Path()
      ..moveTo(centerX - bodyWidth, shoulderY + size.height * 0.02)
      ..quadraticBezierTo(
        centerX - bodyWidth - armReach,
        shoulderY + size.height * 0.16,
        centerX - bodyWidth * 1.05,
        shoulderY + size.height * 0.38,
      )
      ..quadraticBezierTo(
        centerX - bodyWidth * 0.9,
        shoulderY + size.height * 0.46,
        centerX - bodyWidth * 0.85,
        shoulderY + size.height * 0.54,
      );
    final rightArm = Path()
      ..moveTo(centerX + bodyWidth, shoulderY + size.height * 0.02)
      ..quadraticBezierTo(
        centerX + bodyWidth + armReach,
        shoulderY + size.height * 0.16,
        centerX + bodyWidth * 1.05,
        shoulderY + size.height * 0.38,
      )
      ..quadraticBezierTo(
        centerX + bodyWidth * 0.9,
        shoulderY + size.height * 0.46,
        centerX + bodyWidth * 0.85,
        shoulderY + size.height * 0.54,
      );
    canvas.drawPath(leftArm, silhouetteLine);
    canvas.drawPath(rightArm, silhouetteLine);

    final leftLeg = Path()
      ..moveTo(centerX - size.width * 0.04, hipY)
      ..quadraticBezierTo(
        centerX - size.width * 0.09,
        hipY + size.height * 0.20,
        centerX - size.width * 0.07,
        legEndY,
      );
    final rightLeg = Path()
      ..moveTo(centerX + size.width * 0.04, hipY)
      ..quadraticBezierTo(
        centerX + size.width * 0.09,
        hipY + size.height * 0.20,
        centerX + size.width * 0.07,
        legEndY,
      );
    canvas.drawPath(leftLeg, silhouetteLine);
    canvas.drawPath(rightLeg, silhouetteLine);

    if (view == BodyView.front) {
      canvas.drawLine(
        Offset(centerX - size.width * 0.03, shoulderY + size.height * 0.10),
        Offset(centerX + size.width * 0.05, shoulderY + size.height * 0.10),
        silhouetteLine,
      );
      canvas.drawCircle(
        Offset(centerX + size.width * 0.05, shoulderY + size.height * 0.08),
        5,
        silhouetteLine,
      );
    } else {
      canvas.drawLine(
        Offset(centerX, shoulderY + size.height * 0.01),
        Offset(centerX, hipY - size.height * 0.01),
        silhouetteLine,
      );
      canvas.drawLine(
        Offset(centerX - size.width * 0.07, shoulderY + size.height * 0.12),
        Offset(centerX + size.width * 0.07, shoulderY + size.height * 0.12),
        silhouetteLine,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BodyPanelPainter oldDelegate) {
    return oldDelegate.view != view;
  }
}
