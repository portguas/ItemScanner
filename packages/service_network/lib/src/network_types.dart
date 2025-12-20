import 'dart:async';

import 'package:dio/dio.dart';

typedef RequestHook = FutureOr<RequestContext> Function(RequestContext ctx);
typedef ResponseHook = FutureOr<ResponseContext> Function(ResponseContext ctx);
typedef ErrorHook = FutureOr<ResponseContext?> Function(NetworkErrorContext ctx);
typedef StubResolver = FutureOr<StubResponse?> Function(RequestContext ctx);
typedef NetworkProgressCallback = void Function(int count, int total);

/// 对外暴露的请求上下文，不依赖具体网络库。
class RequestContext {
  const RequestContext({
    required this.method,
    required this.path,
    this.headers = const {},
    this.queryParameters,
    this.body,
    this.extra,
  });

  final String method;
  final String path;
  final Map<String, dynamic> headers;
  final Map<String, dynamic>? queryParameters;
  final dynamic body;
  final Map<String, dynamic>? extra;

  RequestContext copyWith({
    String? method,
    String? path,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? queryParameters,
    dynamic body,
    Map<String, dynamic>? extra,
  }) {
    return RequestContext(
      method: method ?? this.method,
      path: path ?? this.path,
      headers: headers ?? this.headers,
      queryParameters: queryParameters ?? this.queryParameters,
      body: body ?? this.body,
      extra: extra ?? this.extra,
    );
  }
}

/// 对外暴露的响应上下文，不依赖具体网络库。
class ResponseContext {
  const ResponseContext({
    required this.statusCode,
    required this.data,
    required this.request,
    this.headers = const {},
  });

  final int statusCode;
  final dynamic data;
  final RequestContext request;
  final Map<String, dynamic> headers;

  ResponseContext copyWith({
    int? statusCode,
    dynamic data,
    Map<String, dynamic>? headers,
  }) {
    return ResponseContext(
      statusCode: statusCode ?? this.statusCode,
      data: data ?? this.data,
      headers: headers ?? this.headers,
      request: request,
    );
  }
}

/// 桩响应：返回非空值时短路网络请求。
class StubResponse {
  const StubResponse({
    required this.data,
    this.statusCode = 200,
    this.headers = const {},
  });

  final int statusCode;
  final dynamic data;
  final Map<String, dynamic> headers;
}

/// 错误上下文：允许 onError 将异常转为可恢复的 ResponseContext。
class NetworkErrorContext {
  NetworkErrorContext({
    required this.request,
    required this.error,
    this.stackTrace,
  });

  final RequestContext request;
  final Object error;
  final StackTrace? stackTrace;
}

/// 额外的请求配置（如额外 header、extra）。
class RequestConfig {
  const RequestConfig({
    this.headers,
    this.extra,
  });

  final Map<String, dynamic>? headers;
  final Map<String, dynamic>? extra;
}

/// 取消令牌封装，不暴露 Dio。
class NetworkCancelToken {
  NetworkCancelToken() : _inner = CancelToken();

  final CancelToken _inner;

  void cancel([String? reason]) => _inner.cancel(reason);

  bool get isCancelled => _inner.isCancelled;

  /// 仅内部使用：适配到底层网络库。
  Object get rawToken => _inner;
}

class DownloadResult {
  const DownloadResult({
    required this.savePath,
    required this.statusCode,
  });

  final String savePath;
  final int statusCode;
}
