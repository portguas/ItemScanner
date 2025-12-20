import 'package:dio/dio.dart';

/// App-level exception with detailed context converted from Dio errors.
class AppException implements Exception {
  /// Human readable message for UI or logs.
  final String message;

  /// Optional HTTP status or business code.
  final int? code;

  /// Original Dio error type for diagnostics.
  final DioExceptionType? dioType;

  /// Raw data returned by backend (if any).
  final dynamic data;

  /// Original error to keep full context.
  final Object? original;

  /// Stack trace captured at creation time.
  final StackTrace? stackTrace;

  const AppException({
    required this.message,
    this.code,
    this.dioType,
    this.data,
    this.original,
    this.stackTrace,
  });

  /// Factory to normalize all Dio exceptions.
  factory AppException.fromDio(DioException exception) {
    final statusCode = exception.response?.statusCode;
    final payload = exception.response?.data;

    final readableMessage = switch (exception.type) {
      DioExceptionType.connectionTimeout => '连接超时，请稍后重试',
      DioExceptionType.sendTimeout => '请求发送超时',
      DioExceptionType.receiveTimeout => '响应超时',
      DioExceptionType.cancel => '请求已取消',
      DioExceptionType.badCertificate => '证书校验失败',
      DioExceptionType.connectionError => '网络连接异常',
      DioExceptionType.badResponse =>
          _mapStatusCode(statusCode, payload) ?? '响应异常($statusCode)',
      DioExceptionType.unknown => '未知网络错误，请检查连接',
    };

    return AppException(
      message: readableMessage,
      code: statusCode,
      dioType: exception.type,
      data: payload,
      original: exception,
      stackTrace: exception.stackTrace,
    );
  }

  /// Factory to build business-level exception from backend payload.
  factory AppException.business({
    int? code,
    String? message,
    dynamic data,
  }) {
    return AppException(
      message: message ?? '业务异常',
      code: code,
      data: data,
    );
  }

  /// Maps HTTP status code to a consistent readable message.
  static String? _mapStatusCode(int? statusCode, dynamic payload) {
    if (payload is Map<String, dynamic>) {
      final serverMessage = payload['message'] as String?;
      if (serverMessage != null && serverMessage.isNotEmpty) {
        return serverMessage;
      }
    }
    return switch (statusCode) {
      400 => '请求参数错误',
      401 => '未授权或登录已过期',
      403 => '没有访问权限',
      404 => '资源不存在',
      500 => '服务器内部错误',
      502 => '网关异常',
      503 => '服务暂不可用',
      504 => '网关超时',
      _ => statusCode != null ? '服务异常($statusCode)' : null,
    };
  }

  @override
  String toString() =>
      'AppException(code: $code, message: $message, data: $data)';
}
