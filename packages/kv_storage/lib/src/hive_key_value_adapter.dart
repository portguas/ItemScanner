import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'key_value_adapter.dart';

/// Hive 版 KV 适配器，默认使用 `Hive.initFlutter` 初始化。
/// 可通过自定义 [hive] 与 [initializer] 适配测试或替换存储目录。
class HiveKeyValueAdapter implements KeyValueAdapter {
  HiveKeyValueAdapter({
    this.boxName = 'app_cache',
    HiveInterface? hive,
    Future<void> Function()? initializer,
  })  : _hive = hive ?? Hive,
        _initializer = initializer ?? Hive.initFlutter;

  final HiveInterface _hive;
  final Future<void> Function() _initializer;
  final String boxName;

  Box<dynamic>? _box;
  bool _didInitHive = false;

  Future<Box<dynamic>> _ensureBox() async {
    if (_box?.isOpen == true) {
      return _box!;
    }

    if (!_didInitHive) {
      await _initializer();
      _didInitHive = true;
    }

    if (_hive.isBoxOpen(boxName)) {
      _box = _hive.box<dynamic>(boxName);
    } else {
      _box = await _hive.openBox<dynamic>(boxName);
    }
    return _box!;
  }

  @override
  Future<void> init() async {
    await _ensureBox();
  }

  @override
  Future<bool> containsKey(String key) async {
    final box = await _ensureBox();
    return box.containsKey(key);
  }

  @override
  Future<T?> read<T>(String key) async {
    final box = await _ensureBox();
    final value = box.get(key);
    if (value is T) {
      return value;
    }
    return value as T?;
  }

  @override
  Future<void> write<T>(String key, T value) async {
    final box = await _ensureBox();
    await box.put(key, value);
  }

  @override
  Future<void> delete(String key) async {
    final box = await _ensureBox();
    await box.delete(key);
  }

  @override
  Future<void> clear() async {
    final box = await _ensureBox();
    await box.clear();
  }

  @override
  Future<void> close() async {
    if (_box?.isOpen == true) {
      await _box!.close();
    }
  }
}
