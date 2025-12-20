/// 统一的数据库操作结果封装。
class DbResult<T> {
  DbResult._({
    required this.isSuccess,
    this.data,
    this.error,
    this.message,
  });

  final bool isSuccess;
  final T? data;
  final Object? error;
  final String? message;

  factory DbResult.success(T data, {String? message}) => DbResult._(
        isSuccess: true,
        data: data,
        message: message,
      );

  factory DbResult.failure(Object error, {String? message}) => DbResult._(
        isSuccess: false,
        error: error,
        message: message,
      );

  /// 友好的回调调用方式，便于 UI/业务层统一处理。
  R when<R>({
    required R Function(T data) onSuccess,
    required R Function(Object error, String? message) onError,
  }) {
    if (isSuccess) {
      return onSuccess(data as T);
    }
    return onError(error!, message);
  }
}
