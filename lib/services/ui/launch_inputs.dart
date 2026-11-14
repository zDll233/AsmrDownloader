import 'dart:ffi';
import 'dart:io';

import 'package:asmr_downloader/services/ui/selection_reader.dart';
import 'package:asmr_downloader/utils/log.dart';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// 启动瞬间的 `GetForegroundWindow()` 结果。
///
/// 原生入口 (`windows/runner/main.cpp`) 在创建窗口之前就采集好, 再通过
/// `--launch_foreground_window=` 传进来。在 Dart 里调 `GetForegroundWindow()`
/// 已经太晚: Dart 的 `main()` 跑起来时原生窗口早就建好了 (而且一旦 show,
/// 前台窗口就是本程序自己)。
int? _launchForegroundWindow;

/// 启动瞬间选中文本的快照。
String? _launchSelectionText;

/// 启动瞬间的剪贴板文本快照。
String? _launchClipboardText;

/// 读取选中文本 (参数是窗口句柄), 仅用于统一 [captureLaunchInputs] 的入参类型。
typedef SelectionReader = Future<String?> Function(int windowHandle);

/// 读取剪贴板文本, 仅用于统一 [captureLaunchInputs] 的入参类型。
typedef ClipboardReader = String? Function();

/// 抓取"启动瞬间"的选中文本和剪贴板。
///
/// 两件事都必须在 `runApp()` 之前、窗口显示之前完成:
///  * 前台窗口句柄来自原生入口 (见 [_launchForegroundWindow]);
///  * 剪贴板读的是此刻系统里的内容。
///
/// 提前读过之后, 后面就只剩一次纯内存的回放, 不再需要在 UI 层 `sleep`
/// 一段时间来"等 main 加载完"。
///
/// [selectionReader] / [clipboardReader] 仅用于测试替换。
Future<void> captureLaunchInputs(
  List<String> entrypointArgs, {
  Duration timeout = const Duration(milliseconds: 600),
  SelectionReader? selectionReader,
  ClipboardReader? clipboardReader,
}) async {
  final SelectionReader selection = selectionReader ?? _readSelectedText;
  final ClipboardReader clipboard = clipboardReader ?? readClipboardText;

  _launchForegroundWindow = _parseForegroundWindowArg(entrypointArgs);
  if (_launchForegroundWindow != null && _launchForegroundWindow != 0) {
    Log.info(
      'launch foreground window: 0x${_launchForegroundWindow!.toRadixString(16)}',
    );
  }

  // 选区读取会跨进程调 UIA, 慢的时候可能上百毫秒; 和剪贴板一起尽早开始,
  // 让这段等待和后面的窗口初始化重叠掉。
  final Future<String?> selectionFuture =
      selection(_launchForegroundWindow ?? 0);
  _launchClipboardText = clipboard();
  // 和剪贴板并行; 超时就当"没选中", 不能拖慢启动。
  final String? selected = await _withTimeout(selectionFuture, timeout);
  _launchSelectionText = selected;
  // 空白选区 (光标停着没选东西) 当作"没选中"。
  if (_launchSelectionText != null && _launchSelectionText!.trim().isEmpty) {
    _launchSelectionText = null;
  }

  final candidate = peekLaunchCandidate();
  if (candidate != null) {
    Log.info(
      'launch candidate <- '
      '${candidate.length > 80 ? '${candidate.substring(0, 80)}...' : candidate}',
    );
  }
}

Future<String?> _readSelectedText(int windowHandle) =>
    readSelectedText(windowHandle: windowHandle);

/// 等 [future] 最多 [timeout], 超时返回 `null`。
///
/// 不用 `Future.timeout`: 它的 `onTimeout` 会被推断成非空类型, 而这里
/// "超时"的语义就是"没有结果", 返回 `null` 更直接。
Future<String?> _withTimeout(Future<String?> future, Duration timeout) {
  return Future.any<String?>([
    future,
    Future<String?>.delayed(timeout, () => null),
  ]);
}

/// 启动时的候选文本: 选中文本优先, 没有选中就退回剪贴板。
///
/// 只取值不清缓冲, 供抓取阶段打日志用。
String? peekLaunchCandidate() => _launchSelectionText ?? _launchClipboardText;

/// 取出启动时抓到的首选项 (只给启动时那一次自动搜索用, 取一次就清)。
///
/// 用户主动点"粘贴并搜索"时不该用这份快照: 那时剪贴板可能已经变了,
/// 而前台窗口也不是他要复制 sourceId 的那个程序了。
String? takeLaunchInput() {
  final candidate = peekLaunchCandidate();
  _launchSelectionText = null;
  _launchClipboardText = null;
  return candidate;
}

/// 解析原生入口传进来的前台窗口句柄。
int? _parseForegroundWindowArg(List<String> args) {
  const prefix = '--launch_foreground_window=';
  for (final arg in args) {
    if (!arg.startsWith(prefix)) continue;
    return int.tryParse(arg.substring(prefix.length));
  }
  return null;
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
