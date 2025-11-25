import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';
import 'api_service.dart';
import 'unread_service.dart';

/// 聊天服务类
///
/// 负责处理所有聊天相关的业务逻辑：
/// - 会话管理
/// - 消息发送与接收
/// - WebSocket连接管理
class ChatService extends ChangeNotifier {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  // 会话列表
  List<Conversation> _conversations = [];
  List<Conversation> get conversations => _conversations;

  // 当前聊天会话
  Conversation? _currentConversation;
  Conversation? get currentConversation => _currentConversation;

  // 当前会话的消息列表
  List<Message> _messages = [];
  List<Message> get messages => _messages;

  // 加载状态
  bool _isLoadingConversations = false;
  bool get isLoadingConversations => _isLoadingConversations;

  bool _isLoadingMessages = false;
  bool get isLoadingMessages => _isLoadingMessages;

  // 连接状态
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  // 模拟数据
  void _initMockData() {
    _conversations = [
      Conversation(
        id: '1',
        name: '张同学',
        avatar: 'https://via.placeholder.com/50',
        type: ConversationType.private,
        lastMessage: Message(
          id: 'm1',
          conversationId: '1',
          senderId: 'user1',
          senderName: '张同学',
          senderAvatar: 'https://via.placeholder.com/50',
          content: '论文写得怎么样了？',
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
          isMe: false,
        ),
        unreadCount: 2,
        updatedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        participants: [
          ConversationParticipant(
            id: 'user1',
            name: '张同学',
            avatar: 'https://via.placeholder.com/50',
            isOnline: true,
          ),
        ],
        isOnline: true,
      ),
      Conversation(
        id: '2',
        name: '李同学',
        avatar: 'https://via.placeholder.com/50',
        type: ConversationType.private,
        lastMessage: Message(
          id: 'm2',
          conversationId: '2',
          senderId: 'me',
          senderName: '我',
          senderAvatar: 'https://via.placeholder.com/50',
          content: '好的，谢谢！',
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
          isMe: true,
        ),
        unreadCount: 0,
        updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
        participants: [
          ConversationParticipant(
            id: 'user2',
            name: '李同学',
            avatar: 'https://via.placeholder.com/50',
            isOnline: false,
            lastSeen: DateTime.now().subtract(const Duration(minutes: 30)),
          ),
        ],
        isOnline: false,
      ),
      Conversation(
        id: '3',
        name: '学习小组',
        avatar: 'https://via.placeholder.com/50',
        type: ConversationType.group,
        lastMessage: Message(
          id: 'm3',
          conversationId: '3',
          senderId: 'user3',
          senderName: '王同学',
          senderAvatar: 'https://via.placeholder.com/50',
          content: '明天几点讨论？',
          createdAt: DateTime.now().subtract(const Duration(hours: 3)),
          isMe: false,
        ),
        unreadCount: 5,
        updatedAt: DateTime.now().subtract(const Duration(hours: 3)),
        participants: [
          ConversationParticipant(id: 'me', name: '我', isMe: true),
          ConversationParticipant(
            id: 'user3',
            name: '王同学',
            avatar: 'https://via.placeholder.com/50',
            isOnline: true,
          ),
          ConversationParticipant(
            id: 'user4',
            name: '刘同学',
            avatar: 'https://via.placeholder.com/50',
            isOnline: false,
          ),
        ],
        isOnline: false,
      ),
    ];
    _syncUnreadBadges();
  }

  /// 获取会话列表
  Future<void> loadConversations() async {
    _isLoadingConversations = true;
    notifyListeners();

    try {
      final result = await ApiService.getConversations();

      if (result['statusCode'] == 200) {
        final List<dynamic> data = result['body'];
        _conversations = data.map((json) => Conversation.fromJson(json)).toList();

        _conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        _syncUnreadBadges();
      } else {
        debugPrint('加载会话列表失败: ${result['body']['message']}');
        // 失败时显示空列表
        _conversations = [];
        _syncUnreadBadges();
      }
    } catch (e) {
      debugPrint('加载会话列表失败: $e');
      // 异常时显示空列表
      _conversations = [];
      _syncUnreadBadges();
    } finally {
      _isLoadingConversations = false;
      notifyListeners();
    }
  }

  /// 获取指定会话的消息列表
  Future<void> loadMessages(String conversationId) async {
    _isLoadingMessages = true;
    notifyListeners();

    try {
      final result = await ApiService.getConversationMessages(conversationId);

      if (result['statusCode'] == 200) {
        final Map<String, dynamic> data = result['body'];
        final List<dynamic> content = data['content'] ?? [];
        // 后端返回的消息是按时间降序（最新的在前），需要反转以显示最早的在顶部
        _messages = content.map((json) => Message.fromJson(json)).toList().reversed.toList();
      } else {
        debugPrint('加载消息失败: ${result['body']['message']}');
        // 失败时显示空消息列表
        _messages = [];
      }
    } catch (e) {
      debugPrint('加载消息失败: $e');
      // 异常时显示空消息列表
      _messages = [];
    } finally {
      _isLoadingMessages = false;
      notifyListeners();
    }
  }

  /// 初始化模拟消息数据（降级方案）
  void _initMockMessages(String conversationId) {
    _messages = [
      Message(
        id: 'msg1',
        conversationId: conversationId,
        senderId: 'other',
        senderName: '张同学',
        senderAvatar: 'https://via.placeholder.com/50',
        content: '你好！最近在忙什么？',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        isMe: false,
      ),
      Message(
        id: 'msg2',
        conversationId: conversationId,
        senderId: 'me',
        senderName: '我',
        senderAvatar: 'https://via.placeholder.com/50',
        content: '在写论文，有点头疼',
        createdAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 50)),
        isMe: true,
      ),
      Message(
        id: 'msg3',
        conversationId: conversationId,
        senderId: 'other',
        senderName: '张同学',
        senderAvatar: 'https://via.placeholder.com/50',
        content: '论文写得怎么样了？',
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        isMe: false,
      ),
    ];
  }

  /// 发送消息
  Future<void> sendMessage({
    required String conversationId,
    required String content,
    MessageType type = MessageType.text,
  }) async {
    final newMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      conversationId: conversationId,
      senderId: 'me',
      senderName: '我',
      senderAvatar: 'https://via.placeholder.com/50',
      content: content,
      type: type,
      createdAt: DateTime.now(),
      status: MessageStatus.sending,
      isMe: true,
    );

    // 添加到消息列表末尾（因为列表现在是按时间升序排列，最早的在顶部）
    _messages.add(newMessage);
    notifyListeners();

    try {
      final result = await ApiService.sendMessage(
        conversationId,
        content,
        type: _convertMessageType(type),
      );

      if (result['statusCode'] == 200) {
        // 更新消息状态为已发送
        final updatedMessage = newMessage.copyWith(status: MessageStatus.sent);
        final index = _messages.indexWhere((m) => m.id == newMessage.id);
        if (index != -1) {
          _messages[index] = updatedMessage;
          notifyListeners();
        }

        // 更新会话的最后消息
        _updateLastMessage(conversationId, updatedMessage);
      } else {
        debugPrint('发送消息失败: ${result['body']['message']}');
        throw Exception(result['body']['message'] ?? '发送消息失败');
      }
    } catch (e) {
      debugPrint('发送消息失败: $e');

      // 更新消息状态为发送失败
      final failedMessage = newMessage.copyWith(status: MessageStatus.failed);
      final index = _messages.indexWhere((m) => m.id == newMessage.id);
      if (index != -1) {
        _messages[index] = failedMessage;
        notifyListeners();
      }
      rethrow;
    }
  }

  /// 发送带媒体的消息
  Future<void> sendMessageWithMedia({
    required String conversationId,
    required List<String> mediaUrls,
    String content = '',
    MessageType type = MessageType.image,
  }) async {
    final newMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      conversationId: conversationId,
      senderId: 'me',
      senderName: '我',
      senderAvatar: 'https://via.placeholder.com/50',
      content: content,
      type: type,
      mediaUrls: mediaUrls,
      createdAt: DateTime.now(),
      status: MessageStatus.sending,
      isMe: true,
    );

    // 添加到消息列表
    _messages.add(newMessage);
    notifyListeners();

    try {
      final result = await ApiService.sendMessageWithMedia(
        conversationId,
        mediaUrls,
        type: _convertMessageType(type),
        content: content,
      );

      if (result['statusCode'] == 200) {
        // 更新消息状态为已发送
        final updatedMessage = newMessage.copyWith(status: MessageStatus.sent);
        final index = _messages.indexWhere((m) => m.id == newMessage.id);
        if (index != -1) {
          _messages[index] = updatedMessage;
          notifyListeners();
        }

        // 更新会话的最后消息
        _updateLastMessage(conversationId, updatedMessage);
      } else {
        debugPrint('发送媒体消息失败: ${result['body']['message']}');
        throw Exception(result['body']['message'] ?? '发送消息失败');
      }
    } catch (e) {
      debugPrint('发送媒体消息失败: $e');

      // 更新消息状态为发送失败
      final failedMessage = newMessage.copyWith(status: MessageStatus.failed);
      final index = _messages.indexWhere((m) => m.id == newMessage.id);
      if (index != -1) {
        _messages[index] = failedMessage;
        notifyListeners();
      }
      rethrow;
    }
  }

  /// 转换前端消息类型为后端消息类型
  String _convertMessageType(MessageType type) {
    switch (type) {
      case MessageType.text:
        return 'TEXT';
      case MessageType.voice:
        return 'VOICE';
      case MessageType.image:
        return 'IMAGE';
      case MessageType.file:
        return 'FILE';
      default:
        return 'TEXT';
    }
  }

  /// 设置当前会话
  void setCurrentConversation(Conversation conversation) {
    _currentConversation = conversation;
    loadMessages(conversation.id);
  }

  /// 将后端返回的ConversationResponse转换为前端的Conversation模型
  Conversation _convertConversationResponseToConversation(Map<String, dynamic> responseBody) {
    return Conversation(
      id: responseBody['id']?.toString() ?? '', // 将数字ID转换为字符串
      name: responseBody['displayName'] ?? '', // 使用displayName作为name
      avatar: responseBody['displayAvatar'], // 使用displayAvatar作为avatar
      type: ConversationType.private, // 私聊会话固定为private类型
      lastMessage: null, // 新会话没有最后一条消息
      unreadCount: responseBody['unreadCount'] ?? 0,
      updatedAt: DateTime.parse(responseBody['updatedAt'] ?? DateTime.now().toIso8601String()),
      participants: [], // 新会话暂时没有参与者信息
      isOnline: responseBody['isOnline'] ?? false,
      isTyping: false,
    );
  }

  /// 创建或获取私聊会话
  Future<Conversation?> createOrGetPrivateConversation(String targetUserId) async {
    try {
      final result = await ApiService.createOrGetConversation(targetUserId);

      if (result['statusCode'] == 200) {
        // 将后端返回的ConversationResponse转换为前端的Conversation模型
        final responseBody = result['body'];
        final conversation = _convertConversationResponseToConversation(responseBody);

        // 添加到会话列表
        final existingIndex = _conversations.indexWhere((c) => c.id == conversation.id);
        if (existingIndex == -1) {
          _conversations.add(conversation);
        } else {
          _conversations[existingIndex] = conversation;
        }

        // 重新排序
        _conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

        // 自动设置为当前会话
        setCurrentConversation(conversation);

        notifyListeners();

        return conversation;
      } else {
        debugPrint('创建会话失败: ${result['body']['message']}');
        return null;
      }
    } catch (e) {
      debugPrint('创建会话失败: $e');
      return null;
    }
  }

  /// 更新会话的最后消息
  void _updateLastMessage(String conversationId, Message message) {
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      _conversations[index] = _conversations[index].copyWith(
        lastMessage: message,
        updatedAt: message.createdAt,
      );
      // 重新排序
      _conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      notifyListeners();
      _syncUnreadBadges();
    }
  }

  /// 标记消息为已读
  Future<void> markAsRead(String conversationId) async {
    try {
      final result = await ApiService.markConversationAsRead(conversationId);

      if (result['statusCode'] == 200) {
        final index = _conversations.indexWhere((c) => c.id == conversationId);
        if (index != -1 && _conversations[index].unreadCount > 0) {
          _conversations[index] = _conversations[index].copyWith(unreadCount: 0);
          notifyListeners();
          _syncUnreadBadges();
        }
      } else {
        debugPrint('标记已读失败: ${result['body']['message']}');
      }
    } catch (e) {
      debugPrint('标记已读失败: $e');
    }
  }

  void _syncUnreadBadges() {
    final total =
        _conversations.fold<int>(0, (sum, c) => sum + c.unreadCount);
    UnreadService.instance.updateChatUnread(total);
  }

  /// 搜索会话
  List<Conversation> searchConversations(String query) {
    if (query.isEmpty) return _conversations;

    return _conversations.where((conversation) {
      return conversation.displayName.toLowerCase().contains(query.toLowerCase()) ||
          (conversation.lastMessage?.content.toLowerCase().contains(query.toLowerCase()) ?? false);
    }).toList();
  }

  /// 删除会话
  Future<void> deleteConversation(String conversationId) async {
    try {
      // TODO: 替换为实际的API调用
      await Future.delayed(const Duration(milliseconds: 500));

      _conversations.removeWhere((c) => c.id == conversationId);
      if (_currentConversation?.id == conversationId) {
        _currentConversation = null;
        _messages.clear();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('删除会话失败: $e');
    }
  }
}