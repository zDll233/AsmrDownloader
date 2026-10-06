import 'package:asmr_downloader/services/updater/update_checker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('compareVersions', () {
    test('忽略 v 前缀', () {
      expect(compareVersions('v0.2.10', '0.2.10'), 0);
      expect(compareVersions('0.2.10', 'v0.2.10'), 0);
    });

    test('按段比较', () {
      expect(compareVersions('v0.2.11', 'v0.2.10'), greaterThan(0));
      expect(compareVersions('v0.2.9', 'v0.2.10'), lessThan(0));
      expect(compareVersions('v0.3', 'v0.2.11'), greaterThan(0));
      expect(compareVersions('v1.0.0', 'v0.2.11'), greaterThan(0));
      expect(compareVersions('v0.2.11', 'v0.2.11'), 0);
    });

    test('段数不同时按 0 补齐', () {
      expect(compareVersions('v1.0', 'v1.0.0'), 0);
      expect(compareVersions('v1.0.1', 'v1.0'), greaterThan(0));
    });

    test('两位数十位数比较 (0.2.10 vs 0.2.9)', () {
      expect(compareVersions('v0.2.10', 'v0.2.9'), greaterThan(0));
    });
  });

  group('kAppVersion', () {
    test('注入 dart-define 时保留 tag 原文 (设置界面展示 v0.2.11 形式)', () {
      const injected = String.fromEnvironment('APP_VERSION', defaultValue: '');
      if (injected.isEmpty) {
        // 本地构建未注入
        expect(kAppVersion, 'dev');
      } else {
        expect(kAppVersion, injected);
        expect(kAppVersion, startsWith('v'));
      }
    });

    test('版本比较忽略 v 前缀', () {
      expect(compareVersions('v0.2.11', '0.2.11'), 0);
      expect(compareVersions('0.2.11', 'v0.2.11'), 0);
    });
  });

  group('UpdateCheckResult.hasUpdate', () {
    test('更高 tag 视为有更新', () {
      const result = UpdateCheckResult(latestTag: 'v99.0.0');
      expect(result.hasUpdate, isTrue);
    });

    test('与当前版本相同则无更新', () {
      final tag = kAppVersion.startsWith('v') ? kAppVersion : 'v$kAppVersion';
      expect(UpdateCheckResult(latestTag: tag).hasUpdate, isFalse);
    });
  });
}
