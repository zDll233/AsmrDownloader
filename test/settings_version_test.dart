import 'package:asmr_downloader/common/config_providers.dart';
import 'package:asmr_downloader/pages/settings/settings_page.dart';
import 'package:asmr_downloader/services/updater/update_checker.dart';
import 'package:asmr_downloader/utils/json_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 内存版配置存储, 避免 widget 测试里做真实文件 IO。
class _MemStorage extends JsonStorage {
  _MemStorage() : super(filePath: 'settings_version_test_config.json');

  @override
  Future<Map<String, dynamic>> read() async => <String, dynamic>{};

  @override
  Future<void> write(Map<String, dynamic> data) async {}

  @override
  Future<void> addOrUpdate(Map<String, dynamic> data) async {}
}

void main() {
  testWidgets('设置界面"检查更新"处展示版本号 (发布版带 v 前缀)', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [configFileProvider.overrideWithValue(_MemStorage())],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    const injected = String.fromEnvironment('APP_VERSION', defaultValue: '');
    final expected = injected.isEmpty ? '当前版本 dev' : '当前版本 $injected';

    expect(kAppVersion, injected.isEmpty ? 'dev' : injected);
    expect(find.text(expected), findsOneWidget);

    // 发布构建 (CI 注入 tag) 必须展示 v 前缀, 如 "当前版本 v0.2.11"
    if (injected.isNotEmpty) {
      expect(expected, startsWith('当前版本 v'));
      expect(expected, isNot(contains('dev')));
    }
  });
}
