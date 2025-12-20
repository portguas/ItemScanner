import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'network_types.dart';

typedef HeaderProvider = FutureOr<Map<String, String>?> Function();
typedef TokenProvider = FutureOr<String?> Function();

/// Config object to initialise [Dio] with consistent defaults.
class NetworkConfig {
  final String baseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final HeaderProvider? headerProvider;
  final TokenProvider? tokenProvider;
  final StubResolver? stubResolver;
  final RequestHook? onRequest;
  final ResponseHook? onResponse;
  final ErrorHook? onError;
  final bool enableNetworkLog;

  const NetworkConfig({
    this.baseUrl = '',
    this.connectTimeout = const Duration(seconds: 15),
    this.receiveTimeout = const Duration(seconds: 15),
    this.headerProvider,
    this.tokenProvider,
    this.stubResolver,
    this.onRequest,
    this.onResponse,
    this.onError,
    bool? enableNetworkLog,
  }) : enableNetworkLog = enableNetworkLog ?? kDebugMode;

  BaseOptions toBaseOptions() {
    return BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    );
  }
}
