import 'package:asmr_downloader/common/config_providers.dart';
import 'package:asmr_downloader/pages/components/failure_panel.dart';
import 'package:asmr_downloader/pages/downloader/search_result/search_result.dart';
import 'package:asmr_downloader/services/asmr_repo/asmr_api.dart';
import 'package:asmr_downloader/services/asmr_repo/providers/api_providers.dart';
import 'package:asmr_downloader/services/asmr_repo/search_failure.dart';
import 'package:asmr_downloader/services/download/download_providers.dart';
import 'package:asmr_downloader/services/ui/ui_providers.dart';
import 'package:asmr_downloader/utils/json_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 内存版配置存储, 避免测试写真实文件。
class _MemStorage extends JsonStorage {
  _MemStorage() : super(filePath: 'search_failure_ui_test_config.json');

  @override
  Future<Map<String, dynamic>> read() async => <String, dynamic>{};

  @override
  Future<void> write(Map<String, dynamic> data) async {}

  @override
  Future<void> addOrUpdate(Map<String, dynamic> data) async {}
}

/// 构造一个失败的 dio 异常。
DioException dioFailure(
  DioExceptionType type, {
  int? statusCode,
  String? body,
}) {
  final options = RequestOptions(path: 'https://api.asmr-200.com/api/search/VJ1');
  return DioException(
    requestOptions: options,
    type: type,
    response: statusCode == null
        ? null
        : Response(
            requestOptions: options,
            statusCode: statusCode,
            data: body,
          ),
    message: '$type',
  );
}

/// 可编排的假 API: 搜索直接返回结果或抛出失败, 不发真实请求。
class _FakeApi extends AsmrApi {
  _FakeApi({
    this.works = const [],
    this.onSearchFailure,
    this.onWorkInfoFailure,
    this.requestDelay = Duration.zero,
  });

  /// 搜索结果里 works 的内容。
  final List<Map<String, dynamic>> works;

  /// 非空时搜索抛失败 (模拟网络/服务器问题)。
  final SearchFailure? onSearchFailure;

  /// 非空时作品信息抛失败。
  final SearchFailure? onWorkInfoFailure;

  /// 每个请求的耗时 (用于断言"加载中"状态)。
  final Duration requestDelay;

  int searchCallCount = 0;
  int workInfoCallCount = 0;
  String? lastApiChannel;

  @override
  Future<Map<String, dynamic>> search({
    required String content,
    Map<String, dynamic>? params,
    int maxTry = 3,
  }) async {
    searchCallCount++;
    if (requestDelay > Duration.zero) {
      await Future<void>.delayed(requestDelay);
    }
    final failure = onSearchFailure;
    if (failure != null) {
      throw SearchFailureException(failure);
    }
    return {'works': works};
  }

  @override
  Future<Map<String, dynamic>> getWorkInfo(String id) async {
    workInfoCallCount++;
    if (requestDelay > Duration.zero) {
      await Future<void>.delayed(requestDelay);
    }
    final failure = onWorkInfoFailure;
    if (failure != null) {
      throw SearchFailureException(failure);
    }
    return {
      'title': '测试作品',
      'circle': {'name': '测试社团'},
      'vas': [
        {'name': '测试cv'},
      ],
      'tags': const <dynamic>[],
      'mainCoverUrl': '',
      'release': '2024-01-01',
      'dl_count': 0,
    };
  }

  @override
  Future<List<dynamic>> getTracks(String id) async {
    if (requestDelay > Duration.zero) {
      await Future<void>.delayed(requestDelay);
    }
    return const <dynamic>[];
  }

  @override
  void setApiChannel(String apiChannel) => lastApiChannel = apiChannel;
}

/// 当前 api channel 下的搜索失败。
SearchFailure searchFailureOf(DioExceptionType type, {int? statusCode}) =>
    SearchFailure.of(
      dioFailure(type, statusCode: statusCode),
      stage: SearchStage.search,
      apiChannel: 'asmr-200',
    );

/// 作品信息请求失败 (RJ 号只走 work/{id} 接口)。
SearchFailure workInfoFailureOf(DioExceptionType type, {int? statusCode}) =>
    SearchFailure.of(
      dioFailure(type, statusCode: statusCode),
      stage: SearchStage.workInfo,
      apiChannel: 'asmr-200',
      requireFullMatch: true,
    );

/// RJ 号: 不做搜索请求, 直接用 id 取元数据。
void setRjSearch(ProviderContainer container, String sourceId) {
  container.read(searchTextProvider.notifier).state = sourceId;
}

void main() {
  late ProviderContainer container;
  late _FakeApi api;

  setUp(() {
    // windows_taskbar 的通道在测试环境没有实现, 不 mock 会让
    // UIService.resetProgress() 永远不返回。
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

  ProviderContainer createContainer(_FakeApi fake) {
    final container = ProviderContainer(
      overrides: [
        configFileProvider.overrideWithValue(_MemStorage()),
        asmrApiProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> pumpSearchResult(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: Column(children: [SearchResult()])),
        ),
      ),
    );
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
  }

  testWidgets('搜索请求失败: 两个 panel 都显示失败原因 (不再显示 No tracks/info)', (tester) async {
    api = _FakeApi(
      onSearchFailure: searchFailureOf(DioExceptionType.badResponse, statusCode: 500),
    );
    container = createContainer(api);
    container.read(searchTextProvider.notifier).state = 'VJ012345';

    await pumpSearchResult(tester, container);

    // 左 (作品信息) 与右 (音轨) 两个面板。
    expect(find.byType(FailurePanel), findsNWidgets(2));
    expect(find.textContaining('服务器错误'), findsNWidgets(2));
    // 不再显示默认文案。
    expect(find.text('No work info'), findsNothing);
    expect(find.text('No tracks'), findsNothing);
    // 面板与空状态一致: 只有图标 + 文案。
    expect(find.byType(TextButton), findsNothing);
    // 状态码写在括号里 (不写 "HTTP"), 原始错误只在技术详情里。
    expect(find.textContaining('服务器错误（500）'), findsNWidgets(2));
    expect(find.textContaining('HTTP'), findsNothing);
  });

  testWidgets('再次搜索会清掉失败提示 (回归)', (tester) async {
    api = _FakeApi(
      requestDelay: const Duration(milliseconds: 20),
      onSearchFailure: searchFailureOf(DioExceptionType.badResponse, statusCode: 500),
    );
    container = createContainer(api);
    container.read(searchTextProvider.notifier).state = 'VJ012345';

    await pumpSearchResult(tester, container);
    expect(find.byType(FailurePanel), findsNWidgets(2));

    // 用户再次触发搜索: 失败提示先消失 (回到原本的加载/空状态)。
    await container.read(uiServiceProvider).search('VJ012345');
    await tester.pump();
    await tester.pump();

    expect(find.byType(FailurePanel), findsNothing);

    // 请求结束后依然失败, 原因重新显示在两个面板上。
    await tester.pumpAndSettle();
    expect(find.byType(FailurePanel), findsNWidgets(2));
    expect(api.searchCallCount, 2);
  });

  testWidgets('无法连接服务器: 面板直接说明是本机网络问题', (tester) async {
    api = _FakeApi(
      onSearchFailure: searchFailureOf(DioExceptionType.connectionError),
    );
    container = createContainer(api);
    container.read(searchTextProvider.notifier).state = 'VJ012345';

    await pumpSearchResult(tester, container);

    expect(find.textContaining('无法连接服务器'), findsNWidgets(2));
    expect(find.byType(FailurePanel), findsNWidgets(2));
  });

  testWidgets('搜索成功但没有结果: 两个 panel 提示没有搜到', (tester) async {
    api = _FakeApi(works: const []);
    container = createContainer(api);
    container.read(searchTextProvider.notifier).state = 'VJ012345';

    await pumpSearchResult(tester, container);

    expect(find.textContaining('没有搜索到匹配的作品'), findsNWidgets(2));
    expect(find.byType(FailurePanel), findsNWidgets(2));
    expect(find.text('No tracks'), findsNothing);
    expect(find.textContaining('无法连接服务器'), findsNothing);
  });

  testWidgets('输入不合法: 面板提示 sourceId 格式问题', (tester) async {
    api = _FakeApi();
    container = createContainer(api);

    // 用户输入 "abc!!!": 清洗后是 ABC, 不匹配 sourceId 规则。
    final result = await container.read(uiServiceProvider).search('abc!!!');
    expect(result, isNull);
    expect(api.searchCallCount, 0);

    await pumpSearchResult(tester, container);

    expect(find.byType(FailurePanel), findsNWidgets(2));
    expect(find.textContaining('sourceId'), findsNWidgets(2));
    // 输入问题没有可点的操作。
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('搜索成功后不显示失败面板 (过期失败不残留)', (tester) async {
    api = _FakeApi(
      works: const [
        {'id': '422979', 'source_id': 'RJ422979'},
      ],
    );
    container = createContainer(api);
    container.read(searchTextProvider.notifier).state = 'VJ012345';

    await pumpSearchResult(tester, container);

    expect(find.byType(FailurePanel), findsNothing);
    expect(container.read(sourceIdProvider), 'RJ422979');
    expect(container.read(failureProvider), isNull);
  });

  testWidgets('换 api channel 后自动按当前输入重搜', (tester) async {
    api = _FakeApi(
      onSearchFailure: searchFailureOf(DioExceptionType.badResponse, statusCode: 503),
    );
    container = createContainer(api);
    container.read(searchTextProvider.notifier).state = 'VJ012345';

    await pumpSearchResult(tester, container);
    expect(find.byType(FailurePanel), findsNWidgets(2));
    expect(api.searchCallCount, 1);

    container.read(uiServiceProvider).onApiChannelChoosed('asmr-300');
    await tester.pumpAndSettle();

    expect(api.lastApiChannel, 'asmr-300');
    expect(api.searchCallCount, 2, reason: '换 channel 应自动重搜');
  });

  testWidgets('RJ 搜索: 不请求 search, 直接取作品元数据', (tester) async {
    api = _FakeApi();
    container = createContainer(api);
    setRjSearch(container, 'RJ01234567');

    await pumpSearchResult(tester, container);

    expect(api.searchCallCount, 0);
    expect(container.read(idProvider), '01234567');
    expect(find.byType(FailurePanel), findsNothing);
  });

  testWidgets('作品不存在: 两个 panel 都说明作品不存在', (tester) async {
    api = _FakeApi(
      onWorkInfoFailure: workInfoFailureOf(
        DioExceptionType.badResponse,
        statusCode: 404,
      ),
    );
    container = createContainer(api);
    setRjSearch(container, 'RJ99999999');

    await pumpSearchResult(tester, container);

    expect(find.textContaining('作品不存在'), findsNWidgets(2));
    expect(find.byType(FailurePanel), findsNWidgets(2));
    expect(find.textContaining('无法连接'), findsNothing);
    expect(find.text('No work info'), findsNothing);
    expect(find.text('No tracks'), findsNothing);
    expect(api.workInfoCallCount, 1);

    // 重新搜索即可重试 (面板上没有按钮)。
    container.read(uiServiceProvider).retry();
    await tester.pumpAndSettle();
    expect(api.workInfoCallCount, 2, reason: '重试应重新请求作品信息');
  });

  testWidgets('作品信息请求超时: 面板说明超时原因', (tester) async {
    api = _FakeApi(
      onWorkInfoFailure: workInfoFailureOf(DioExceptionType.receiveTimeout),
    );
    container = createContainer(api);
    setRjSearch(container, 'RJ01234567');

    await pumpSearchResult(tester, container);

    expect(find.textContaining('超时'), findsNWidgets(2));
    expect(find.byType(FailurePanel), findsNWidgets(2));
  });
}
