import 'dart:convert';
import 'dart:io';

import 'package:logger/logger.dart';

/// 多进程安全的日志文件输出: 单文件 + 跨进程锁。
///
/// dart:io 在 Windows 上的 append 只在打开时定位到文件末尾, 之后按各句柄
/// 自己的偏移写。两个实例同时写同一个日志时, 后打开的实例和先打开的实例
/// 位置重叠, 会互相覆盖 (丢块、把 UTF-8 字符切成乱码)。
///
/// 这里每次写入都:
/// 1. 在 [lockFile] 上加独占锁 ([FileLock.blockingExclusive]), 让多个实例
///    的写入串行化;
/// 2. 持锁时检查大小, 超过 [maxBytes] 就把日志轮转成 `<file>.old`
///    (覆盖旧的 .old, 只保留一代);
/// 3. 持锁时重新打开日志, 显式定位到锁内看到的真实 EOF 再写, 写完 flush。
///
/// 每次写入都开关文件/加锁, 日志频率低, 开销可以忽略;
/// 好处是进程崩溃时不会留下未 flush 的缓冲, 也不会长期占着文件导致轮转失败。
class LockedFileOutput extends LogOutput {
  LockedFileOutput({
    required this.file,
    this.maxBytes = 5 * 1024 * 1024,
    this.encoding = utf8,
  });

  /// 目标日志文件。
  final File file;

  /// 超过这个大小就轮转成 `<file>.old`。
  final int maxBytes;

  final Encoding encoding;

  /// 跨进程锁文件 (与日志同目录, 后缀 `.lock`)。
  File get lockFile => File('${file.path}.lock');

  /// 只做同步的准备工作: `init()` 会被 Logger 异步调用, 而 [output] 可能
  /// 紧接着就被调用, 所以这里不放任何 await。
  @override
  Future<void> init() async {
    try {
      file.parent.createSync(recursive: true);
      if (!lockFile.existsSync()) {
        lockFile.createSync(recursive: true);
      }
    } catch (_) {
      // 目录不可写时留给写入时再失败, 不能把启动搞挂。
    }
  }

  @override
  void output(OutputEvent event) {
    final text = '${event.lines.join('\n')}\n';
    try {
      _append(text);
    } catch (_) {
      // 日志写失败不能影响主流程。
    }
  }

  void _append(String text) {
    RandomAccessFile? lock;
    try {
      try {
        lock = lockFile.openSync(mode: FileMode.append);
        lock.lockSync(FileLock.blockingExclusive);
      } catch (_) {
        // 某些文件系统不支持文件锁: 退化成本进程直接写, 至少别把日志丢了。
      }

      _rotateIfNeeded();

      final raf = file.openSync(mode: FileMode.writeOnlyAppend);
      try {
        // 不依赖 append 的隐式定位, 锁内显式跳到真实末尾。
        raf.setPositionSync(raf.lengthSync());
        raf.writeStringSync(text, encoding: encoding);
        raf.flushSync();
      } finally {
        raf.closeSync();
      }
    } finally {
      try {
        lock?.unlockSync();
      } catch (_) {
        // 已经随 close 释放时 unlock 会失败, 忽略。
      }
      try {
        lock?.closeSync();
      } catch (_) {
        // 忽略。
      }
    }
  }

  /// 持锁时调用: 日志超过 [maxBytes] 就重命名为 `.old`。
  ///
  /// 轮转时机在写入前, 所以 `.old` 里是"上一代"的完整日志;
  /// `.old` 已存在时 Windows 上 rename 会直接替换 (只保留一代, 有意为之)。
  void _rotateIfNeeded() {
    if (!file.existsSync()) return;
    if (file.lengthSync() <= maxBytes) return;
    try {
      file.renameSync('${file.path}.old');
    } catch (_) {
      // 被外部程序占用时 (例如正在用编辑器看日志) 本轮跳过, 下次再试。
    }
  }

  @override
  Future<void> destroy() async {
    // 每次写入都已 flush 并关闭, 无需收尾。
  }
}
