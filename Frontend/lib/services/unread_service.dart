import 'package:flutter/foundation.dart';

import '../models/notification_model.dart';

/// 全局未读状态，负责聚合聊天与通知的 badge。
class UnreadService extends ChangeNotifier {
  UnreadService._();

  static final UnreadService instance = UnreadService._();

  int _chatUnread = 0;
  UnreadCount _notificationCount =
      UnreadCount(likes: 0, follows: 0, comments: 0);

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
}

