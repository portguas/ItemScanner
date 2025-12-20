import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

typedef LogErrorReporter = FutureOr<void> Function(
  String message,
  Object? error,
  StackTrace? stackTrace,
);

typedef LogFileWriter = FutureOr<void> Function(String line);

/// 通用日志管理工具，封装 logger，提供环境感知、文件/远程扩展能力。
class LogUtil {
  LogUtil._();

  static Logger? _logger;
  static LogErrorReporter? _errorReporter;
  static LogFileWriter? _fileWriter;

  /// 初始化日志配置，可在 `main` 中调用一次。
  static void init({
    LogErrorReporter? errorReporter,
    LogFileWriter? fileWriter,
  }) {
    _errorReporter = errorReporter;
    _fileWriter = fileWriter;
    _logger = _buildLogger();
  }

  static void v(dynamic message) => _log(Level.verbose, message);

  static void d(dynamic message) => _log(Level.debug, message);

  static void i(dynamic message) => _log(Level.info, message);

  static void w(dynamic message) => _log(Level.warning, message);

  static void e(dynamic message, [StackTrace? stackTrace]) =>
      _log(Level.error, message, stackTrace: stackTrace);

  static void _log(
    Level level,
    dynamic message, {
    StackTrace? stackTrace,
  }) {
    _logger ??= _buildLogger();
    _logger!.log(level, message, stackTrace: stackTrace);

    // 错误级别额外触发远程上报，保持非阻塞。
    if (level.index >= Level.error.index && _errorReporter != null) {
      final payload = message?.toString() ?? '';
      Future.sync(
        () => _errorReporter!(
          payload,
          message is Object ? message : null,
          stackTrace,
        ),
      ).ignore();
    }
  }

  static Logger _buildLogger() {
    final isRelease = kReleaseMode;
    return Logger(
      filter: _EnvLogFilter(),
      printer: PrettyPrinter(
        methodCount: isRelease ? 0 : 4,
        errorMethodCount: isRelease ? 3 : 8,
        colors: !isRelease,
        printEmojis: !isRelease,
        lineLength: 120,
      ),
      output: _CompositeOutput(
        consoleOutput: ConsoleOutput(),
        fileWriter: _fileWriter,
      ),
    );
  }
}

/// 环境过滤：Release 仅输出 Warning/Error。
class _EnvLogFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    if (kReleaseMode) {
      return event.level.index >= Level.warning.index;
    }
    return true;
  }
}

/// 复合输出：控制台 + 可选文件写入。
class _CompositeOutput extends LogOutput {
  _CompositeOutput({
    required this.consoleOutput,
    this.fileWriter,
  });

  final LogOutput consoleOutput;
  final LogFileWriter? fileWriter;

  @override
  void output(OutputEvent event) {
    consoleOutput.output(event);

    if (fileWriter == null) {
      return;
    }

    final payload = event.lines.join('\n');
    final isErrorLevel = event.level == Level.error || event.level == Level.wtf;
    if (isErrorLevel) {
      Future.sync(() => fileWriter!(payload)).ignore();
    }
  }
}

extension _FutureIgnore on FutureOr<void> {
  /// 忽略 Future 错误，避免日志链路影响业务。
  void ignore() {
    if (this is Future<void>) {
      (this as Future<void>).catchError((_) {});
    }
  }
}
