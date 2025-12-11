import 'dart:async';
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

  // 应用状态管理
  bool _isAppInForeground = true;
  StreamSubscription? _appLifecycleSubscription;

  // 重连管理
  Timer? _reconnectTimer;
  static const Duration _reconnectInterval = Duration(seconds: 5);
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;

  // 心跳保活
  Timer? _heartbeatTimer;
  static const Duration _heartbeatInterval = Duration(seconds: 30);

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
      _reconnectAttempts = 0; // 重置重连次数
      print('通知WebSocket连接成功');

      // 启动应用状态监听
      _startAppLifecycleListener();

      // 启动心跳保活
      _startHeartbeat();

      // 停止轮询（如果正在运行）
      _stopPolling();

    } catch (e) {
      print('通知WebSocket连接失败: $e');
      _isConnected = false;

      // 启动重连机制
      _scheduleReconnect();
    }
  }

  /// 断开WebSocket连接
  void disconnect() {
    // 清理所有资源
    _cleanupResources();

    _isConnected = false;
    _currentUserId = null;
    print('通知WebSocket已断开');
  }

  /// 清理所有资源
  void _cleanupResources() {
    // 关闭WebSocket连接
    if (_channel != null) {
      _channel!.sink.close();
      _channel = null;
    }

    // 停止应用状态监听
    _stopAppLifecycleListener();

    // 停止心跳保活
    _stopHeartbeat();

    // 停止重连定时器
    _stopReconnectTimer();

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

  /// 启动应用状态监听
  void _startAppLifecycleListener() {
    _stopAppLifecycleListener(); // 先停止现有的监听

    try {
      // 在Flutter中，应用生命周期监听通过WidgetsBindingObserver实现
      // 这里我们使用一个简化的方法：使用定时器检查应用是否在前台
      // 在实际应用中，你可能需要实现WidgetsBindingObserver接口
      print('启动应用状态监听（简化版）');

      // 由于WebSocket连接本身已经处理了重连，这里我们不需要复杂的生命周期监听
      // 只需要标记应用在前台即可
      _isAppInForeground = true;

    } catch (e) {
      print('启动应用状态监听失败: $e');
    }
  }

  /// 停止应用状态监听
  void _stopAppLifecycleListener() {
    _appLifecycleSubscription?.cancel();
    _appLifecycleSubscription = null;
    _isAppInForeground = false;
  }

  /// 应用回到前台时的处理
  void _onAppResumed() {
    print('应用回到前台，检查WebSocket连接');

    if (!_isConnected) {
      // 如果WebSocket断开，尝试重连
      _scheduleReconnect();
    } else {
      // 如果已连接，刷新未读数量
      _refreshUnreadCounts();
    }
  }

  /// 应用进入后台时的处理
  void _onAppPaused() {
    print('应用进入后台');
    // 可以在这里选择是否断开WebSocket以节省资源
    // 目前保持连接，让心跳保活维持连接
  }

  /// 调度重连
  void _scheduleReconnect() {
    _stopReconnectTimer(); // 先停止现有的重连定时器

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print('已达到最大重连次数 ($_maxReconnectAttempts)，启动轮询作为备选方案');
      _startPollingAsFallback();
      return;
    }

    _reconnectAttempts++;
    print('调度重连，尝试次数: $_reconnectAttempts/$_maxReconnectAttempts');

    _reconnectTimer = Timer(_reconnectInterval, () {
      print('执行重连...');
      connect();
    });
  }

  /// 停止重连定时器
  void _stopReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// 启动心跳保活
  void _startHeartbeat() {
    _stopHeartbeat(); // 先停止现有的心跳

    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (timer) {
      if (_isConnected && _channel != null && _channel!.sink != null) {
        try {
          // 发送心跳消息（简单的ping）
          final heartbeat = jsonEncode({'type': 'ping', 'timestamp': DateTime.now().millisecondsSinceEpoch});
          _channel!.sink.add(heartbeat);
          print('发送心跳保活');
        } catch (e) {
          print('发送心跳失败: $e');
          // 心跳失败，可能连接已断开
          _isConnected = false;
          _scheduleReconnect();
        }
      }
    });
  }

  /// 停止心跳保活
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// 获取当前用户ID
  Future<int?> _getCurrentUserId() async {
    try {
      final token = LocalStorage.instance.read('accessToken');
      if (token == null || token.isEmpty) {
        print('未找到accessToken');
        return null;
      }

      // 从JWT token中解析用户ID
      final parts = token.split('.');
      if (parts.length != 3) {
        print('JWT token格式不正确，应有3部分，实际有${parts.length}部分');
        return null;
      }

      try {
        final payload = parts[1];
        final decoded = utf8.decode(base64Url.decode(payload + '=' * (4 - payload.length % 4)));
        final payloadMap = jsonDecode(decoded);

        print('JWT payload解析结果: $payloadMap');

        // 尝试不同的用户ID字段名
        final userId = payloadMap['userId'] ?? payloadMap['sub'] ?? payloadMap['id'];

        if (userId == null) {
          print('JWT payload中未找到用户ID字段');
          return null;
        }

        return int.tryParse(userId.toString());
      } catch (e) {
        print('解析JWT payload失败: $e');
        return null;
      }
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

    // 启动重连机制
    _scheduleReconnect();
  }

  /// 处理WebSocket关闭
  void _handleDone() {
    print('通知WebSocket连接关闭');
    _isConnected = false;

    // 启动重连机制
    _scheduleReconnect();
  }

  /// 检查是否已连接
  bool get isConnected => _isConnected;

  /// 获取当前用户ID
  int? get currentUserId => _currentUserId;

  /// 手动检查并重连（可以在任何页面调用）
  Future<void> checkAndReconnect() async {
    print('手动检查WebSocket连接状态');

    if (!_isConnected) {
      print('WebSocket未连接，尝试重连...');
      await connect();
    } else {
      print('WebSocket已连接，刷新未读数量...');
      await _refreshUnreadCounts();
    }
  }

  /// 刷新未读数量（公开方法）
  Future<void> refreshUnreadCounts() async {
    await _refreshUnreadCounts();
  }
}