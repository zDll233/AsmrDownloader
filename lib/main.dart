import 'dart:io';

import 'package:asmr_downloader/common/const.dart';
import 'package:asmr_downloader/pages/my_app.dart';
import 'package:asmr_downloader/services/ui/launch_inputs.dart';
import 'package:asmr_downloader/services/ui/theme/theme_provider.dart';
import 'package:asmr_downloader/utils/json_storage.dart';
import 'package:asmr_downloader/utils/log.dart';
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
      // 隐藏系统原生的窗口按钮 (去掉窗口样式里的 WS_SYSMENU)。
      // 标题栏是本项目用 Flutter 自绘的 (TitleBarStyle.hidden), 但窗口样式
      // 里仍带着 WS_CAPTION/WS_SYSMENU, 最大化时 DWM 会在窗口右上角再画一套
      // 原生的 最小化/最大化/关闭 按钮; Flutter 自绘的那一套画在客户区里,
      // 最大化时客户区相对窗口有偏移, 于是两套按钮错开几个像素重叠在一起。
      // 必须在 show 之前隐藏, 否则窗口出现的第一帧会闪一下原生按钮。
      await Window.hideWindowControls();
      // 重新应用一次标题栏样式: SetWindowPos(SWP_FRAMECHANGED) 会触发 DWM
      // 按新样式重算非客户区, 让原生按钮立即消失。
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
      // 恢复上次的窗口位置/尺寸, 必须在 show 之前: waitUntilReadyToShow 会按
      // WindowOptions 的 size 再设一次, 之后在 Dart 侧恢复会被它覆盖。
      final config = await JsonStorage(filePath: 'asmr_dl_config.json').read();
      await _restoreWindowBoundsBeforeShow(config, initialSize);
      windowManager
        ..setMinimumSize(initialSize)
        ..setTitle('AsmrDownloader')
        ..setPreventClose(true)
        ..show();
      // 窗口显示后应用配置的窗口背景效果 (缺省 acrylic 毛玻璃);
      // DWM 在窗口可见并首次绘制后才真正合成 backdrop,
      // 显示后 80ms 重设一次, 消除启动时延迟。
      final effect = resolveWindowEffect(config);
      await _applyStartupWindowEffect(effect);
      Future<void>.delayed(const Duration(milliseconds: 80), () {
        _applyStartupWindowEffect(effect);
      });
    });
  }
}

/// 在窗口 show 之前恢复上次的位置/尺寸。
///
/// 必须在这里做而不是在 Initialization 里: `waitUntilReadyToShow` 内部会按
/// WindowOptions 的 size 再设一次窗口尺寸, Dart 侧稍后恢复会被它覆盖掉。
Future<void> _restoreWindowBoundsBeforeShow(
  Map<String, dynamic> config,
  Size initialSize,
) async {
  final b = config['windowBounds'];
  if (b is! Map) return;

  final rememberPos = config['rememberWindowPos'] ?? kDefaultRememberWindowPos;
  final rememberSize =
      config['rememberWindowSize'] ?? kDefaultRememberWindowSize;

  final sizeValid = b['w'] is num &&
      b['h'] is num &&
      (b['w'] as num) >= initialSize.width &&
      (b['h'] as num) >= initialSize.height;
  final posValid = b['x'] is num && b['y'] is num;

  try {
    if (rememberSize && sizeValid) {
      await windowManager.setSize(Size(
        (b['w'] as num).toDouble(),
        (b['h'] as num).toDouble(),
      ));
    }
    if (rememberPos && posValid) {
      await windowManager.setPosition(Offset(
        (b['x'] as num).toDouble(),
        (b['y'] as num).toDouble(),
      ));
    }
  } catch (e) {
    Log.error('restore window bounds failed.\n$e');
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
  // 启动时先把剪贴板抓下来: 窗口 show 之前那段空窗期里它可能已经被别的东西
  // 覆盖了。也顺手省掉了 UI 层"等 main 加载完"的 sleep。
  await captureLaunchInputs(args);
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
