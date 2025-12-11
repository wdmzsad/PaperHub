import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/notification_model.dart';
import '../services/api_service.dart';

/// 全局未读状态，负责聚合聊天与通知的 badge。
class UnreadService extends ChangeNotifier {
  UnreadService._();

  static final UnreadService instance = UnreadService._();

  int _chatUnread = 0;
  UnreadCount _notificationCount =
      UnreadCount(likes: 0, follows: 0, comments: 0);

  Timer? _pollingTimer;
  static const Duration _pollingInterval = Duration(seconds: 30); // 30秒轮询一次

  int get chatUnread => _chatUnread;

  UnreadCount get notificationCount => _notificationCount;

  int get notificationsUnread =>
      _notificationCount.likes +
      _notificationCount.follows +
      _notificationCount.comments;

  /// 聊天 tab 的小红点显示所有聊天 + 通知未读
  int get totalMessageBadge => chatUnread + notificationsUnread;

  void updateChatUnread(int count) {
    if (count == _chatUnread) return;
    _chatUnread = count;
    notifyListeners();
  }

  void updateNotificationUnread(UnreadCount count) {
    if (_notificationCount.likes == count.likes &&
        _notificationCount.follows == count.follows &&
        _notificationCount.comments == count.comments) {
      return;
    }
    _notificationCount = count;
    notifyListeners();
  }

  void resetAll() {
    _chatUnread = 0;
    _notificationCount = UnreadCount(likes: 0, follows: 0, comments: 0);
    notifyListeners();
  }

  /// 启动轮询（作为WebSocket不可用时的备选方案）
  void startPolling() {
    _stopPolling(); // 先停止现有的轮询
    _pollingTimer = Timer.periodic(_pollingInterval, (_) {
      _pollUnreadCounts();
    });
    // 立即执行一次轮询
    _pollUnreadCounts();
  }

  /// 停止轮询
  void stopPolling() {
    _stopPolling();
  }

  /// 停止轮询（内部方法）
  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// 轮询未读数量
  Future<void> _pollUnreadCounts() async {
    try {
      final resp = await ApiService.getUnreadNotificationCount();
      if (resp['statusCode'] == 200) {
        final body = resp['body'] as Map<String, dynamic>;
        final count = UnreadCount.fromJson(body);
        updateNotificationUnread(count);
      }
    } catch (e) {
      // 忽略轮询错误
    }
  }
}

