import 'package:asmr_downloader/utils/system_proxy_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SystemProxyConfig.formatProxy', () {
    test('无代理返回 DIRECT', () {
      expect(SystemProxyConfig.formatProxy(null), 'DIRECT');
      expect(SystemProxyConfig.formatProxy(''), 'DIRECT');
      expect(SystemProxyConfig.formatProxy('   '), 'DIRECT');
      expect(SystemProxyConfig.formatProxy(';'), 'DIRECT');
      expect(SystemProxyConfig.formatProxy(' ; '), 'DIRECT');
    });

    test('单个代理', () {
      expect(
        SystemProxyConfig.formatProxy('127.0.0.1:7890'),
        'PROXY 127.0.0.1:7890; DIRECT',
      );
    });

    test('多个代理与多余空格', () {
      expect(
        SystemProxyConfig.formatProxy('127.0.0.1:7890; 10.0.0.1:8080'),
        'PROXY 127.0.0.1:7890; PROXY 10.0.0.1:8080; DIRECT',
      );
      expect(
        SystemProxyConfig.formatProxy(' 127.0.0.1:7890 ;; '),
        'PROXY 127.0.0.1:7890; DIRECT',
      );
    });
  });
}
