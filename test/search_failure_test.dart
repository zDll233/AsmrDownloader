import 'dart:io';
import 'dart:typed_data';

import 'package:asmr_downloader/services/asmr_repo/asmr_api.dart';
import 'package:asmr_downloader/services/asmr_repo/search_failure.dart';
import 'package:asmr_downloader/services/ui/ui_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 构造一个失败的 dio 异常。
DioException dioFailure(
  DioExceptionType type, {
  Object? error,
  String? message,
  int? statusCode,
  String? body,
}) {
  final options = RequestOptions(path: 'https://api.asmr-200.com/api/work/123');
  return DioException(
    requestOptions: options,
    type: type,
    error: error,
    response: statusCode == null
        ? null
        : Response(
            requestOptions: options,
            statusCode: statusCode,
            data: body,
          ),
    message: message ?? '$type',
  );
}

void main() {
  group('失败分类', () {
    test('连接/DNS 异常 -> 本机网络问题', () {
      final e = dioFailure(
        DioExceptionType.connectionError,
        error: const SocketException('Failed host lookup: api.asmr-200.com'),
      );
      expect(classifyDioException(e), SearchFailureKind.noNetwork);

      expect(
        SearchFailure.of(e, stage: SearchStage.search).title,
        contains('无法连接服务器'),
      );
    });

    test('连接超时 -> 超时, 且提示当前启用了代理', () {
      final e = dioFailure(DioExceptionType.connectionTimeout);
      expect(classifyDioException(e), SearchFailureKind.timeout);

      final failure = SearchFailure.of(
        e,
        stage: SearchStage.workInfo,
        proxyMode: 'PROXY 127.0.0.1:7890; DIRECT',
      );
      expect(failure.proxyMode, isNot('DIRECT'));
      expect(failure.proxyMode, contains('127.0.0.1'));
    });

    test('报错里出现代理地址 -> 代理不可用', () {
      final e = dioFailure(
        DioExceptionType.connectionError,
        error: const SocketException(
            'Connection refused (OS Error: 由于目标计算机积极拒绝) '
            'uri=https://api.asmr-200.com/api/search/RJ1'),
        message: 'The connection errored: Connection refused '
            'while connecting to proxy 127.0.0.1:7890',
      );
      expect(
        classifyDioException(e, proxyMode: 'PROXY 127.0.0.1:7890; DIRECT'),
        SearchFailureKind.proxyFailed,
      );
      // 未启用代理时同样的报错不算代理问题。
      expect(classifyDioException(e), SearchFailureKind.noNetwork);
    });

    test('服务器 5xx -> 服务器错误 (状态码只进技术详情)', () {
      final e = dioFailure(DioExceptionType.badResponse, statusCode: 502);
      expect(classifyDioException(e), SearchFailureKind.serverError);

      final failure = SearchFailure.of(e, stage: SearchStage.tracks);
      expect(failure.title, '服务器错误');
      expect(failure.title, isNot(contains('502')));
      expect(failure.httpStatusCode, 502);
      expect(failure.technicalDetail, contains('HTTP 状态码: 502'));
    });

    test('精确 id 接口的 404 -> 作品不存在', () {
      final e = dioFailure(DioExceptionType.badResponse, statusCode: 404);
      expect(classifyDioException(e), SearchFailureKind.badResponse);
      expect(
        classifyDioException(e, requireFullMatch: true),
        SearchFailureKind.workNotFound,
      );

      final failure = SearchFailure.of(
        e,
        stage: SearchStage.workInfo,
        requireFullMatch: true,
      );
      expect(failure.title, '作品不存在');
    });

    test('4xx -> 服务器拒绝了请求', () {
      final e = dioFailure(
        DioExceptionType.badResponse,
        statusCode: 403,
        body: '<html>cloudflare</html>',
      );
      expect(classifyDioException(e), SearchFailureKind.badResponse);

      final failure = SearchFailure.of(e, stage: SearchStage.search);
      expect(failure.title, contains('服务器拒绝了搜索请求'));
      expect(failure.title, isNot(contains('403')));
      // 状态码与响应体片段进技术详情, 便于定位是不是风控页面。
      expect(failure.technicalDetail, contains('HTTP 状态码: 403'));
      expect(failure.technicalDetail, contains('cloudflare'));
    });

    test('429 -> 请求过于频繁', () {
      final e = dioFailure(DioExceptionType.badResponse, statusCode: 429);
      expect(classifyDioException(e), SearchFailureKind.rateLimited);
    });

    test('证书异常 -> 证书校验失败', () {
      final e = dioFailure(
        DioExceptionType.badCertificate,
        error: const HandshakeException('bad cert'),
      );
      expect(classifyDioException(e), SearchFailureKind.badCertificate);
    });

    test('重试策略: 4xx / 证书不重试, 超时与 5xx 重试', () {
      expect(
        isRetryableDioException(
            dioFailure(DioExceptionType.badResponse, statusCode: 404)),
        isFalse,
      );
      expect(
        isRetryableDioException(
            dioFailure(DioExceptionType.badResponse, statusCode: 503)),
        isTrue,
      );
      expect(
        isRetryableDioException(dioFailure(DioExceptionType.badCertificate)),
        isFalse,
      );
      expect(
        isRetryableDioException(dioFailure(DioExceptionType.connectionTimeout)),
        isTrue,
      );
    });
  });

  group('失败文案', () {
    test('输入不合法与空结果不做重试', () {
      expect(SearchFailure.invalidInput('abc!').retryable, isFalse);
      expect(SearchFailure.emptyResult('VJ123').retryable, isFalse);
      expect(
        SearchFailure.of(
          dioFailure(DioExceptionType.connectionTimeout),
          stage: SearchStage.search,
        ).retryable,
        isTrue,
      );
    });

    test('空结果标题明确表示没有搜到', () {
      expect(SearchFailure.emptyResult('VJ012345').title, contains('没有搜索到'));
    });

    test('技术详情包含阶段/状态码/channel/代理/尝试次数', () {
      final failure = SearchFailure.of(
        dioFailure(DioExceptionType.badResponse, statusCode: 500),
        stage: SearchStage.workInfo,
        apiChannel: 'asmr-200',
        proxyMode: 'DIRECT',
        tries: 3,
      );
      expect(failure.technicalDetail, contains('作品信息请求'));
      expect(failure.technicalDetail, contains('HTTP 状态码: 500'));
      expect(failure.technicalDetail, contains('asmr-200'));
      expect(failure.technicalDetail, contains('尝试次数: 3'));
    });

    test('只有网络/服务端类失败才建议换 channel', () {
      expect(
        SearchFailure.suggestChannelSwitch(SearchFailureKind.serverError),
        isTrue,
      );
      expect(
        SearchFailure.suggestChannelSwitch(SearchFailureKind.noNetwork),
        isTrue,
      );
      expect(
        SearchFailure.suggestChannelSwitch(SearchFailureKind.workNotFound),
        isFalse,
      );
      expect(
        SearchFailure.suggestChannelSwitch(SearchFailureKind.badData),
        isFalse,
      );
    });
  });

  group('AsmrApi 失败语义', () {
    test('服务器 500 抛出带原因的 SearchFailureException', () async {
      final api = AsmrApi()
        ..setApiChannel(_FakeStatusAdapter.apiChannel)
        ..httpClientAdapter = _FakeStatusAdapter(500, 'internal error');

      await expectLater(
        api.getWorkInfo('123'),
        throwsA(
          isA<SearchFailureException>()
              .having((e) => e.failure.kind, 'kind', SearchFailureKind.serverError)
              .having((e) => e.failure.httpStatusCode, 'statusCode', 500)
              .having((e) => e.failure.technicalDetail, 'detail',
                  contains('internal error')),
        ),
      );
    });

    test('4xx 不重试 (只请求一次), 且归类为服务器拒绝', () async {
      final adapter = _FakeStatusAdapter(404, 'not found');
      final api = AsmrApi()
        ..setApiChannel(_FakeStatusAdapter.apiChannel)
        ..httpClientAdapter = adapter;

      await expectLater(
        api.getWorkInfo('123'),
        throwsA(
          isA<SearchFailureException>().having(
            (e) => e.failure.kind,
            'kind',
            SearchFailureKind.workNotFound,
          ),
        ),
      );
      expect(adapter.requestCount, 1, reason: '4xx 是确定性错误, 不应重试');
    });
  });

  group('combineStates', () {
    test('上游错误优先于加载与数据', () {
      final error = AsyncError<int>(Exception('boom'), StackTrace.empty);

      expect(combineStates(error, const AsyncData<int>(1)), isA<AsyncError>());
      expect(combineStates(const AsyncData<int>(1), error), isA<AsyncError>());
      expect(
        combineStates(const AsyncLoading<int>(), error),
        isA<AsyncError>(),
      );
    });

    test('加载中优先于数据', () {
      expect(
        combineStates(const AsyncData<int>(1), const AsyncLoading<int>()),
        isA<AsyncLoading>(),
      );
    });

    test('两者都有数据时取后者的数据', () {
      expect(
        combineStates(const AsyncData<int>(1), const AsyncData<int>(2)).value,
        2,
      );
      expect(
        combineStates(const AsyncData<int>(1), const AsyncData<int?>(null)).value,
        isNull,
      );
    });
  });
}

/// 固定返回指定状态码的假 http 适配器 (不打真实网络)。
class _FakeStatusAdapter implements HttpClientAdapter {
  _FakeStatusAdapter(this.statusCode, this.body);

  static const apiChannel = 'asmr-200';

  final int statusCode;
  final String body;

  /// 适配器被调用 (即真实发请求) 的次数。
  int requestCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestCount++;
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: options,
        statusCode: statusCode,
        data: body,
      ),
      message: 'bad response ($statusCode)',
    );
  }

  @override
  void close({bool force = false}) {}
}
