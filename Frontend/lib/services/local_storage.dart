import 'package:shared_preferences/shared_preferences.dart';

/// 简单封装：提供同步读取 + 持久化存储（底层使用 SharedPreferences）。
class LocalStorage {
  LocalStorage._private();
  static final LocalStorage instance = LocalStorage._private();

  SharedPreferences? _prefs;
  final Map<String, String> _cache = {};

  /// 在应用启动时调用，预加载 SharedPreferences 数据。
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    final prefs = _prefs;
    if (prefs == null) return;

    _cache
      ..clear()
      ..addEntries(
        prefs
            .getKeys()
            .map(
              (key) {
                final value = prefs.getString(key);
                return value == null ? null : MapEntry(key, value);
              },
            )
            .whereType<MapEntry<String, String>>(),
      );
  }

  Future<void> write(String key, String value) async {
    await _ensurePrefs();
    _cache[key] = value;
    await _prefs?.setString(key, value);
  }

  Future<void> delete(String key) async {
    await _ensurePrefs();
    _cache.remove(key);
    await _prefs?.remove(key);
  }

  String? read(String key) {
    return _cache[key];
  }

  Future<void> _ensurePrefs() async {
    if (_prefs == null) {
      await init();
    }
  }
}
