import 'package:logging_util/logging_util.dart';

import 'database_adapter.dart';
import 'database_result.dart';
import 'sqlite_database_adapter.dart';

/// 数据库统一入口，默认使用 SQLite，可通过 [configure] 注入其他实现。
class DatabaseClient {
  DatabaseClient(this._adapter);

  final DatabaseAdapter _adapter;

  static DatabaseClient? _instance;

  /// 全局默认实例。
  static DatabaseClient get instance =>
      _instance ??= DatabaseClient(SqliteDatabaseAdapter());

  /// 替换全局默认适配器（如切换到 FFI/内存实现）。
  static DatabaseClient configure(DatabaseAdapter adapter) {
    _instance = DatabaseClient(adapter);
    return _instance!;
  }

  Future<void> init() async {
    LogUtil.d('[DB] 初始化开始');
    await _adapter.init();
    LogUtil.d('[DB] 初始化完成');
  }

  Future<DbResult<int>> insert(
    String table,
    Map<String, Object?> values, {
    bool replaceIfExists = false,
  }) {
    return _wrap(
      action: 'insert $table',
      runner: () => _adapter.insert(
        table,
        values,
        replaceIfExists: replaceIfExists,
      ),
    );
  }

  Future<DbResult<List<Map<String, Object?>>>> query(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    List<String>? columns,
    String? orderBy,
    int? limit,
    int? offset,
  }) {
    return _wrap(
      action: 'query $table',
      runner: () => _adapter.query(
        table,
        where: where,
        whereArgs: whereArgs,
        columns: columns,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      ),
    );
  }

  Future<DbResult<int>> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
  }) {
    return _wrap(
      action: 'update $table',
      runner: () => _adapter.update(
        table,
        values,
        where: where,
        whereArgs: whereArgs,
      ),
    );
  }

  Future<DbResult<int>> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) {
    return _wrap(
      action: 'delete $table',
      runner: () => _adapter.delete(
        table,
        where: where,
        whereArgs: whereArgs,
      ),
    );
  }

  Future<void> close() => _adapter.close();

  Future<DbResult<T>> _wrap<T>({
    required String action,
    required Future<DbResult<T>> Function() runner,
  }) async {
    try {
      final result = await runner();
      if (result.isSuccess) {
        LogUtil.d('[DB] $action 成功');
      } else {
        LogUtil.w('[DB] $action 失败: ${result.message ?? result.error}');
      }
      return result;
    } catch (e, st) {
      LogUtil.e('[DB] $action 异常: $e', st);
      return DbResult.failure(e, message: '$action 异常');
    }
  }
}
