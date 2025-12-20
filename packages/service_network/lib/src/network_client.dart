import 'dart:async';

import 'package:dio/dio.dart';
import 'package:logging_util/logging_util.dart';

import 'api_response.dart';
import 'app_exception.dart';
import 'network_config.dart';
import 'network_types.dart';

/// 高级封装的网络客户端，默认以单例形式使用，也可按需创建独立实例。
class NetworkClient {
  NetworkClient._(this._dio, this._config) {
    _setupInterceptors();
  }

  /// 默认单例入口，满足大多数应用场景；如需隔离配置，可使用 [NetworkClient.newInstance]。
  factory NetworkClient({
    NetworkConfig config = const NetworkConfig(),
    bool useSingleton = true,
  }) {
    if (useSingleton) {
      _singleton ??= NetworkClient._create(config);
      return _singleton!;
    }
    return NetworkClient._create(config);
  }

  /// 创建隔离实例，便于依赖注入或测试。
  factory NetworkClient.newInstance(
      {NetworkConfig config = const NetworkConfig()}) {
    return NetworkClient._create(config);
  }

  static NetworkClient? _singleton;

  final Dio _dio;
  final NetworkConfig _config;

  Dio get rawDio => _dio;

  static NetworkClient _create(NetworkConfig config) {
    final dio = Dio(config.toBaseOptions());
    return NetworkClient._(dio, config);
  }

  void _setupInterceptors() {
    _dio.interceptors.clear();
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _handleRequest,
        onResponse: _handleResponse,
        onError: _handleError,
      ),
    );

    if (_config.enableNetworkLog) {
      _dio.interceptors.add(_buildLogInterceptor());
    }
  }

  Future<void> _handleRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final headers = <String, dynamic>{...?options.headers};

    final token = await _config.tokenProvider?.call();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final dynamicHeaders = await _config.headerProvider?.call();
    if (dynamicHeaders != null && dynamicHeaders.isNotEmpty) {
      headers.addAll(dynamicHeaders);
    }

    var ctx = RequestContext(
      method: options.method,
      path: options.path,
      headers: headers,
      queryParameters: options.queryParameters,
      body: options.data,
      extra: options.extra,
    );

    if (_config.onRequest != null) {
      ctx = await _config.onRequest!(ctx);
    }

    if (_config.stubResolver != null) {
      final stub = await _config.stubResolver!(ctx);
      if (stub != null) {
        return handler.resolve(
          Response(
            requestOptions: options,
            statusCode: stub.statusCode,
            data: stub.data,
            headers: _toHeaders(stub.headers),
          ),
        );
      }
    }

    options
      ..method = ctx.method
      ..path = ctx.path
      ..headers = ctx.headers
      ..queryParameters = ctx.queryParameters ?? {}
      ..data = ctx.body
      ..extra = {...?options.extra, ...?ctx.extra};

    handler.next(options);
  }

  Future<void> _handleResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    final ctx = ResponseContext(
      statusCode: response.statusCode ?? 0,
      data: response.data,
      headers: response.headers.map,
      request: _toRequestContext(response.requestOptions),
    );

    final value =
        _config.onResponse != null ? await _config.onResponse!(ctx) : ctx;
    final statusCode = value.statusCode;
    if (statusCode < 200 || statusCode >= 300) {
      return handler.reject(
        DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          message: 'HTTP $statusCode',
        ),
      );
    }

    handler.next(
      Response(
        requestOptions: response.requestOptions,
        statusCode: value.statusCode,
        data: value.data,
        headers: _toHeaders(value.headers),
      ),
    );
  }

  Future<void> _handleError(
      DioException error, ErrorInterceptorHandler handler) async {
    final ctx = NetworkErrorContext(
      request: _toRequestContext(error.requestOptions),
      error: error,
      stackTrace: error.stackTrace,
    );

    final recovered =
        _config.onError != null ? await _config.onError!(ctx) : null;
    if (recovered != null) {
      return handler.resolve(
        Response(
          requestOptions: error.requestOptions,
          statusCode: recovered.statusCode,
          data: recovered.data,
          headers: _toHeaders(recovered.headers),
        ),
      );
    }

    LogUtil.e(
      '[Network] Request failed: ${error.message}',
      error.stackTrace,
    );
    handler.next(error);
  }

  /// GET 请求封装，提供泛型解析与取消、进度回调。
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    RequestConfig? requestConfig,
    NetworkCancelToken? cancelToken,
    NetworkProgressCallback? onReceiveProgress,
    JsonParser<T>? parser,
  }) {
    final options = _buildOptions(requestConfig);
    return _wrapRequest(
      () => _dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: _asCancelToken(cancelToken),
        onReceiveProgress: onReceiveProgress,
      ),
      parser: parser,
    );
  }

  /// POST 请求封装，支持上传进度回调。
  Future<T> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    RequestConfig? requestConfig,
    NetworkCancelToken? cancelToken,
    NetworkProgressCallback? onSendProgress,
    NetworkProgressCallback? onReceiveProgress,
    JsonParser<T>? parser,
  }) {
    final options = _buildOptions(requestConfig);
    return _wrapRequest(
      () => _dio.post<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: _asCancelToken(cancelToken),
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      ),
      parser: parser,
    );
  }

  Future<T> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    RequestConfig? requestConfig,
    NetworkCancelToken? cancelToken,
    NetworkProgressCallback? onSendProgress,
    NetworkProgressCallback? onReceiveProgress,
    JsonParser<T>? parser,
  }) {
    final options = _buildOptions(requestConfig);
    return _wrapRequest(
      () => _dio.put<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: _asCancelToken(cancelToken),
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      ),
      parser: parser,
    );
  }

  Future<T> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    RequestConfig? requestConfig,
    NetworkCancelToken? cancelToken,
    JsonParser<T>? parser,
  }) {
    final options = _buildOptions(requestConfig);
    return _wrapRequest(
      () => _dio.delete<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: _asCancelToken(cancelToken),
      ),
      parser: parser,
    );
  }

  /// 文件下载封装，提供进度回调。
  Future<DownloadResult> download(
    String urlPath,
    String savePath, {
    NetworkProgressCallback? onReceiveProgress,
    NetworkCancelToken? cancelToken,
    Map<String, dynamic>? queryParameters,
    RequestConfig? requestConfig,
  }) async {
    final options = _buildOptions(requestConfig);
    try {
      final response = await _dio.download(
        urlPath,
        savePath,
        queryParameters: queryParameters,
        options: options,
        cancelToken: _asCancelToken(cancelToken),
        onReceiveProgress: onReceiveProgress,
      );
      return DownloadResult(
        savePath: savePath,
        statusCode: response.statusCode ?? 0,
      );
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  /// 将请求调用与统一错误转换封装起来，减少重复代码。
  Future<T> _wrapRequest<T>(
    Future<Response<dynamic>> Function() send, {
    JsonParser<T>? parser,
  }) async {
    try {
      final response = await send();
      return _parseResponse(response, parser);
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    } on AppException {
      rethrow;
    } catch (e, s) {
      throw AppException(
        message: '未知错误',
        original: e,
        stackTrace: s,
      );
    }
  }

  T _parseResponse<T>(Response<dynamic> response, JsonParser<T>? parser) {
    final payload = response.data;
    if (payload is Map<String, dynamic>) {
      try {
        final apiResponse = ApiResponse<T>.fromJson(payload, parser: parser);
        if (apiResponse.success) {
          final result = apiResponse.data;
          if (result is T) {
            return result;
          }
          if (result == null && (null is T)) {
            return result as T;
          }
          throw AppException(
            message: '无法将响应转换为目标类型 $T',
            code: apiResponse.code,
            data: result,
          );
        }
        throw AppException.business(
          code: apiResponse.code,
          message: apiResponse.message,
          data: apiResponse.data,
        );
      } on AppException {
        rethrow;
      } catch (e, s) {
        throw AppException(
          message: '响应解析失败',
          code: response.statusCode,
          data: payload,
          original: e,
          stackTrace: s,
        );
      }
    }

    if (payload == null && (null is T)) {
      return payload as T;
    }
    if (payload is T) {
      return payload;
    }

    throw AppException(
      message: '响应格式非预期，无法解析',
      code: response.statusCode,
      data: payload,
    );
  }

  Interceptor _buildLogInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        LogUtil.d(
          '[Network] REQUEST [${options.method}] => ${options.uri}\nHeaders: ${options.headers}\nQuery: ${options.queryParameters}\nBody: ${options.data}',
        );
        handler.next(options);
      },
      onResponse: (response, handler) {
        LogUtil.d(
          '[Network] RESPONSE [${response.statusCode}] <= ${response.requestOptions.uri}\nData: ${response.data}',
        );
        handler.next(response);
      },
      onError: (error, handler) {
        LogUtil.e(
          '[Network] ERROR [${error.response?.statusCode}] <= ${error.requestOptions.uri}\n${error.message}',
          error.stackTrace,
        );
        handler.next(error);
      },
    );
  }

  Options _buildOptions(RequestConfig? requestConfig) {
    return Options(
      headers: requestConfig?.headers,
      extra: requestConfig?.extra,
    );
  }

  CancelToken? _asCancelToken(NetworkCancelToken? token) {
    return token?.rawToken as CancelToken?;
  }

  Headers _toHeaders(Map<String, dynamic> headers) {
    final normalized = <String, List<String>>{};
    headers.forEach((key, value) {
      if (value is List) {
        normalized[key] = value.map((e) => e.toString()).toList();
      } else if (value != null) {
        normalized[key] = [value.toString()];
      }
    });
    return Headers.fromMap(normalized);
  }

  RequestContext _toRequestContext(RequestOptions options) {
    return RequestContext(
      method: options.method,
      path: options.path,
      headers: options.headers,
      queryParameters: options.queryParameters,
      body: options.data,
      extra: options.extra,
    );
  }
}
