import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/search_model.dart';

class SearchHistoryService {
  static const String _searchHistoryKey = 'search_history';
  static const int _maxHistoryCount = 10;

  // 获取搜索历史
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
      return [];
    }
  }

  // 添加搜索历史
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
  static Future<void> clearSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_searchHistoryKey);
    } catch (e) {
      // 忽略错误
    }
  }

  // 生成唯一ID
  static String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}
