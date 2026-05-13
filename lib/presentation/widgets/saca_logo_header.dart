import 'package:flutter/cupertino.dart';

import '../../core/theme/saca_theme.dart';

class SacaLogoHeader extends StatelessWidget {
  const SacaLogoHeader({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = SacaThemeColors.of(context);
    final height = compact ? 118.0 : 190.0;
    final logoSize = compact ? 46.0 : 56.0;

    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Align(
            alignment: compact ? Alignment.topCenter : Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SACA',
                  style: SacaTheme.logoText.copyWith(
                    fontSize: logoSize,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Smart Adaptive Clinical Assistant',
                  textAlign: TextAlign.center,
                  style: SacaTheme.small.copyWith(
                    color: colors.onSurfaceMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: compact ? 38 : 44,
            top: compact ? 28 : 82,
            child: SizedBox(
              width: compact ? 88 : 112,
              height: compact ? 58 : 74,
              child: CustomPaint(painter: _StethoscopePainter()),
            ),
          ),
        ],
      ),
    );
  }
}

class _StethoscopePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final tube = Paint()
      ..color = const Color(0xFF9ED2DE)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final metal = Paint()
      ..color = const Color(0xFF2A3B40)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = const Color(0xFFE9FAFC)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width * 0.1, size.height * 0.08)
      ..cubicTo(
        size.width * 0.35,
        size.height * 0.1,
        size.width * 0.47,
        size.height * 0.5,
        size.width * 0.62,
        size.height * 0.54,
      )
      ..cubicTo(
        size.width * 0.8,
        size.height * 0.58,
        size.width * 0.82,
        size.height * 0.82,
        size.width * 0.62,
        size.height * 0.86,
      );
    canvas.drawPath(path, tube);

    canvas.drawCircle(
      Offset(size.width * 0.6, size.height * 0.72),
      size.width * 0.18,
      fill,
    );
    canvas.drawCircle(
      Offset(size.width * 0.6, size.height * 0.72),
      size.width * 0.18,
      metal,
    );
    canvas.drawCircle(
      Offset(size.width * 0.6, size.height * 0.72),
      size.width * 0.08,
      metal,
    );
    canvas.drawLine(
      Offset(size.width * 0.78, size.height * 0.72),
      Offset(size.width * 0.98, size.height * 0.62),
      metal,
    );
    canvas.drawLine(
      Offset(size.width * 0.07, size.height * 0.07),
      const Offset(0, 0),
      metal,
    );
    canvas.drawLine(
      Offset(size.width * 0.13, size.height * 0.07),
      Offset(size.width * 0.24, 0),
      metal,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
