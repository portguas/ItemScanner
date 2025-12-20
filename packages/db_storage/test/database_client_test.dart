import 'dart:io';

import 'package:db_storage/db_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:logging_util/logging_util.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  setUpAll(() {
    LogUtil.init();
  });

  group('DatabaseClient + SqliteDatabaseAdapter', () {
    late Directory tempDir;
    late DatabaseFactory factory;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('db_client_test_');
      factory = databaseFactoryFfi;
      await factory.setDatabasesPath(tempDir.path);
    });

    tearDown(() async {
      await factory.deleteDatabase(p.join(tempDir.path, 'test.db'));
      await tempDir.delete(recursive: true);
    });

    test('支持 CRUD 与回调', () async {
      final adapter = SqliteDatabaseAdapter(
        dbName: 'test.db',
        version: 1,
        factory: factory,
        onCreate: (db, version) async {
          final database = db as Database;
          await database.execute(
            'CREATE TABLE todos(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT)',
          );
        },
      );
      final client = DatabaseClient(adapter);

      await client.init();

      final inserted = await client.insert('todos', {'title': 'learn'});
      expect(inserted.isSuccess, isTrue);
      expect(inserted.data, 1);

      final queried = await client.query('todos');
      queried.when(
        onSuccess: (rows) => expect(rows.first['title'], 'learn'),
        onError: (_, __) => fail('query should succeed'),
      );

      final updated = await client.update(
        'todos',
        {'title': 'done'},
        where: 'id = ?',
        whereArgs: [1],
      );
      expect(updated.data, 1);

      final replaced = await client.insert(
        'todos',
        {'id': 1, 'title': 'replaced'},
        replaceIfExists: true,
      );
      expect(replaced.data, 1);

      final deleted = await client.delete(
        'todos',
        where: 'id = ?',
        whereArgs: [1],
      );
      expect(deleted.data, 1);

      await client.close();
    });
  });
}
