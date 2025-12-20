import 'hive_key_value_adapter.dart';
import 'key_value_adapter.dart';

/// KV 存储统一入口，默认使用 Hive 适配器，可通过 [configure] 替换实现。
class KeyValueStore {
  KeyValueStore(this._adapter);

  final KeyValueAdapter _adapter;

  static KeyValueStore? _instance;

  /// 默认实例，未显式配置时使用 Hive 作为底层实现。
  static KeyValueStore get instance =>
      _instance ??= KeyValueStore(HiveKeyValueAdapter());

  /// 使用自定义适配器重置全局实例，例如 SharedPreferences 适配器。
  static KeyValueStore configure(KeyValueAdapter adapter) {
    _instance = KeyValueStore(adapter);
    return _instance!;
  }

  Future<void> init() => _adapter.init();

  Future<bool> containsKey(String key) => _adapter.containsKey(key);

  Future<T?> read<T>(String key) => _adapter.read<T>(key);

  Future<void> write<T>(String key, T value) => _adapter.write<T>(key, value);

  Future<void> delete(String key) => _adapter.delete(key);

  Future<void> clear() => _adapter.clear();

  Future<void> close() => _adapter.close();
}
