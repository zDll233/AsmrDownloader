import 'package:asmr_downloader/services/ui/launch_inputs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 每个用例结束都把快照取干净, 避免全局状态串味。
  tearDown(takeLaunchInput);

  group('captureLaunchInputs', () {
    test('抓到剪贴板文本', () async {
      await captureLaunchInputs(
        const [],
        clipboardReader: () => 'RJ01234567',
      );

      expect(takeLaunchInput(), 'RJ01234567');
    });

    test('剪贴板为空时返回 null', () async {
      await captureLaunchInputs(
        const [],
        clipboardReader: () => null,
      );

      expect(takeLaunchInput(), isNull);
    });

    test('快照只取一次, 第二次就是空了', () async {
      await captureLaunchInputs(
        const [],
        clipboardReader: () => 'RJ01234567',
      );

      expect(takeLaunchInput(), 'RJ01234567');
      expect(takeLaunchInput(), isNull);
    });

    test('带首尾空白的剪贴板内容原样保留 (由搜索侧归一化)', () async {
      await captureLaunchInputs(
        const [],
        clipboardReader: () => '  RJ01234567\n',
      );

      expect(takeLaunchInput(), '  RJ01234567\n');
    });

    test('传入的命令行参数不影响剪贴板抓取', () async {
      // 曾经的 --launch_foreground_window 参数已不再使用, 传了也不该出错
      await captureLaunchInputs(
        const ['--launch_foreground_window=12345'],
        clipboardReader: () => 'RJ01234567',
      );

      expect(takeLaunchInput(), 'RJ01234567');
    });
  });
}
