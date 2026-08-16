import 'dart:io';

import 'package:asmr_downloader/common/const.dart';
import 'package:asmr_downloader/pages/my_app.dart';
import 'package:asmr_downloader/services/ui/theme/theme_provider.dart';
import 'package:asmr_downloader/utils/json_storage.dart';
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
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      windowManager
        ..setMinimumSize(initialSize)
        ..setTitle('AsmrDownloader')
        ..setPreventClose(true)
        ..show();
      // 窗口显示后应用配置的窗口背景效果 (缺省 acrylic 毛玻璃);
      // DWM 在窗口可见并首次绘制后才真正合成 backdrop,
      // 显示后 80ms 重设一次, 消除启动时延迟。
      final config = await JsonStorage(filePath: 'asmr_dl_config.json').read();
      final effect = resolveWindowEffect(config);
      await _applyStartupWindowEffect(effect);
      Future<void>.delayed(const Duration(milliseconds: 80), () {
        _applyStartupWindowEffect(effect);
      });
    });
  }
}

Future<void> _applyStartupWindowEffect(String effect) async {
  try {
    switch (effect) {
      case WINDOW_EFFECT_TRANSPARENT:
        await Window.setEffect(
          effect: WindowEffect.transparent,
          color: const Color(0xCC222222),
        );
      case WINDOW_EFFECT_OPAQUE:
        await Window.setEffect(
          effect: WindowEffect.solid,
          color: const Color(0xFF1E1E28),
        );
      default: // WINDOW_EFFECT_ACRYLIC
        await Window.setEffect(
          effect: WindowEffect.acrylic,
          color: const Color(0x40262A33),
        );
    }
  } catch (e) {
    // ignore: 启动时效果应用失败不影响使用
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
