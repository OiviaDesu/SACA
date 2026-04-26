import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

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
    return DragToMoveArea(child: child);
  }
}

Future<void> minimizeDesktopWindow() => windowManager.minimize();

Future<void> toggleMaximizeDesktopWindow() async {
  if (await windowManager.isMaximized()) {
    await windowManager.unmaximize();
    return;
  }
  await windowManager.maximize();
}

Future<void> closeDesktopWindow() => windowManager.close();

Future<void> resizeDesktopWindow(DesktopResizeEdge edge) {
  return windowManager.startResizing(switch (edge) {
    DesktopResizeEdge.top => ResizeEdge.top,
    DesktopResizeEdge.topRight => ResizeEdge.topRight,
    DesktopResizeEdge.right => ResizeEdge.right,
    DesktopResizeEdge.bottomRight => ResizeEdge.bottomRight,
    DesktopResizeEdge.bottom => ResizeEdge.bottom,
    DesktopResizeEdge.bottomLeft => ResizeEdge.bottomLeft,
    DesktopResizeEdge.left => ResizeEdge.left,
    DesktopResizeEdge.topLeft => ResizeEdge.topLeft,
  });
}
