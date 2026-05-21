import 'package:flutter/cupertino.dart';

class SacaLogoHeader extends StatelessWidget {
  const SacaLogoHeader({
    super.key,
    this.compact = false,
    this.lift = 0,
  });

  final bool compact;
  final double lift;

  @override
  Widget build(BuildContext context) {
    final height = compact ? 118.0 : 190.0;
    final logoWidth = compact ? 170.0 : 240.0;

    return Transform.translate(
      offset: Offset(0, -lift),
      child: SizedBox(
        height: height,
        child: Center(
          child: Semantics(
            label: 'SACA',
            image: true,
            child: ExcludeSemantics(
              child: Image.asset(
                'assets/branding/SACA_logo.png',
                width: logoWidth,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
