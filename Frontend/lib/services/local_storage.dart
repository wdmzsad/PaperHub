import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 简单封装：提供同步读取 + 持久化存储（底层使用 SharedPreferences）。
class LocalStorage {
  LocalStorage._private();
  static final LocalStorage instance = LocalStorage._private();

  SharedPreferences? _prefs;
  final Map<String, String> _cache = {};

  /// 在应用启动时调用，预加载 SharedPreferences 数据。
  Future<void> init() async {
    // 确保 _prefs 已初始化
    _prefs ??= await SharedPreferences.getInstance();
    final prefs = _prefs;
    if (prefs == null) return;

    // 清空缓存并重新加载所有数据（Web 刷新时需要重新加载）
    _cache.clear();
    final keys = prefs.getKeys();
    for (final key in keys) {
      final value = prefs.getString(key);
      if (value != null) {
        _cache[key] = value;
      }
    }
    
    if (kDebugMode) {
      print('LocalStorage.init(): 已加载 ${_cache.length} 个键到缓存');
      if (_cache.containsKey('accessToken')) {
        print('LocalStorage.init(): accessToken 已加载 (${_cache['accessToken']!.length} chars)');
      }
      if (_cache.containsKey('refreshToken')) {
        print('LocalStorage.init(): refreshToken 已加载 (${_cache['refreshToken']!.length} chars)');
      }
    }
  }

  Future<void> write(String key, String value) async {
    await _ensurePrefs();
    _cache[key] = value;
    await _prefs?.setString(key, value);
    // 在调试模式下，如果写入的是 token 相关键，记录日志
    if (kDebugMode && (key == 'accessToken' || key == 'refreshToken')) {
      print('LocalStorage.write($key): saved (${value.length} chars), cache now has: ${_cache[key] != null ? "present" : "missing"}');
    }
  }

  Future<void> delete(String key) async {
    await _ensurePrefs();
    _cache.remove(key);
    await _prefs?.remove(key);
  }

  String? read(String key) {
    // 先从缓存读取
    var value = _cache[key];
    
    // 如果缓存中没有，但 _prefs 已经初始化，尝试从 _prefs 读取（Web 刷新时可能出现这种情况）
    if (value == null && _prefs != null) {
      final prefsValue = _prefs!.getString(key);
      if (prefsValue != null) {
        // 更新缓存，避免下次再读取
        _cache[key] = prefsValue;
        value = prefsValue;
        // 只在从 _prefs 读取时才记录日志（这是特殊情况，值得记录）
        if (kDebugMode && (key == 'accessToken' || key == 'refreshToken')) {
          print('LocalStorage.read($key): 从_prefs读取并更新缓存 (${value.length} chars)');
        }
      }
    }
    
    // 移除常规读取的日志，减少控制台输出
    // 只在关键操作（write、init）时记录日志
    return value;
  }

  Future<void> _ensurePrefs() async {
    if (_prefs == null) {
      await init();
    }
  }
}
