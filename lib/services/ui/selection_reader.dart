import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// 读取"当前选中文本"的抽象。
///
/// 选区读取是 Windows 专属的 Windows UI Automation 实现, 但调用方不应该
/// 依赖 FFI; 测试也可以替换成假实现。
typedef SelectedTextReader = Future<String?> Function(int windowHandle);

/// 通过 Windows UI Automation 读取指定窗口里的选中文本。
///
/// [windowHandle] 必须是调用方"此刻"采集的前台窗口 (见 `launch_inputs.dart`):
/// 本函数会把活干在独立 isolate 里, 那里再读前台窗口可能已经不是同一个了。
///
/// 返回 `null` 表示读不到 (非 Windows、目标程序不暴露选区、调用超时等),
/// 调用方据此回退到剪贴板。
Future<String?> readSelectedText({
  required int windowHandle,
  Duration timeout = const Duration(milliseconds: 300),
}) async {
  if (!Platform.isWindows || windowHandle == 0) return null;

  // 先排除本程序自己: 启动时窗口一旦 show, 前台窗口就是自己了。
  if (_isOwnProcess(windowHandle)) return null;

  return readSelectedTextOfWindow(windowHandle).timeout(
    timeout,
    onTimeout: () => null,
  );
}

/// 窗口是否属于本进程。
bool _isOwnProcess(int windowHandle) {
  final pidOut = calloc<Uint32>();
  try {
    GetWindowThreadProcessId(windowHandle, pidOut);
    return pidOut.value == GetCurrentProcessId();
  } finally {
    free(pidOut);
  }
}

/// 读取指定窗口的选中文本, 读不到返回 `null`。
///
/// 句柄必须在调用方 isolate 里采集: 本函数跑在独立 isolate 中, 那里读到的
/// "前台窗口"可能已经不是调用时那一个了。
Future<String?> readSelectedTextOfWindow(
  int windowHandle, {
  Duration timeout = const Duration(milliseconds: 300),
}) async {
  if (!Platform.isWindows || windowHandle == 0) return null;
  return Isolate.run(() => _readSelectionSync(windowHandle))
      .timeout(timeout, onTimeout: () => null);
}

/// UIA 的 COM 对象在 win32 包里是"指针的指针"约定:
/// 每个接口都要求 `this` 指向一个存放接口指针的格子, 而不是接口本身。
/// UIA 的方法通过 out 参数直接吐裸接口指针, 这里补一层包装。
Pointer<COMObject> _wrap(Pointer<COMObject> iface) {
  final cell = calloc<COMObject>();
  cell.ref.lpVtbl = Pointer<Pointer<IntPtr>>.fromAddress(iface.address);
  return cell;
}

/// 在独立 isolate 里同步读取选中文本。
///
/// 放在 isolate 里跑的原因: UIA 调用会被目标程序的响应速度拖住 (活动标签页
/// 切换、后台程序卡顿时可达数百毫秒), 不能让 UI 线程跟着卡。
String? _readSelectionSync(int windowHandle) {
  // MTA 而不是 STA: isolate 里没有消息循环, STA 的跨进程编排会死锁。
  // 句柄已经由调用方采集, 这里拿不到"调用时的前台窗口"。
  final hrInit = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
  // RPC_E_CHANGED_MODE 说明本线程已经是别的公寓模式, 仍然可以用。
  if (hrInit != S_OK && hrInit != S_FALSE && hrInit != _rpcChangedMode) {
    return null;
  }

  try {
    final automation = CUIAutomation.createInstance();
    return _selectionOfTarget(automation, windowHandle);
  } catch (_) {
    // UIA 在目标程序正忙/已退出时会抛 COM 异常, 一律当作"读不到"。
    return null;
  }
}

/// `RPC_E_CHANGED_MODE`。
const int _rpcChangedMode = -2147417850; // 0x80010106

String? _selectionOfTarget(IUIAutomation automation, int windowHandle) {
  final pidOut = calloc<Uint32>();
  try {
    GetWindowThreadProcessId(windowHandle, pidOut);
    // 读自己进程没有意义: 启动时前台窗口是资源管理器/浏览器, 不是本程序。
    if (pidOut.value == GetCurrentProcessId()) return null;
  } finally {
    free(pidOut);
  }

  final windowPtrPtr = calloc<Pointer<COMObject>>();
  try {
    if (automation.elementFromHandle(windowHandle, windowPtrPtr) != S_OK ||
        windowPtrPtr.value.address == 0) {
      return null;
    }
    final window = IUIAutomationElement(_wrap(windowPtrPtr.value));

    // 1. 焦点元素: 编辑器/文本框这类控件, 窗口元素本身没有 TextPattern。
    final focused = _focusedElementOf(automation);
    if (focused != null) {
      final text = _selectionOf(focused);
      if (_isMeaningful(text)) return text;
    }

    // 2. 窗口元素本身 (部分控件的 TextPattern 挂在窗口这一层)。
    final direct = _selectionOf(window);
    if (_isMeaningful(direct)) return direct;

    // 3. 子树里第一个支持 TextPattern 的元素: 浏览器把选区暴露在
    //    Document 元素上, 而 Document 往往不是焦点元素。
    final found = _firstTextPatternElementOf(automation, window);
    if (found != null) {
      final text = _selectionOf(found);
      if (_isMeaningful(text)) return text;
    }

    return null;
  } finally {
    free(windowPtrPtr);
  }
}

/// 读取焦点元素, 且它必须属于目标窗口所在进程。
///
/// 不加这层校验的话, 用户点了别处之后焦点会跑到本程序身上, 读出来的是
/// 我们自己的输入框内容。
IUIAutomationElement? _focusedElementOf(IUIAutomation automation) {
  final focusedPtrPtr = calloc<Pointer<COMObject>>();
  try {
    if (automation.getFocusedElement(focusedPtrPtr) != S_OK ||
        focusedPtrPtr.value.address == 0) {
      return null;
    }
    return IUIAutomationElement(_wrap(focusedPtrPtr.value));
  } finally {
    free(focusedPtrPtr);
  }
}

IUIAutomationElement? _firstTextPatternElementOf(
  IUIAutomation automation,
  IUIAutomationElement window,
) {
  final conditionPtrPtr = calloc<Pointer<COMObject>>();
  final foundPtrPtr = calloc<Pointer<COMObject>>();
  try {
    final variant = calloc<VARIANT>();
    try {
      VariantInit(variant);
      variant.ref.vt = VT_BOOL;
      variant.ref.boolVal = true;
      if (automation.createPropertyCondition(
            UIA_IsTextPatternAvailablePropertyId,
            variant.ref,
            conditionPtrPtr,
          ) !=
          S_OK) {
        return null;
      }
    } finally {
      VariantClear(variant);
      free(variant);
    }

    if (window.findFirst(
          TreeScope_Subtree,
          conditionPtrPtr.value,
          foundPtrPtr,
        ) !=
            S_OK ||
        foundPtrPtr.value.address == 0) {
      return null;
    }
    return IUIAutomationElement(_wrap(foundPtrPtr.value));
  } finally {
    free(conditionPtrPtr);
    free(foundPtrPtr);
  }
}

/// 读一个元素的当前选区; 不支持 TextPattern 或没有选区时返回 `null`。
String? _selectionOf(IUIAutomationElement element) {
  final patternPtrPtr = calloc<Pointer<COMObject>>();
  try {
    if (element.getCurrentPattern(UIA_TextPatternId, patternPtrPtr) != S_OK ||
        patternPtrPtr.value.address == 0) {
      return null;
    }
    final pattern =
        IUIAutomationTextPattern.from(IUnknown(_wrap(patternPtrPtr.value)));

    final rangesPtrPtr = calloc<Pointer<COMObject>>();
    try {
      if (pattern.getSelection(rangesPtrPtr) != S_OK ||
          rangesPtrPtr.value.address == 0) {
        return null;
      }
      final ranges = IUIAutomationTextRangeArray.from(
        IUnknown(_wrap(rangesPtrPtr.value)),
      );

      final buffer = StringBuffer();
      for (var i = 0; i < ranges.length; i++) {
        buffer.write(_textOfRange(ranges, i) ?? '');
      }
      return buffer.toString();
    } finally {
      free(rangesPtrPtr);
    }
  } finally {
    free(patternPtrPtr);
  }
}

String? _textOfRange(IUIAutomationTextRangeArray ranges, int index) {
  final rangePtrPtr = calloc<Pointer<COMObject>>();
  try {
    if (ranges.getElement(index, rangePtrPtr) != S_OK ||
        rangePtrPtr.value.address == 0) {
      return null;
    }
    final range = IUIAutomationTextRange.from(
      IUnknown(_wrap(rangePtrPtr.value)),
    );

    final textPtr = calloc<Pointer<Utf16>>();
    try {
      // -1 = 取整个范围。
      if (range.getText(-1, textPtr) != S_OK || textPtr.value.address == 0) {
        return null;
      }
      final text = textPtr.value.toDartString();
      SysFreeString(textPtr.value);
      return text;
    } finally {
      free(textPtr);
    }
  } finally {
    free(rangePtrPtr);
  }
}

/// 空白选区 (光标停着没选东西) 不算"选中的文本"。
bool _isMeaningful(String? text) => text != null && text.trim().isNotEmpty;
