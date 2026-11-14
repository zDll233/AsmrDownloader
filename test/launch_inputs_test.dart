import 'package:asmr_downloader/services/ui/launch_inputs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 每个用例结束都把快照取干净, 避免全局状态串味。
  tearDown(takeLaunchInput);

  /// 带上原生入口传进来的窗口句柄参数。
  const args = ['--launch_foreground_window=12345'];

  group('captureLaunchInputs', () {
    test('选中文本优先于剪贴板', () async {
      await captureLaunchInputs(
        args,
        selectionReader: (_) async => 'RJ01234567',
        clipboardReader: () => 'RJ99999999',
      );

      expect(takeLaunchInput(), 'RJ01234567');
    });

    test('没有选中文本时用剪贴板', () async {
      await captureLaunchInputs(
        args,
        selectionReader: (_) async => null,
        clipboardReader: () => 'RJ01234567',
      );

      expect(takeLaunchInput(), 'RJ01234567');
    });

    test('空白选区当作没选中, 退回剪贴板', () async {
      await captureLaunchInputs(
        args,
        selectionReader: (_) async => '  \n\t ',
        clipboardReader: () => 'RJ01234567',
      );

      expect(takeLaunchInput(), 'RJ01234567');
    });

    test('选区读取超时不会拖住启动, 且退回剪贴板', () async {
      final stopwatch = Stopwatch()..start();
      await captureLaunchInputs(
        args,
        timeout: const Duration(milliseconds: 50),
        selectionReader: (_) async {
          await Future<void>.delayed(const Duration(seconds: 10));
          return 'RJ01234567';
        },
        clipboardReader: () => 'RJ99999999',
      );
      stopwatch.stop();

      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
      expect(takeLaunchInput(), 'RJ99999999');
    });

    test('两者都没有时返回 null', () async {
      await captureLaunchInputs(
        args,
        selectionReader: (_) async => null,
        clipboardReader: () => null,
      );

      expect(takeLaunchInput(), isNull);
    });

    test('快照只取一次, 第二次就是空了', () async {
      await captureLaunchInputs(
        args,
        selectionReader: (_) async => 'RJ01234567',
        clipboardReader: () => null,
      );

      expect(takeLaunchInput(), 'RJ01234567');
      expect(takeLaunchInput(), isNull);
    });

    test('把命令行里的窗口句柄传给选区读取', () async {
      int? received;
      await captureLaunchInputs(
        args,
        selectionReader: (windowHandle) async {
          received = windowHandle;
          return null;
        },
        clipboardReader: () => null,
      );

      expect(received, 12345);
    });

    test('没有句柄参数时传 0 (选区读取会直接放弃)', () async {
      int? received;
      await captureLaunchInputs(
        const [],
        selectionReader: (windowHandle) async {
          received = windowHandle;
          return null;
        },
        clipboardReader: () => 'RJ01234567',
      );

      expect(received, 0);
      expect(takeLaunchInput(), 'RJ01234567');
    });
  });
}
