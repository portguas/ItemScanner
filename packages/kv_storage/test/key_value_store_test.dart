import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:kv_storage/kv_storage.dart';

class _InMemoryAdapter implements KeyValueAdapter {
  final Map<String, Object?> _data = {};

  @override
  Future<void> init() async {}

  @override
  Future<bool> containsKey(String key) async => _data.containsKey(key);

  @override
  Future<T?> read<T>(String key) async {
    final value = _data[key];
    if (value is T) {
      return value;
    }
    return value as T?;
  }

  @override
  Future<void> write<T>(String key, T value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }

  @override
  Future<void> clear() async {
    _data.clear();
  }

  @override
  Future<void> close() async {}
}

void main() {
  group('HiveKeyValueAdapter', () {
    late Directory tempDir;
    late HiveInterface hive;

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('kv_store_test_');
      hive = Hive;
      hive.init(tempDir.path);
    });

    tearDown(() async {
      await hive.close();
      await hive.deleteBoxFromDisk('test_box');
    });

    tearDownAll(() async {
      await hive.deleteFromDisk();
      await tempDir.delete(recursive: true);
    });

    test('支持增删查改', () async {
      final adapter = HiveKeyValueAdapter(
        boxName: 'test_box',
        hive: hive,
        initializer: () async {},
      );
      final store = KeyValueStore(adapter);

      await store.init();

      expect(await store.containsKey('foo'), isFalse);

      await store.write('foo', 'bar');
      expect(await store.read<String>('foo'), 'bar');

      await store.write('foo', 'baz');
      expect(await store.read<String>('foo'), 'baz');

      await store.write('count', 1);
      expect(await store.read<int>('count'), 1);

      await store.delete('count');
      expect(await store.containsKey('count'), isFalse);

      await store.clear();
      expect(await store.containsKey('foo'), isFalse);

      await store.close();
    });
  });

  test('configure 可快速切换适配器', () async {
    final memoryAdapter = _InMemoryAdapter();
    final store = KeyValueStore.configure(memoryAdapter);

    await store.init();
    await store.write('key', 'value');
    expect(await store.read<String>('key'), 'value');

    await store.clear();
    expect(await store.containsKey('key'), isFalse);

    await store.close();
  });
}
