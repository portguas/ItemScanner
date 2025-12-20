/// KV 存储适配接口，方便按需替换 Hive、SharedPreferences 等实现。
abstract class KeyValueAdapter {
  Future<void> init();

  Future<bool> containsKey(String key);

  Future<T?> read<T>(String key);

  Future<void> write<T>(String key, T value);

  Future<void> delete(String key);

  Future<void> clear();

  Future<void> close();
}
