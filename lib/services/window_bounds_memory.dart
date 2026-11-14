import 'dart:async';

import 'package:asmr_downloader/utils/json_storage.dart';
import 'package:asmr_downloader/utils/log.dart';
import 'package:window_manager/window_manager.dart';

/// 窗口位置/尺寸记忆: 移动或缩放后防抖保存到 config (`windowBounds`)。
///
/// 注意: 启动时的**恢复**在 `main.dart` 的 `waitUntilReadyToShow` 回调里做,
/// 因为那里才在 `show()` 之前; 放在 Initialization 里会被
/// `waitUntilReadyToShow` 内部的 setSize 覆盖掉。
class WindowBoundsMemory extends WindowListener {
  WindowBoundsMemory(this._storage) {
    windowManager.addListener(this);
  }

  final JsonStorage _storage;
  Timer? _debounce;

  void dispose() {
    windowManager.removeListener(this);
    _debounce?.cancel();
  }

  @override
  void onWindowMove() => _scheduleSave();

  @override
  void onWindowResize() => _scheduleSave();

  void _scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _save);
  }

  Future<void> _save() async {
    try {
      final bounds = await windowManager.getBounds();
      final config = await _storage.read();
      await _storage.write({
        ...config,
        'windowBounds': {
          'x': bounds.left,
          'y': bounds.top,
          'w': bounds.width,
          'h': bounds.height,
        },
      });
    } catch (e) {
      Log.error('WindowBoundsMemory save error: $e');
    }
  }
}
