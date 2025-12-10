import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart';

import '../config/app_env.dart';
import '../services/local_storage.dart';
import '../services/unread_service.dart';
import '../models/notification_model.dart';

/// 通知WebSocket服务
/// 用于接收实时通知推送
class NotificationWebSocketService {
  NotificationWebSocketService._();

  static final NotificationWebSocketService instance = NotificationWebSocketService._();

  WebSocketChannel? _channel;
  bool _isConnected = false;
  int? _currentUserId;

  /// 连接WebSocket
  Future<void> connect() async {
    if (_isConnected && _channel != null) {
      return;
    }

    try {
      // 获取当前用户ID
      final userId = await _getCurrentUserId();
      if (userId == null) {
        print('未登录，不连接通知WebSocket');
        return;
      }

      _currentUserId = userId;

      // 构建WebSocket URL
      final wsUrl = '${AppEnv.wsBaseUrl}/ws/notifications/$userId';
      print('连接通知WebSocket: $wsUrl');

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      // 监听消息
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDone,
      );

      _isConnected = true;
      print('通知WebSocket连接成功');

    } catch (e) {
      print('通知WebSocket连接失败: $e');
      _isConnected = false;

      // WebSocket连接失败，启动轮询作为备选方案
      _startPollingAsFallback();
    }
  }

  /// 断开WebSocket连接
  void disconnect() {
    if (_channel != null) {
      _channel!.sink.close();
      _channel = null;
    }
    _isConnected = false;
    _currentUserId = null;
    print('通知WebSocket已断开');

    // 停止轮询
    _stopPolling();
  }

  /// 启动轮询作为备选方案
  void _startPollingAsFallback() {
    print('启动轮询作为WebSocket备选方案');
    UnreadService.instance.startPolling();
  }

  /// 停止轮询
  void _stopPolling() {
    UnreadService.instance.stopPolling();
  }

  /// 获取当前用户ID
  Future<int?> _getCurrentUserId() async {
    try {
      final token = LocalStorage.instance.read('token');
      if (token == null || token.isEmpty) {
        return null;
      }

      // 从JWT token中解析用户ID
      final parts = token.split('.');
      if (parts.length != 3) {
        return null;
      }

      final payload = parts[1];
      final decoded = utf8.decode(base64Url.decode(payload + '=' * (4 - payload.length % 4)));
      final payloadMap = jsonDecode(decoded);

      return payloadMap['userId'] as int?;
    } catch (e) {
      print('解析用户ID失败: $e');
      return null;
    }
  }

  /// 处理WebSocket消息
  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message);
      final type = data['type'] as String?;

      if (type == null) return;

      switch (type) {
        case 'new_notification':
          _handleNewNotification(data);
          break;
        case 'unread_count_update':
          _handleUnreadCountUpdate(data);
          break;
        default:
          print('未知的WebSocket消息类型: $type');
      }
    } catch (e) {
      print('解析WebSocket消息失败: $e, message: $message');
    }
  }

  /// 处理新通知
  void _handleNewNotification(Map<String, dynamic> data) {
    final notificationType = data['notificationType'] as String?;
    final notificationData = data['data'] as Map<String, dynamic>?;

    if (notificationType == null || notificationData == null) {
      return;
    }

    print('收到新通知: $notificationType, data: $notificationData');

    // 这里可以触发UI更新，比如显示Toast通知
    // 暂时只更新未读数量
    _refreshUnreadCounts();
  }

  /// 处理未读数量更新
  void _handleUnreadCountUpdate(Map<String, dynamic> data) {
    final unreadCounts = data['unreadCounts'] as Map<String, dynamic>?;

    if (unreadCounts == null) {
      return;
    }

    try {
      final counts = UnreadCount(
        likes: (unreadCounts['likes'] as num?)?.toInt() ?? 0,
        follows: (unreadCounts['follows'] as num?)?.toInt() ?? 0,
        comments: (unreadCounts['comments'] as num?)?.toInt() ?? 0,
      );

      print('收到未读数量更新: $counts');

      // 更新全局未读状态
      UnreadService.instance.updateNotificationUnread(counts);
    } catch (e) {
      print('更新未读数量失败: $e');
    }
  }

  /// 刷新未读数量（通过API获取最新数据）
  Future<void> _refreshUnreadCounts() async {
    // 这里可以调用API获取最新的未读数量
    // 但WebSocket推送已经包含了未读数量，所以这里主要是为了确保数据一致性
    // 在实际应用中，可以定期调用API同步数据
  }

  /// 处理WebSocket错误
  void _handleError(dynamic error) {
    print('通知WebSocket错误: $error');
    _isConnected = false;

    // 尝试重新连接
    Future.delayed(const Duration(seconds: 5), () {
      if (!_isConnected) {
        connect();
      }
    });
  }

  /// 处理WebSocket关闭
  void _handleDone() {
    print('通知WebSocket连接关闭');
    _isConnected = false;

    // 尝试重新连接
    Future.delayed(const Duration(seconds: 5), () {
      if (!_isConnected) {
        connect();
      }
    });
  }

  /// 检查是否已连接
  bool get isConnected => _isConnected;

  /// 获取当前用户ID
  int? get currentUserId => _currentUserId;
}