import 'dart:ffi';
import 'dart:io';

import 'package:asmr_downloader/utils/log.dart';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// 启动瞬间的剪贴板文本快照。
String? _launchClipboardText;

/// 读剪贴板文本, 仅用于统一 [captureLaunchInputs] 的入参类型 (测试替换)。
typedef ClipboardReader = String? Function();

/// 在 `runApp()` 之前、窗口显示之前把剪贴板内容抓下来。
///
/// 之前还尝试过用 UI Automation 读"用户选中的文本", 已移除: 真实启动路径上
/// (点图标/点任务栏) 前台窗口会先落到 Explorer 或本程序, 而且 Chromium 只在
/// 自己的窗口处于前台时才暴露选区, 这条路径实际几乎读不到东西。
///
/// [clipboardReader] 仅用于测试替换。
Future<void> captureLaunchInputs(
  List<String> entrypointArgs, {
  ClipboardReader? clipboardReader,
}) async {
  final ClipboardReader clipboard = clipboardReader ?? readClipboardText;
  _launchClipboardText = clipboard();

  final candidate = _launchClipboardText;
  if (candidate != null && candidate.trim().isNotEmpty) {
    Log.info(
      'launch clipboard <- '
      '${candidate.length > 80 ? '${candidate.substring(0, 80)}...' : candidate}',
    );
  }
}

/// 取出启动时抓到的剪贴板文本 (只给启动时那一次自动搜索用, 取一次即清)。
///
/// 用户主动点"粘贴并搜索"时不该用这份快照: 那时剪贴板可能已经变了, 应该
/// 读实时的内容。
String? takeLaunchInput() {
  final candidate = _launchClipboardText;
  _launchClipboardText = null;
  return candidate;
}

/// 读剪贴板里的文本, 读不到返回 `null`。
///
/// 走原生 API 而不是 `Clipboard.getData`: 那个通道要等 Flutter 引擎和
/// 平台通道都就绪, 启动时读到的不一定是"启动那一刻"的内容。
String? readClipboardText() {
  if (!Platform.isWindows) return null;

  for (var attempt = 0; attempt < 3; attempt++) {
    if (OpenClipboard(0) == 0) {
      // 别的程序正占用剪贴板, 稍等重试。
      sleep(const Duration(milliseconds: 10));
      continue;
    }
    try {
      if (IsClipboardFormatAvailable(CF_UNICODETEXT) == 0) return null;
      final handle = GetClipboardData(CF_UNICODETEXT);
      if (handle == 0) return null;

      final handlePtr = Pointer.fromAddress(handle);
      final textPtr = GlobalLock(handlePtr);
      if (textPtr.address == 0) return null;
      try {
        return textPtr.cast<Utf16>().toDartString();
      } finally {
        GlobalUnlock(handlePtr);
      }
    } finally {
      CloseClipboard();
    }
  }
  return null;
}
