import 'package:flutter/cupertino.dart';

import '../../core/theme/saca_theme.dart';

class SacaAppFrame extends StatelessWidget {
  const SacaAppFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: SacaTheme.background,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > SacaTheme.phoneWidth;
            final frame = ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: SacaTheme.phoneWidth),
              child: child,
            );

            if (!isWide) return frame;

            return Center(
              child: SizedBox(
                width: SacaTheme.phoneWidth,
                height: constraints.maxHeight,
                child: frame,
              ),
            );
          },
        ),
      ),
    );
  }
}
