import 'package:asmr_downloader/common/config_providers.dart';
import 'package:asmr_downloader/pages/settings/settings_page.dart';
import 'package:asmr_downloader/utils/json_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 内存版配置存储, 记录写入内容供断言。
class _MemStorage extends JsonStorage {
  _MemStorage([Map<String, dynamic>? initial])
      : _data = {...?initial},
        super(filePath: 'settings_options_test_config.json');

  Map<String, dynamic> _data;

  Map<String, dynamic> get data => _data;

  @override
  Future<Map<String, dynamic>> read() async => {..._data};

  @override
  Future<void> write(Map<String, dynamic> value) async {
    _data = {...value};
  }

  @override
  Future<void> addOrUpdate(Map<String, dynamic> value) async {
    _data = {..._data, ...value};
  }
}

void main() {
  setUp(() {
    // windows_taskbar 的通道在测试环境没有实现, 不 mock 会让调用的 Future
    // 一直挂着。
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.alexmercerind/windows_taskbar'),
      (call) async => null,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.alexmercerind/windows_taskbar'),
      null,
    );
  });

  Future<_MemStorage> pumpSettings(
    WidgetTester tester, {
    Map<String, dynamic>? initial,
  }) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final storage = _MemStorage(initial);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [configFileProvider.overrideWithValue(storage)],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();
    return storage;
  }

  group('设置页新选项', () {
    testWidgets('窗口分组里有"记住窗口位置/大小"两个开关', (tester) async {
      await pumpSettings(tester);

      expect(find.text('记住窗口位置'), findsOneWidget);
      expect(find.text('记住窗口大小'), findsOneWidget);
    });

    testWidgets('默认值照搬 Again: 位置关、大小开', (tester) async {
      await pumpSettings(tester);

      // 窗口卡片里的前两个 Switch: 位置 (默认关)、大小 (默认开)。
      // 第三个是"扩展名过滤条", 不在这里断言。
      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switches.length, greaterThanOrEqualTo(2));
      expect(switches[0].value, isFalse);
      expect(switches[1].value, isTrue);
    });

    testWidgets('切换"记住窗口位置"会写入配置', (tester) async {
      final storage = await pumpSettings(tester);

      await tester.tap(find.byType(Switch).at(0));
      await tester.pumpAndSettle();

      expect(storage.data['rememberWindowPos'], isTrue);
    });

    testWidgets('已有配置里的开关值会被读出来', (tester) async {
      await pumpSettings(tester, initial: {
        'rememberWindowPos': true,
        'rememberWindowSize': false,
      });

      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switches[0].value, isTrue);
      expect(switches[1].value, isFalse);
    });

    testWidgets('外观分组里有主题色入口', (tester) async {
      await pumpSettings(tester);

      expect(find.text('外观'), findsOneWidget);
      expect(find.text('主题色'), findsOneWidget);
    });

    testWidgets('点击主题色会打开颜色选择对话框', (tester) async {
      await pumpSettings(tester);

      await tester.tap(find.text('主题色'));
      await tester.pumpAndSettle();

      expect(find.text('选择颜色'), findsOneWidget);
      expect(find.text('预设'), findsOneWidget);

      // 取消关闭, 不改配置
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.text('选择颜色'), findsNothing);
    });

    testWidgets('在颜色对话框里选色并确定, 会写入 themeSeedColor', (tester) async {
      final storage = await pumpSettings(tester);

      await tester.tap(find.text('主题色'));
      await tester.pumpAndSettle();

      // 点一个预设色块 (预设第一项是红色 #F44336), 再确定
      // 色块是 InkWell 包着的方形, 用 ColorPickerDialog.presets 的坐标定位
      final swatches = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(InkWell),
      );
      expect(swatches, findsWidgets);
      await tester.tap(swatches.first);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, '确定'));
      await tester.pumpAndSettle();

      expect(find.text('选择颜色'), findsNothing);
      // 写入的应当是合法 #RRGGBB
      final written = storage.data['themeSeedColor'] as String?;
      expect(written, isNotNull);
      expect(written, matches(RegExp(r'^#[0-9A-F]{6}$')));
    });

    testWidgets('危险操作里有"重置所有设置"', (tester) async {
      await pumpSettings(tester);

      expect(find.text('重置所有设置'), findsOneWidget);
    });

    testWidgets('设置项顺序与 Again 一致 (窗口记忆在背景效果之前)', (tester) async {
      await pumpSettings(tester);

      final posY = tester.getTopLeft(find.text('记住窗口位置')).dy;
      final sizeY = tester.getTopLeft(find.text('记住窗口大小')).dy;
      final effectY = tester.getTopLeft(find.text('窗口背景效果')).dy;

      expect(posY, lessThan(sizeY));
      expect(sizeY, lessThan(effectY));
    });

    testWidgets('重置所有设置用 Again 同款图标 (restart_alt)', (tester) async {
      await pumpSettings(tester);

      // 图标挂在"重置所有设置"这一行的 ListTile 上
      final tile = find.ancestor(
        of: find.text('重置所有设置'),
        matching: find.byType(ListTile),
      );
      expect(tile, findsOneWidget);
      final icon = tester.widget<Icon>(
        find.descendant(of: tile, matching: find.byType(Icon)),
      );
      expect(icon.icon, Icons.restart_alt);
    });

    testWidgets('检查更新与重置是两张独立卡片, 且不带分节标题', (tester) async {
      await pumpSettings(tester);

      // Again 里最后两项目前没有"关于"/"危险操作"这类标题
      expect(find.text('关于'), findsNothing);
      expect(find.text('危险操作'), findsNothing);
      expect(find.text('检查更新'), findsOneWidget);
      expect(find.text('重置所有设置'), findsOneWidget);
    });
  });

  group('重置所有设置', () {
    testWidgets('二次确认后清空配置, 但保留下载路径', (tester) async {
      final storage = await pumpSettings(tester, initial: {
        'themeSeedColor': '#00BCD4',
        'windowEffect': 'opaque',
        'rememberWindowPos': true,
        'dlPath': 'D:/asmr',
      });

      await tester.tap(find.text('重置所有设置'));
      await tester.pumpAndSettle();

      // 确认对话框
      expect(find.text('将恢复所有设置的默认值, 包括主题色、窗口效果、窗口记忆等。确定继续吗?'),
          findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, '重置'));
      await tester.pumpAndSettle();

      // 自定义设置都被清掉
      expect(storage.data['themeSeedColor'], isNull);
      expect(storage.data['windowEffect'], isNull);
      expect(storage.data['rememberWindowPos'], isNull);
      // 下载路径保留
      expect(storage.data['dlPath'], 'D:/asmr');
      // 界面回到默认值
      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switches[0].value, isFalse);
      expect(switches[1].value, isTrue);
    });

    testWidgets('取消重置时配置不变', (tester) async {
      final storage = await pumpSettings(tester, initial: {
        'themeSeedColor': '#00BCD4',
        'rememberWindowPos': true,
      });

      await tester.tap(find.text('重置所有设置'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '取消'));
      await tester.pumpAndSettle();

      expect(storage.data['themeSeedColor'], '#00BCD4');
      expect(storage.data['rememberWindowPos'], isTrue);
    });
  });
}
