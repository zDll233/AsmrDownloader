import 'dart:io';

import 'package:dio/dio.dart';

/// 失败发生的阶段 (搜索 -> 作品信息 -> 音声文件列表)。
enum SearchStage {
  search('搜索请求'),
  workInfo('作品信息请求'),
  tracks('音声文件请求');

  const SearchStage(this.label);

  final String label;
}

/// 失败归属: 本机 / 服务器 / sourceId / 数据。
enum SearchFailureKind {
  invalidInput,
  emptyResult,
  noNetwork,
  timeout,
  proxyFailed,
  badResponse,
  workNotFound,
  serverError,
  rateLimited,
  badCertificate,
  badData,
  unknown,
}

/// 一次失败的原因。UI 只展示 [title] (以及可展开的 [technicalDetail])。
class SearchFailure {
  SearchFailure({
    required this.kind,
    required this.stage,
    this.httpStatusCode,
    this.apiChannel = '',
    this.proxyMode = 'DIRECT',
    this.tries = 0,
    this.rawDetail,
  });

  final SearchFailureKind kind;
  final SearchStage stage;
  final int? httpStatusCode;
  final String apiChannel;
  final String proxyMode;
  final int tries;

  /// 原始异常描述 / 服务器响应片段, 用于技术详情。
  final String? rawDetail;

  /// 面板标题: 只说清楚问题出在哪, 状态码写在括号里 (不写 "HTTP")。
  String get title {
    switch (kind) {
      case SearchFailureKind.invalidInput:
        return '请输入合法的 sourceId';
      case SearchFailureKind.emptyResult:
        return '没有搜索到匹配的作品';
      case SearchFailureKind.noNetwork:
        return '无法连接服务器（本机网络或 DNS 异常）';
      case SearchFailureKind.timeout:
        return proxyMode == 'DIRECT' ? '请求超时' : '请求超时（当前已启用代理）';
      case SearchFailureKind.proxyFailed:
        return '代理不可用（$proxyMode）';
      case SearchFailureKind.badResponse:
        // 只写状态码, 不啰嗦 "HTTP"。
        final code = httpStatusCode == null ? '' : '（$httpStatusCode）';
        return stage == SearchStage.search
            ? '服务器拒绝了搜索请求$code'
            : '服务器拒绝了请求$code';
      case SearchFailureKind.workNotFound:
        return httpStatusCode == null ? '作品不存在' : '作品不存在（$httpStatusCode）';
      case SearchFailureKind.serverError:
        return httpStatusCode == null ? '服务器错误' : '服务器错误（$httpStatusCode）';
      case SearchFailureKind.rateLimited:
        return httpStatusCode == null ? '请求过于频繁' : '请求过于频繁（$httpStatusCode）';
      case SearchFailureKind.badCertificate:
        return 'HTTPS 证书校验失败';
      case SearchFailureKind.badData:
        return '服务器返回的数据异常';
      case SearchFailureKind.unknown:
        return stage == SearchStage.search
            ? '搜索失败'
            : '${stage.label}失败';
    }
  }

  /// 技术详情: 面板中默认折叠, 供排查与反馈。
  String get technicalDetail {
    final raw = rawDetail?.trim();
    return [
      '阶段: ${stage.label}',
      if (httpStatusCode != null) 'HTTP 状态码: $httpStatusCode',
      if (apiChannel.isNotEmpty) 'api channel: $apiChannel',
      '代理: $proxyMode',
      '尝试次数: $tries',
      if (raw != null && raw.isNotEmpty) '原始错误: $raw',
    ].join('\n');
  }

  /// 该失败是否值得直接重试 (输入问题与"没有结果"重试无意义)。
  bool get retryable =>
      kind != SearchFailureKind.invalidInput &&
      kind != SearchFailureKind.emptyResult;

  /// 服务端/网络侧的可变状态问题: 换个 api channel 可能就好了。
  static bool suggestChannelSwitch(SearchFailureKind kind) =>
      switch (kind) {
        SearchFailureKind.noNetwork ||
        SearchFailureKind.timeout ||
        SearchFailureKind.proxyFailed ||
        SearchFailureKind.badResponse ||
        SearchFailureKind.serverError ||
        SearchFailureKind.rateLimited ||
        SearchFailureKind.unknown =>
          true,
        _ => false,
      };

  /// 输入不合法。
  factory SearchFailure.invalidInput(String rawInput) => SearchFailure(
        kind: SearchFailureKind.invalidInput,
        stage: SearchStage.search,
        rawDetail: '输入: "$rawInput"',
      );

  /// 请求成功但服务器没有返回匹配的作品。
  factory SearchFailure.emptyResult(String sourceId) => SearchFailure(
        kind: SearchFailureKind.emptyResult,
        stage: SearchStage.search,
        rawDetail: '搜索关键字: "$sourceId", 服务器返回 works 为空',
      );

  /// 把任意异常归一化成失败原因。
  factory SearchFailure.of(
    Object error, {
    required SearchStage stage,
    bool requireFullMatch = false,
    int? httpStatusCode,
    String apiChannel = '',
    String proxyMode = 'DIRECT',
    int tries = 0,
  }) {
    final kind = _kindOf(error, requireFullMatch, proxyMode);

    if (error is DioException) {
      return SearchFailure(
        kind: kind,
        stage: stage,
        httpStatusCode: httpStatusCode ?? _statusCodeOf(error),
        apiChannel: apiChannel,
        proxyMode: proxyMode,
        tries: tries,
        rawDetail: dioErrorDetail(error),
      );
    }

    return SearchFailure(
      kind: kind,
      stage: stage,
      httpStatusCode: httpStatusCode,
      apiChannel: apiChannel,
      proxyMode: proxyMode,
      tries: tries,
      rawDetail: _trim(error.toString(), 300),
    );
  }

  static SearchFailureKind _kindOf(
    Object error,
    bool requireFullMatch,
    String proxyMode,
  ) {
    if (error is DioException) {
      return classifyDioException(
        error,
        requireFullMatch: requireFullMatch,
        proxyMode: proxyMode,
      );
    }
    if (error is SocketException) return SearchFailureKind.noNetwork;
    return SearchFailureKind.unknown;
  }
}

/// api 请求失败, 由 [SearchFailure] 说明原因。
class SearchFailureException implements Exception {
  SearchFailureException(this.failure);

  final SearchFailure failure;

  @override
  String toString() => 'SearchFailureException(${failure.title})';
}

/// 根据 dio 异常判断失败归属。
///
/// [requireFullMatch] 为 true 时 (精确 id 接口, 如 `work/{id}`) 404 直接判定为
/// "作品不存在"。
SearchFailureKind classifyDioException(
  DioException e, {
  bool requireFullMatch = false,
  String proxyMode = 'DIRECT',
}) {
  switch (e.type) {
    case DioExceptionType.cancel:
      return SearchFailureKind.unknown;
    case DioExceptionType.badCertificate:
      return SearchFailureKind.badCertificate;
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      // 代理不通时常见表现也是连接超时。
      return _looksLikeProxyFailure(e, proxyMode)
          ? SearchFailureKind.proxyFailed
          : SearchFailureKind.timeout;
    case DioExceptionType.connectionError:
      return _looksLikeProxyFailure(e, proxyMode)
          ? SearchFailureKind.proxyFailed
          : SearchFailureKind.noNetwork;
    case DioExceptionType.badResponse:
      final status = e.response?.statusCode;
      if (status == 429) return SearchFailureKind.rateLimited;
      if (status != null && status >= 500 && status < 600) {
        return SearchFailureKind.serverError;
      }
      // Cloudflare/网关把"连不上源站"表达成 502/503/504 之外的 HTML 页面时,
      // body 里通常也带关键字。
      if (_looksLikeProxyFailure(e, proxyMode)) {
        return SearchFailureKind.proxyFailed;
      }
      if (status == 404 && requireFullMatch) {
        return SearchFailureKind.workNotFound;
      }
      if (status != null && status >= 400 && status < 500) {
        return SearchFailureKind.badResponse;
      }
      return SearchFailureKind.unknown;
    case DioExceptionType.unknown:
      final cause = e.error;
      if (cause is SocketException) {
        return _looksLikeProxyFailure(e, proxyMode)
            ? SearchFailureKind.proxyFailed
            : SearchFailureKind.noNetwork;
      }
      if (cause is HandshakeException) {
        return SearchFailureKind.badCertificate;
      }
      if (cause is HttpException) return SearchFailureKind.noNetwork;
      return SearchFailureKind.unknown;
  }
}

/// 该异常是否值得重试 (客户端的确定性错误重试没意义)。
bool isRetryableDioException(DioException e) {
  switch (e.type) {
    case DioExceptionType.cancel:
      return false;
    case DioExceptionType.badCertificate:
      return false;
    case DioExceptionType.badResponse:
      final status = e.response?.statusCode ?? 0;
      // 4xx 是客户端的确定性错误; 5xx 交给上层重试。
      return status >= 500;
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
    case DioExceptionType.unknown:
      return true;
  }
}

int? _statusCodeOf(DioException e) => e.response?.statusCode;

bool _looksLikeProxyFailure(DioException e, String proxyMode) {
  final cause = e.error;
  if (cause is SocketException && proxyMode != 'DIRECT') return true;

  final text = '${e.message ?? ''} ${e.error ?? ''} ${e.response?.data ?? ''}';
  if (text.contains('Proxy Authentication Required') ||
      text.contains('proxy authentication') ||
      text.contains('ERR_PROXY') ||
      text.contains('Bad Gateway')) {
    return true;
  }

  // 代理 host 解析/连接失败: 报错里出现的是代理地址而不是目标站点。
  // (不出现代理地址时, 目标站点本身解析失败属于本机 DNS 问题)
  for (final host in _proxyHosts(proxyMode)) {
    if (text.contains(host)) return true;
  }
  return false;
}

/// 从 `PROXY 127.0.0.1:7890; DIRECT` 里取出代理 host。
List<String> _proxyHosts(String proxyMode) {
  final hosts = <String>[];
  for (final rawEntry in proxyMode.split(';')) {
    final entry = rawEntry.trim();
    if (!entry.toUpperCase().startsWith('PROXY ')) continue;
    final address = entry.substring(6).trim();
    if (address.isEmpty) continue;
    final host = address.contains(':')
        ? address.substring(0, address.lastIndexOf(':'))
        : address;
    if (host.isNotEmpty) hosts.add(host);
  }
  return hosts;
}

/// 供详情展示的 dio 异常描述 (过长会截断), 并附上服务器返回的正文片段
/// —— 网关的 HTML 页面/错误信息往往最能说明问题。
String dioErrorDetail(DioException e) {
  final detail = _trim(e.toString(), 300);
  final snippet = bodySnippet(e);
  if (snippet == null) return detail;
  return '$detail\n响应体: $snippet';
}

/// 从 dio 响应体里取一小段文本, 便于用户看到服务器真正的返回内容。
String? bodySnippet(DioException e) {
  final data = e.response?.data;
  if (data == null) return null;
  if (data is String) {
    final text = data.trim();
    return text.isEmpty ? null : _trim(text, 300);
  }
  return null;
}

String _trim(String text, int maxLength) {
  final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.length <= maxLength) return normalized;
  return '${normalized.substring(0, maxLength)}…';
}
