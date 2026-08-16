import 'dart:io';

import 'package:asmr_downloader/pages/my_app.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';
import 'package:window_manager/window_manager.dart';

Future<void> setupWindow(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows) {
    // for window acrylic, mica or transparency effects
    await Window.initialize();
    Window.setEffect(
      effect: WindowEffect.transparent,
      color: const Color(0xCC222222),
    );

    const initialSize = Size(1040, 690);
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: initialSize,
      center: true,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () {
      windowManager
        ..setMinimumSize(initialSize)
        ..setTitle('AsmrDownloader')
        ..setPreventClose(true)
        ..show();
      // 窗口显示后应用 acrylic 毛玻璃 (浅 tint, 模糊桌面清晰透出);
      // DWM 在窗口可见并首次绘制后才真正合成 backdrop,
      // 显示后 80ms 重设一次, 消除启动时延迟。
      Window.setEffect(
        effect: WindowEffect.acrylic,
        color: const Color(0x40262A33),
      );
      Future<void>.delayed(const Duration(milliseconds: 80), () {
        Window.setEffect(
          effect: WindowEffect.acrylic,
          color: const Color(0x40262A33),
        );
      });
    });
  }
}

void main(List<String> args) async {
  await setupWindow(args);
  // MCP 调试工具链 (flutter-mcp-toolkit), 仅 Windows debug 构建生效;
  // release 构建启用会导致窗口启动即最小化。
  if (kDebugMode && Platform.isWindows) {
    MCPToolkitBinding.instance
      ..initialize()
      ..initializeFlutterToolkit();
  }
  runApp(const ProviderScope(child: MyApp()));
}
