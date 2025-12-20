import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:logging_util/logging_util.dart';

import 'database_adapter.dart';
import 'database_result.dart';

/// 默认的 SQLite 适配器，可按需注入 [DatabaseFactory] 与回调。
class SqliteDatabaseAdapter implements DatabaseAdapter {
  SqliteDatabaseAdapter({
    this.dbName = 'app.db',
    this.version = 1,
    this.onCreate,
    this.onUpgrade,
    this.onDowngrade,
    DatabaseFactory? factory,
    Future<String> Function()? pathBuilder,
  })  : _factory = factory ?? databaseFactory,
        _pathBuilder = pathBuilder;

  final String dbName;
  final int version;
  final DbCreateCallback? onCreate;
  final DbUpgradeCallback? onUpgrade;
  final DbDowngradeCallback? onDowngrade;
  final DatabaseFactory _factory;
  final Future<String> Function()? _pathBuilder;

  Database? _db;

  @override
  Future<void> init() async {
    await _ensureDb();
  }

  @override
  Future<DbResult<int>> insert(
    String table,
    Map<String, Object?> values, {
    bool replaceIfExists = false,
  }) async {
    try {
      final db = await _ensureDb();
      final id = await db.insert(
        table,
        values,
        conflictAlgorithm:
            replaceIfExists ? ConflictAlgorithm.replace : ConflictAlgorithm.abort,
      );
      return DbResult.success(id);
    } catch (e, st) {
      LogUtil.e('[DB] insert $table 失败: $e', st);
      return DbResult.failure(e, message: '插入失败');
    }
  }

  @override
  Future<DbResult<List<Map<String, Object?>>>> query(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    List<String>? columns,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      final db = await _ensureDb();
      final rows = await db.query(
        table,
        columns: columns,
        where: where,
        whereArgs: whereArgs,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      );
      return DbResult.success(rows);
    } catch (e, st) {
      LogUtil.e('[DB] query $table 失败: $e', st);
      return DbResult.failure(e, message: '查询失败');
    }
  }

  @override
  Future<DbResult<int>> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    try {
      final db = await _ensureDb();
      final count = await db.update(
        table,
        values,
        where: where,
        whereArgs: whereArgs,
      );
      return DbResult.success(count);
    } catch (e, st) {
      LogUtil.e('[DB] update $table 失败: $e', st);
      return DbResult.failure(e, message: '更新失败');
    }
  }

  @override
  Future<DbResult<int>> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    try {
      final db = await _ensureDb();
      final count = await db.delete(
        table,
        where: where,
        whereArgs: whereArgs,
      );
      return DbResult.success(count);
    } catch (e, st) {
      LogUtil.e('[DB] delete $table 失败: $e', st);
      return DbResult.failure(e, message: '删除失败');
    }
  }

  @override
  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      LogUtil.d('[DB] 数据库已关闭');
      _db = null;
    }
  }

  Future<Database> _ensureDb() async {
    if (_db != null) {
      return _db!;
    }
    final path = await _resolvePath();
    LogUtil.d('[DB] 打开 SQLite 数据库: $path');
    _db = await _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: version,
        onCreate: onCreate != null
            ? (db, version) => onCreate!(db, version)
            : null,
        onUpgrade: onUpgrade != null
            ? (db, oldVersion, newVersion) =>
                onUpgrade!(db, oldVersion, newVersion)
            : null,
        onDowngrade: onDowngrade != null
            ? (db, oldVersion, newVersion) =>
                onDowngrade!(db, oldVersion, newVersion)
            : null,
      ),
    );
    return _db!;
  }

  Future<String> _resolvePath() async {
    if (_pathBuilder != null) {
      return _pathBuilder!();
    }
    final base = await _factory.getDatabasesPath();
    return p.join(base, dbName);
  }
}
