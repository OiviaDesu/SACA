import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/theme/saca_theme.dart';
import '../platform/desktop_shell_policy.dart';

Future<void> configureSacaDesktopWindow() async {
  if (!DesktopShellPolicy.supportsManagedWindow(defaultTargetPlatform)) return;

  await windowManager.ensureInitialized();

  const options = WindowOptions(
    size: Size(1240, 780),
    minimumSize: Size(430, 560),
    center: true,
    backgroundColor: SacaTheme.background,
    skipTaskbar: false,
    title: 'SACA',
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );

  unawaited(
    windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.setAsFrameless();
      await windowManager.setResizable(true);
      await windowManager.setHasShadow(true);
      await windowManager.show();
      await windowManager.focus();
    }),
  );
}
