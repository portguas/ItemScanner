// 保留向后兼容：将旧的 Log API 转发到 LogUtil。
import 'log_util.dart';

@Deprecated('请使用 LogUtil')
class Log {
  static void d(dynamic message, [String? tag]) =>
      LogUtil.d(tag != null ? '[$tag] $message' : message);

  static void i(dynamic message, [String? tag]) =>
      LogUtil.i(tag != null ? '[$tag] $message' : message);

  static void w(dynamic message, [String? tag]) =>
      LogUtil.w(tag != null ? '[$tag] $message' : message);

  static void e(
    dynamic message, [
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  ]) {
    final merged = tag != null ? '[$tag] $message' : message;
    LogUtil.e(merged, stackTrace ?? (error is Error ? error.stackTrace : null));
  }
}
