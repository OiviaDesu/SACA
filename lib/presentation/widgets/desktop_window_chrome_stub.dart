import 'package:flutter/widgets.dart';

enum DesktopResizeEdge {
  top,
  topRight,
  right,
  bottomRight,
  bottom,
  bottomLeft,
  left,
  topLeft,
}

class DesktopDragArea extends StatelessWidget {
  const DesktopDragArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

Future<void> minimizeDesktopWindow() async {}

Future<void> toggleMaximizeDesktopWindow() async {}

Future<void> closeDesktopWindow() async {}

Future<void> resizeDesktopWindow(DesktopResizeEdge edge) async {}
