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

/// 搜索历史服务：提供静态方法便于直接调用
class SearchHistoryService {
  /// SharedPreferences 的键名
  static const String _searchHistoryKey = 'search_history';
  /// 历史记录最大条数
  static const int _maxHistoryCount = 10;

  // 获取搜索历史
  /// 返回值：最新在前的 `SearchHistoryItem` 列表；失败时返回空列表。
  /// 解析：从 StringList 中逐条 decode JSON -> Map -> `SearchHistoryItem`。
  static Future<List<SearchHistoryItem>> getSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList(_searchHistoryKey) ?? [];

      return historyJson
          .map(
            (jsonString) => SearchHistoryItem.fromMap(json.decode(jsonString)),
          )
          .toList();
    } catch (e) {
      // 解析或存取异常时，返回空列表以保证上层 UI 不崩溃。
      return [];
    }
  }

  // 添加搜索历史
  /// 行为：
  /// 1) 读取当前历史；
  /// 2) 去重（按 keyword + searchType）；
  /// 3) 头插（最新在前）；
  /// 4) 截断至最大容量并持久化（编码为 JSON StringList）。
  static Future<void> addSearchHistory(SearchHistoryItem item) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<SearchHistoryItem> history = await getSearchHistory();

      // 移除重复项
      history.removeWhere(
        (h) => h.keyword == item.keyword && h.searchType == item.searchType,
      );

      // 添加到开头
      history.insert(0, item);

      // 限制数量
      if (history.length > _maxHistoryCount) {
        history = history.sublist(0, _maxHistoryCount);
      }

      // 保存 - 将Map转换为JSON字符串
      final historyJson = history
          .map((item) => json.encode(item.toMap()))
          .toList();
      await prefs.setStringList(_searchHistoryKey, historyJson);
    } catch (e) {
      // 忽略错误
    }
  }

  // 删除单条搜索历史
  /// 按 id 精确删除；若 id 不存在则不做处理。
  static Future<void> removeSearchHistory(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<SearchHistoryItem> history = await getSearchHistory();

      history.removeWhere((item) => item.id == id);

      final historyJson = history
          .map((item) => json.encode(item.toMap()))
          .toList();
      await prefs.setStringList(_searchHistoryKey, historyJson);
    } catch (e) {
      // 忽略错误
    }
  }

  // 清空搜索历史
  /// 直接移除对应 key；调用后 `getSearchHistory()` 将返回空列表。
  static Future<void> clearSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_searchHistoryKey);
    } catch (e) {
      // 忽略错误
    }
  }

  // 生成唯一ID
  /// 使用当前毫秒时间戳作为字符串 ID；
  /// 在多数场景下可满足唯一性需求，但跨设备并发场景不保证绝对唯一。
  static String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}
