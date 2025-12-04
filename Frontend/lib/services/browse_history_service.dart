import 'dart:convert';

import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 单条浏览历史记录
class BrowseHistoryItem {
  final String postId;
  final String title;
  final int timestamp; // 浏览时间（毫秒）

  BrowseHistoryItem({
    required this.postId,
    required this.title,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'title': title,
      'timestamp': timestamp,
    };
  }

  factory BrowseHistoryItem.fromMap(Map<String, dynamic> map) {
    return BrowseHistoryItem(
      postId: map['postId']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      timestamp: (map['timestamp'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }
}

/// 浏览历史服务：
/// - 优先调用后端 API，若失败回退到本地 SharedPreferences 缓存。
/// - 本地缓存按用户划分 key：browse_history_<userId>，只存最近 50 条。
class BrowseHistoryService {
  static const int _maxHistoryCount = 50;

  static String _keyForUser(String userId) => 'browse_history_$userId';

  /// 获取指定用户的浏览历史（最新在前）
  static Future<List<BrowseHistoryItem>> getHistory(String userId) async {
    if (userId.isEmpty) return [];
    // 优先从后端获取，失败时回退到本地缓存
    try {
      final resp = await ApiService.getBrowseHistory(limit: _maxHistoryCount);
      if (resp['statusCode'] == 200) {
        final body = resp['body'] as Map<String, dynamic>?;
        final items = (body?['items'] as List<dynamic>? ?? [])
            .map((e) => e as Map<String, dynamic>)
            .map(
              (m) => BrowseHistoryItem(
                postId: m['postId']?.toString() ?? '',
                title: m['title']?.toString() ?? '',
                timestamp: DateTime.parse(
                  (m['viewedAt'] ?? DateTime.now().toIso8601String()).toString(),
                ).millisecondsSinceEpoch,
              ),
            )
            .toList();
        // 同步一份到本地，作为缓存
        await _saveToLocal(userId, items);
        return items;
      }
    } catch (_) {
      // ignore and fallback
    }
    return _getFromLocal(userId);
  }

  /// 添加一条浏览历史（若已存在该 postId，则先删除旧记录）
  static Future<void> addHistory({
    required String userId,
    required String postId,
    required String title,
  }) async {
    if (userId.isEmpty || postId.isEmpty) return;
    // 后端记录（忽略失败），本地也维护一份缓存
    try {
      await ApiService.addBrowseHistory(postId: postId, title: title);
    } catch (_) {}
    await _addToLocal(userId, postId, title);
  }

  /// 按 postId 删除浏览记录（用于帖子被删除时清理）
  static Future<void> removeByPostId(String userId, String postId) async {
    if (userId.isEmpty || postId.isEmpty) return;
    try {
      await ApiService.deleteBrowseHistory(postId);
    } catch (_) {}
    await _removeFromLocal(userId, postId);
  }

  /// 清空某个用户的浏览历史
  static Future<void> clearHistory(String userId) async {
    if (userId.isEmpty) return;
    try {
      await ApiService.clearBrowseHistory();
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyForUser(userId));
    } catch (_) {
      // ignore
    }
  }

  /// ================= 本地缓存辅助 =================

  static Future<void> _saveToLocal(String userId, List<BrowseHistoryItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = items
          .map((item) => json.encode(item.toMap()))
          .toList();
      await prefs.setStringList(_keyForUser(userId), encoded);
    } catch (_) {}
  }

  static Future<List<BrowseHistoryItem>> _getFromLocal(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_keyForUser(userId)) ?? [];
      return list
          .map((s) => BrowseHistoryItem.fromMap(json.decode(s)))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (_) {
      return [];
    }
  }

  static Future<void> _addToLocal(String userId, String postId, String title) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _keyForUser(userId);
      List<BrowseHistoryItem> history = await _getFromLocal(userId);
      history.removeWhere((h) => h.postId == postId);
      history.insert(
        0,
        BrowseHistoryItem(
          postId: postId,
          title: title,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      if (history.length > _maxHistoryCount) {
        history = history.sublist(0, _maxHistoryCount);
      }
      final encoded = history.map((h) => json.encode(h.toMap())).toList();
      await prefs.setStringList(key, encoded);
    } catch (_) {}
  }

  static Future<void> _removeFromLocal(String userId, String postId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _keyForUser(userId);
      List<BrowseHistoryItem> history = await _getFromLocal(userId);
      history.removeWhere((h) => h.postId == postId);
      final encoded = history.map((h) => json.encode(h.toMap())).toList();
      await prefs.setStringList(key, encoded);
    } catch (_) {}
  }
}


