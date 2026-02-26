import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:asmr_downloader/utils/log.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

class AsmrApi {
  final Dio _apiDio = Dio();

  String _proxy = 'DIRECT';

  String get proxy => _proxy;

  set proxy(String proxy) {
    _proxy = proxy;
    _apiDio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.findProxy = (uri) => proxy;
        return client;
      },
    );

    Log.info('proxy set to: $proxy');
  }

  AsmrApi() {
    _apiDio.options
      ..connectTimeout = Duration(seconds: 10)
      ..sendTimeout = Duration(seconds: 10)
      ..receiveTimeout = Duration(seconds: 15);
  }

  void setApiChannel(String apiChannel) {
    _apiDio.options.baseUrl = 'https://api.$apiChannel.com/api/';

    Log.info('api channel set to: $apiChannel');
  }

  /// Logs in the user and updates the authorization header.
  Future<void> login(String name, String password) async {
    try {
      final response = await _apiDio.post(
        'auth/me',
        data: {'name': name, 'password': password},
      );

      if (response.statusCode == 200) {
        final token = response.data['token'];
        _apiDio.options.headers['Authorization'] = 'Bearer $token';

        Log.info('login successfully');
      } else {
        Log.error('login failed with status code: ${response.statusCode}');
      }
    } on DioException catch (e) {
      Log.error('login failed: ${e.message}');
    } catch (e) {
      Log.error('unexpected error during login: $e');
    }
  }

  Future<Response<T>?> _requestWithRetry<T>(
    Future<Response<T>> Function() request, {
    required String method,
    required String path,
    int maxTry = 3,
  }) async {
    int tryCount = 0;
    while (tryCount < maxTry) {
      try {
        tryCount++;
        final response = await request();
        Log.info('[$method] request to "$path" succeeded');
        return response;
      } on DioException catch (e) {
        Log.warning('[$method] request to "$path" failed\n'
            'current try: $tryCount\n'
            'error: $e');
        await Future.delayed(Duration(seconds: 3));
      } catch (e) {
        Log.error('[$method] request to "$path" failed\n'
            'current try: $tryCount\n'
            'unhandled error: $e');
        return null;
      }
    }

    Log.error('[$method] request to "$path" failed after $maxTry tries');
    return null;
  }

  Future<Response<T>?> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    void Function(int, int)? onReceiveProgress,
    int maxTry = 3,
  }) {
    return _requestWithRetry(
      () => _apiDio.get<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      ),
      method: 'GET',
      path: path,
      maxTry: maxTry,
    );
  }

  Future<Response<T>?> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    void Function(int, int)? onSendProgress,
    void Function(int, int)? onReceiveProgress,
    int maxTry = 3,
  }) {
    return _requestWithRetry(
      () => _apiDio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      ),
      method: 'POST',
      path: path,
      maxTry: maxTry,
    );
  }

  Future<Response<T>?> head<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    int maxTry = 3,
  }) {
    return _requestWithRetry(
      () => _apiDio.head<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
      method: 'HEAD',
      path: path,
      maxTry: maxTry,
    );
  }

  Future<Response<dynamic>> download(
    String urlPath,
    dynamic savePath, {
    void Function(int, int)? onReceiveProgress,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    bool deleteOnError = true,
    String lengthHeader = Headers.contentLengthHeader,
    Object? data,
    Options? options,
  }) {
    return _apiDio.download(
      urlPath,
      savePath,
      onReceiveProgress: onReceiveProgress,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
      deleteOnError: deleteOnError,
      lengthHeader: lengthHeader,
      data: data,
      options: options,
    );
  }

  /// Retrieves the user's profile.
  Future<Map<String, dynamic>?> getProfile() async {
    final response = await get<Map<String, dynamic>>('auth/me');
    return response?.data;
  }

  /// Retrieves playlists with pagination and filtering.
  Future<Map<String, dynamic>?> getPlaylists({
    required int page,
    int pageSize = 12,
    String filterBy = 'all',
  }) async {
    final response = await get<Map<String, dynamic>>('playlist/get-playlists',
        queryParameters: {
          'page': page,
          'pageSize': pageSize,
          'filterBy': filterBy,
        });
    return response?.data;
  }

  /// Creates a new playlist.
  Future<Map<String, dynamic>?> createPlaylist({
    required String name,
    String? description,
    int privacy = 0,
  }) async {
    final response =
        await post<Map<String, dynamic>>('playlist/create-playlist', data: {
      'name': name,
      'description': description ?? '',
      'privacy': privacy,
      'locale': 'zh-CN',
      'works': [],
    });
    return response?.data;
  }

  /// Adds works to a playlist.
  Future<Map<String, dynamic>?> addWorksToPlaylist({
    required List<String> sourceIds,
    required String plId,
  }) async {
    final response = await post<Map<String, dynamic>>(
        'playlist/add-works-to-playlist',
        data: {
          'id': plId,
          'works': sourceIds,
        });
    return response?.data;
  }

  /// Deletes a playlist.
  Future<Map<String, dynamic>?> deletePlaylist({
    required String plId,
  }) async {
    final response =
        await post<Map<String, dynamic>>('playlist/delete-playlist', data: {
      'id': plId,
    });
    return response?.data;
  }

  /// Searches for content.
  Future<Map<String, dynamic>?> search({
    required String content,
    Map<String, dynamic>? params,
    int maxTry = 3,
  }) async {
    final response = await get<Map<String, dynamic>>('search/$content',
        queryParameters: params, maxTry: maxTry);
    return response?.data;
  }

  /// Lists works based on parameters.
  Future<Map<String, dynamic>?> listWorks({
    required Map<String, dynamic> params,
  }) async {
    final response =
        await get<Map<String, dynamic>>('works', queryParameters: params);
    return response?.data;
  }

  /// Searches by tag name.
  Future<Map<String, dynamic>?> searchByTag({
    required String tagName,
    required Map<String, dynamic> params,
  }) async {
    return await search(
      content: '\$tag:$tagName\$',
      params: params,
    );
  }

  /// Searches by VA name.
  Future<Map<String, dynamic>?> searchByVa({
    required String vaName,
    required Map<String, dynamic> params,
  }) async {
    return await search(
      content: '\$va:$vaName\$',
      params: params,
    );
  }

  Future<Map<String, dynamic>?> getWorkInfo(String id) async {
    final response = await get<Map<String, dynamic>>('work/$id');
    return response?.data;
  }

  Future<List<dynamic>?> getTracks(String id) async {
    final response = await get<List<dynamic>>('tracks/$id');
    return response?.data;
  }

  Future<int?> tryGetContentLength(String url) async {
    try {
      final response = await head(url);
      return int.parse(response!.headers.value('content-length')!);
    } catch (e) {
      Log.error('get content-length failed\n' 'url: $url\n' 'error: $e');
      return null;
    }
  }

  Future<Uint8List?> getCoverBytes(String url) async {
    try {
      final response = await get(
        url,
        options: Options(responseType: ResponseType.bytes),
      );

      if (response != null) {
        return Uint8List.fromList(response.data);
      } else {
        return null;
      }
    } catch (e) {
      Log.error('fetch cover image data failed.\n' 'error: $e');
      return null;
    }
  }
}
