/// 搜索历史服务（基于 SharedPreferences 的轻量持久化）
///
/// 功能职责：
/// - 读取/新增/删除/清空 搜索历史记录；
/// - 生成唯一 ID（毫秒时间戳字符串）。
///
/// 数据存储方案：
/// - 使用 `SharedPreferences` 的 `StringList` 存储，每个元素为一条历史记录的 JSON 字符串；
/// - JSON Schema（与 `SearchHistoryItem.toMap()` 对齐）：
///   {
///     "id": String,                 // 唯一标识（毫秒时间戳字符串）
///     "keyword": String,            // 搜索关键词
///     "searchType": String,         // 'keyword' | 'tag' | 'author'
///     "timestamp": int              // 毫秒 since epoch（本地时间）
///   }
/// - 列表顺序：最新在前（add 时插入到头部）。
///
/// 容量与去重策略：
/// - 最多保存 `_maxHistoryCount` 条，多余的会截断尾部；
/// - 去重按（keyword + searchType）维度，如已存在则先移除旧项再插入新项到头部。
///
/// 错误处理：
/// - 所有方法使用 try/catch 捕获异常并静默处理（读取失败返回空列表、写入失败忽略）；
/// - 适用于不阻断主流程的弱依赖场景；如需更严格监控，可在 catch 中上报日志。
///
/// 并发与一致性：
/// - 该服务为简单本地存储封装，未做并发合并控制；
/// - 若多处并发写入，可能存在覆盖；建议外层在交互上做节流/防抖。
///
/// 迁移注意：
/// - 如后续改动 Schema 或存储介质（例如切换到数据库），请提供兼容迁移逻辑；
/// - `_searchHistoryKey` 为数据 Key，请谨慎修改，避免丢失既有数据。
///
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/search_model.dart';
import '../services/api_service.dart';
import '../services/local_storage.dart';

/// 搜索历史服务：提供静态方法便于直接调用
///
/// 增强版：支持云端存储（优先）与本地缓存（回退）
/// - 用户登录时：优先从云端加载搜索历史，失败时回退到本地存储
/// - 添加历史：同时保存到云端和本地（云端失败时仅保存到本地）
/// - 删除/清空：同步操作云端和本地
class SearchHistoryService {
  /// SharedPreferences 的键名前缀（按用户隔离）
  static String _searchHistoryKey(String userId) => 'search_history_$userId';

  /// 本地历史记录最大条数（用于显示）
  static const int _maxLocalHistoryCount = 20;

  /// 云端历史记录最大条数（用于推荐算法，由后端控制）

  /// 获取当前用户ID（从LocalStorage）
  static String? _getCurrentUserId() {
    return LocalStorage.instance.read('userId');
  }

  // 获取搜索历史
  /// 返回值：最新在前的 `SearchHistoryItem` 列表；失败时返回空列表。
  /// 策略：优先从云端获取，失败时回退到本地存储
  static Future<List<SearchHistoryItem>> getSearchHistory() async {
    final userId = _getCurrentUserId();
    if (userId == null || userId.isEmpty) {
      // 用户未登录，只返回本地存储的历史（如果有）
      return await _getFromLocal('');
    }

    // 优先从云端获取
    try {
      final resp = await ApiService.getSearchHistory(limit: _maxLocalHistoryCount);
      if (resp['statusCode'] == 200) {
        final body = resp['body'] as Map<String, dynamic>?;
        final items = (body?['items'] as List<dynamic>? ?? [])
            .map((e) => e as Map<String, dynamic>)
            .map(SearchHistoryItem.fromCloudData)
            .toList();

        // 同步到本地缓存
        await _saveToLocal(userId, items);
        return items;
      }
    } catch (_) {
      // ignore and fallback
    }

    // 回退到本地存储
    return await _getFromLocal(userId);
  }

  // 添加搜索历史
  /// 行为：
  /// 1) 保存到云端（如果用户已登录）
  /// 2) 保存到本地存储
  /// 3) 去重（按 keyword + searchType）
  /// 4) 头插（最新在前）
  /// 5) 截断至最大容量
  static Future<void> addSearchHistory(SearchHistoryItem item) async {
    final userId = _getCurrentUserId();

    // 保存到云端（如果用户已登录）
    if (userId != null && userId.isNotEmpty) {
      try {
        await ApiService.addSearchHistory(
          keyword: item.keyword,
          searchType: item.searchType,
        );
      } catch (_) {
        // 忽略错误，继续保存到本地
      }
    }

    // 保存到本地存储
    await _addToLocal(userId ?? '', item);
  }

  // 删除单条搜索历史
  /// 按 id 精确删除；同时删除云端和本地记录
  static Future<void> removeSearchHistory(String id) async {
    final userId = _getCurrentUserId();

    // 删除云端记录（如果用户已登录且ID是数字，可能是云端ID）
    if (userId != null && userId.isNotEmpty) {
      try {
        // 尝试将ID解析为数字，如果是云端ID
        final cloudId = int.tryParse(id);
        if (cloudId != null && cloudId > 0) {
          await ApiService.deleteSearchHistory(id);
        }
      } catch (_) {
        // 忽略错误
      }
    }

    // 删除本地记录（同时处理云端ID和本地时间戳ID）
    await _removeFromLocal(userId ?? '', id);
  }

  // 清空搜索历史
  /// 清空云端和本地的搜索历史
  static Future<void> clearSearchHistory() async {
    final userId = _getCurrentUserId();

    // 清空云端历史（如果用户已登录）
    if (userId != null && userId.isNotEmpty) {
      try {
        await ApiService.clearSearchHistory();
      } catch (_) {
        // 忽略错误
      }
    }

    // 清空本地历史
    await _clearLocal(userId ?? '');
  }

  // 生成唯一ID
  /// 使用当前毫秒时间戳作为字符串 ID；
  /// 在多数场景下可满足唯一性需求，但跨设备并发场景不保证绝对唯一。
  static String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// ================= 本地存储辅助方法 =================

  /// 从本地存储获取搜索历史
  static Future<List<SearchHistoryItem>> _getFromLocal(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _searchHistoryKey(userId);
      final historyJson = prefs.getStringList(key) ?? [];

      return historyJson
          .map((jsonString) => SearchHistoryItem.fromMap(json.decode(jsonString)))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp)); // 按时间倒序
    } catch (_) {
      return [];
    }
  }

  /// 保存搜索历史到本地存储
  static Future<void> _saveToLocal(String userId, List<SearchHistoryItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _searchHistoryKey(userId);
      final historyJson = items
          .map((item) => json.encode(item.toMap()))
          .toList();
      await prefs.setStringList(key, historyJson);
    } catch (_) {
      // 忽略错误
    }
  }

  /// 添加单条搜索历史到本地存储
  static Future<void> _addToLocal(String userId, SearchHistoryItem item) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _searchHistoryKey(userId);
      List<SearchHistoryItem> history = await _getFromLocal(userId);

      // 去重（按 keyword + searchType）
      history.removeWhere(
        (h) => h.keyword == item.keyword && h.searchType == item.searchType,
      );

      // 添加到开头
      history.insert(0, item);

      // 限制数量
      if (history.length > _maxLocalHistoryCount) {
        history = history.sublist(0, _maxLocalHistoryCount);
      }

      // 保存
      final historyJson = history
          .map((item) => json.encode(item.toMap()))
          .toList();
      await prefs.setStringList(key, historyJson);
    } catch (_) {
      // 忽略错误
    }
  }

  /// 从本地存储删除单条搜索历史
  static Future<void> _removeFromLocal(String userId, String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _searchHistoryKey(userId);
      List<SearchHistoryItem> history = await _getFromLocal(userId);

      history.removeWhere((item) => item.id == id);

      final historyJson = history
          .map((item) => json.encode(item.toMap()))
          .toList();
      await prefs.setStringList(key, historyJson);
    } catch (_) {
      // 忽略错误
    }
  }

  /// 清空本地搜索历史
  static Future<void> _clearLocal(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _searchHistoryKey(userId);
      await prefs.remove(key);
    } catch (_) {
      // 忽略错误
    }
  }
}
