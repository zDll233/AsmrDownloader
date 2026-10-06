import 'package:asmr_downloader/common/config_providers.dart';
import 'package:asmr_downloader/pages/downloader/config_settings/components/asmr_proxy.dart';
import 'package:asmr_downloader/services/asmr_repo/asmr_api.dart';
import 'package:asmr_downloader/services/asmr_repo/providers/api_providers.dart';
import 'package:asmr_downloader/services/ui/system_proxy_reader.dart';
import 'package:asmr_downloader/utils/json_storage.dart';
import 'package:asmr_downloader/utils/system_proxy_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 内存版配置存储, 避免测试写真实文件。
class _MemStorage extends JsonStorage {
  _MemStorage() : super(filePath: 'asmr_proxy_test_config.json');

  final Map<String, dynamic> data = {};

  @override
  Future<Map<String, dynamic>> read() async => Map<String, dynamic>.of(data);

  @override
  Future<void> write(Map<String, dynamic> newData) async {
    data
      ..clear()
      ..addAll(newData);
  }

  @override
  Future<void> addOrUpdate(Map<String, dynamic> newData) async {
    data.addAll(newData);
  }
}

/// 记录代理设置的假 API, 避免真实 HttpClient。
class _FakeApi extends AsmrApi {
  String _proxy = 'DIRECT';

  @override
  String get proxy => _proxy;

  @override
  set proxy(String value) => _proxy = value;

  @override
  void setApiChannel(String apiChannel) {}
}

void main() {
  late ProviderContainer container;
  late _MemStorage storage;
  late _FakeApi api;
  late SystemProxyConfig fakeSystemProxy;

  /// 模拟"系统代理开启"。
  void enableSystemProxy([String proxy = '127.0.0.1:7890']) {
    fakeSystemProxy = SystemProxyConfig(proxy: proxy, autoDetect: false);
  }

  /// 模拟"系统代理关闭"。
  void disableSystemProxy() {
    fakeSystemProxy = SystemProxyConfig(proxy: null, autoDetect: false);
  }

  setUp(() {
    enableSystemProxy();
    storage = _MemStorage();
    api = _FakeApi();
    container = ProviderContainer(
      overrides: [
        systemProxyConfigReaderProvider.overrideWithValue(() => fakeSystemProxy),
        configFileProvider.overrideWithValue(storage),
        asmrApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<void> pumpProxyWidget(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: Center(child: AsmrProxy())),
        ),
      ),
    );
    // post-frame callback + 检测后的重建
    await tester.pump();
    await tester.pump();
  }

  /// 等待一个检测周期, 触发周期性检测。
  Future<void> waitCheckCycle(WidgetTester tester) async {
    await tester.pump(kSystemProxyCheckInterval);
    await tester.pump();
  }

  Checkbox checkbox(WidgetTester tester) =>
      tester.widget<Checkbox>(find.byType(Checkbox));

  testWidgets('系统代理开启时可勾选, 勾选后代理生效并写入配置', (tester) async {
    await pumpProxyWidget(tester);

    expect(checkbox(tester).onChanged, isNotNull);
    expect(checkbox(tester).value, isFalse);
    expect(container.read(proxyProvider), 'DIRECT');

    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    expect(checkbox(tester).value, isTrue);
    expect(container.read(proxyProvider), 'PROXY 127.0.0.1:7890; DIRECT');
    expect(storage.data['proxy'], 'PROXY 127.0.0.1:7890; DIRECT');
    expect(api.proxy, 'PROXY 127.0.0.1:7890; DIRECT');

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('勾选后关闭系统代理: 自动取消勾选并禁用 (回归)', (tester) async {
    await pumpProxyWidget(tester);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(checkbox(tester).value, isTrue);

    // 关闭系统代理, 不做任何鼠标交互
    disableSystemProxy();
    await waitCheckCycle(tester);

    expect(checkbox(tester).value, isFalse, reason: '应自动取消勾选');
    expect(checkbox(tester).onChanged, isNull, reason: '应禁用不可点击');
    expect(container.read(proxyProvider), 'DIRECT', reason: '应切回直连');
    expect(storage.data['proxy'], 'DIRECT', reason: '配置应同步为直连');
    expect(api.proxy, 'DIRECT');

    // 已禁用: 点击不应改变状态
    await tester.tap(find.byType(Checkbox), warnIfMissed: false);
    await tester.pump();
    expect(checkbox(tester).value, isFalse);
    expect(container.read(proxyProvider), 'DIRECT');

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('无系统代理时选项不可点击', (tester) async {
    disableSystemProxy();
    await pumpProxyWidget(tester);

    expect(checkbox(tester).onChanged, isNull);
    expect(checkbox(tester).value, isFalse);

    await tester.tap(find.byType(Checkbox), warnIfMissed: false);
    await tester.pump();
    expect(checkbox(tester).value, isFalse);
    expect(container.read(proxyProvider), 'DIRECT');

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('启动时残留代理勾选但系统代理已关闭: 自动清理', (tester) async {
    disableSystemProxy();
    container.read(proxyProvider.notifier).state =
        'PROXY 127.0.0.1:7890; DIRECT';

    await pumpProxyWidget(tester);

    expect(checkbox(tester).value, isFalse);
    expect(checkbox(tester).onChanged, isNull);
    expect(container.read(proxyProvider), 'DIRECT');
    expect(storage.data['proxy'], 'DIRECT');

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('系统代理地址变化时同步新地址', (tester) async {
    await pumpProxyWidget(tester);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(container.read(proxyProvider), 'PROXY 127.0.0.1:7890; DIRECT');

    enableSystemProxy('127.0.0.1:1080');
    await waitCheckCycle(tester);

    expect(checkbox(tester).value, isTrue, reason: '仍保持勾选');
    expect(checkbox(tester).onChanged, isNotNull);
    expect(container.read(proxyProvider), 'PROXY 127.0.0.1:1080; DIRECT');

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('关闭后重新开启系统代理: 选项恢复可用', (tester) async {
    await pumpProxyWidget(tester);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    disableSystemProxy();
    await waitCheckCycle(tester);
    expect(checkbox(tester).onChanged, isNull);

    enableSystemProxy();
    await waitCheckCycle(tester);

    expect(checkbox(tester).onChanged, isNotNull);
    expect(checkbox(tester).value, isFalse, reason: '重新开启后保持未勾选');

    await tester.pumpWidget(const SizedBox());
  });
}
