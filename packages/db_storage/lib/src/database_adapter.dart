import 'database_result.dart';

typedef DbCreateCallback = Future<void> Function(Object db, int version);
typedef DbUpgradeCallback = Future<void> Function(
  Object db,
  int oldVersion,
  int newVersion,
);
typedef DbDowngradeCallback = Future<void> Function(
  Object db,
  int oldVersion,
  int newVersion,
);

/// 数据库适配接口，方便底层实现替换（如 SQLite、SharedPreferences、IndexedDB）。
abstract class DatabaseAdapter {
  Future<void> init();

  Future<DbResult<int>> insert(
    String table,
    Map<String, Object?> values, {
    bool replaceIfExists = false,
  });

  Future<DbResult<List<Map<String, Object?>>>> query(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    List<String>? columns,
    String? orderBy,
    int? limit,
    int? offset,
  });

  Future<DbResult<int>> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
  });

  Future<DbResult<int>> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  });

  Future<void> close();
}
