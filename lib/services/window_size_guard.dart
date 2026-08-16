import 'dart:async';

import 'package:asmr_downloader/utils/log.dart';
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

/// 防御: Flutter Windows 引擎的 view 尺寸偶发与窗口不同步
/// (内容渲染在窗口一角/偏小, 其余区域空白, 反复出现且无法稳定复现)。
/// 启动后渲染完成时检查一次窗口尺寸与 view 尺寸, 发现偏差时强制触发
/// 一次 resize, 让引擎重新同步 view 尺寸 (只做一次, 不做周期轮询)。
/// 移植自 Again 项目。
class WindowSizeGuard {
  WindowSizeGuard() {
    // 启动后等渲染稳定, 只检查一次
    _timer = Timer(const Duration(seconds: 2), () => _check());
  }

  Timer? _timer;

  Future<void> _check() async {
    try {
      // 窗口不可见 (托盘隐藏/最小化) 时跳过
      if (!await windowManager.isVisible()) return;
      final views = WidgetsBinding.instance.platformDispatcher.views;
      if (views.isEmpty) return;
      final view = views.first;
      final dpr = view.devicePixelRatio;
      final windowSize = await windowManager.getSize();
      if (windowSize.width <= 0 || windowSize.height <= 0) return;
      final expected =
          Size(windowSize.width * dpr, windowSize.height * dpr);
      final actual = view.physicalSize;
      if ((expected.width - actual.width).abs() > 2 ||
          (expected.height - actual.height).abs() > 2) {
        Log.info(
            'WindowSizeGuard: view=$actual expected=$expected dpr=$dpr -> resync');
        // 相同尺寸的 SetWindowPos 可能被 Windows 跳过 (不发 WM_SIZE),
        // 先 +1 再恢复, 确保引擎收到尺寸变化
        await windowManager
            .setSize(Size(windowSize.width + 1, windowSize.height + 1));
        await windowManager.setSize(windowSize);
      }
    } catch (e) {
      Log.error('WindowSizeGuard error: $e');
    }
  }

  void dispose() {
    _timer?.cancel();
  }
}
