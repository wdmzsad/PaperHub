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

  // 分页状态
  int _currentPage = 0;
  int get currentPage => _currentPage;
  int _totalPages = 0;
  int get totalPages => _totalPages;
  bool _hasMoreMessages = false;
  bool get hasMoreMessages => _hasMoreMessages;
  bool _isLoadingMoreMessages = false;
  bool get isLoadingMoreMessages => _isLoadingMoreMessages;

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
  Future<void> loadMessages(String conversationId, {bool silent = false, int page = 0}) async {
    if (page == 0) {
      // 首次加载或刷新
      if (!silent) {
        _isLoadingMessages = true;
        notifyListeners();
      }
    } else {
      // 加载更多
      if (!silent) {
        _isLoadingMoreMessages = true;
        notifyListeners();
      }
    }

    try {
      final result = await ApiService.getConversationMessages(conversationId, page: page);

      if (result['statusCode'] == 200) {
        final Map<String, dynamic> data = result['body'];
        final List<dynamic> content = data['content'] ?? [];

        // 转换消息
        final newMessages = content.map((json) => Message.fromJson(json)).toList();

        // 检查是否为轮询刷新（silent模式且page=0）
        final isPollingRefresh = silent && page == 0;

        if (!isPollingRefresh) {
          // 非轮询刷新时更新分页信息
          _currentPage = data['number'] ?? 0; // Spring Data JPA Page的当前页码
          _totalPages = data['totalPages'] ?? 1;
          _hasMoreMessages = _currentPage < _totalPages - 1;
        }

        if (page == 0) {
          if (isPollingRefresh) {
            // 轮询刷新：合并新消息到列表末尾
            final reversedNewMessages = newMessages.reversed.toList();
            final existingMessageIds = Set<String>.from(_messages.map((msg) => msg.id));

            // 智能去重逻辑：区分本地临时消息替换和用户有意重复发送
            final uniqueNewMessages = reversedNewMessages.where((newMsg) {
              // 如果ID已存在，肯定是重复
              if (existingMessageIds.contains(newMsg.id)) {
                return false;
              }

              // 检查是否有需要替换的本地临时消息
              bool shouldReplaceLocalMessage = false;
              int replaceIndex = -1;

              for (int i = 0; i < _messages.length; i++) {
                final existingMsg = _messages[i];

                // 检查发送者是否相同
                if (existingMsg.senderId != newMsg.senderId) {
                  continue;
                }

                // 检查内容是否相同
                if (existingMsg.content != newMsg.content) {
                  continue;
                }

                // 检查消息类型是否相同
                if (existingMsg.type != newMsg.type) {
                  continue;
                }

                // 如果是媒体消息，检查mediaUrls是否相同
                if (existingMsg.type == MessageType.image || existingMsg.type == MessageType.video || existingMsg.type == MessageType.file) {
                  if (existingMsg.mediaUrls.length != newMsg.mediaUrls.length) {
                    continue;
                  }
                  bool mediaUrlsMatch = true;
                  for (int j = 0; j < existingMsg.mediaUrls.length; j++) {
                    if (existingMsg.mediaUrls[j] != newMsg.mediaUrls[j]) {
                      mediaUrlsMatch = false;
                      break;
                    }
                  }
                  if (!mediaUrlsMatch) {
                    continue;
                  }
                }

                // 检查时间是否非常接近（2秒内）且现有消息是发送中状态
                // 这是区分本地临时消息的关键逻辑
                final timeDiff = existingMsg.createdAt.difference(newMsg.createdAt).abs();
                if (timeDiff <= Duration(seconds: 2) && existingMsg.status == MessageStatus.sending) {
                  // 这是本地临时消息需要被服务器消息替换
                  shouldReplaceLocalMessage = true;
                  replaceIndex = i;
                  break;
                }

                // 如果时间差较大（>2秒），视为用户有意重复发送，允许显示
                // 即使内容相同，时间间隔较大也认为是有效消息
              }

              if (shouldReplaceLocalMessage && replaceIndex != -1) {
                // 替换本地临时消息为服务器消息
                _messages[replaceIndex] = newMsg;
                // 这个服务器消息已经处理了，不添加到uniqueNewMessages列表
                return false;
              }

              // 如果没有需要替换的本地消息，这是一个新消息
              return true;
            }).toList();

            if (uniqueNewMessages.isNotEmpty) {
              _messages = [..._messages, ...uniqueNewMessages];
            }
          } else {
            // 首次加载或手动刷新，替换整个列表（反转时间顺序）
            _messages = newMessages.reversed.toList();
          }
        } else {
          // 加载更多，添加到列表开头（历史消息）
          // 注意：后端返回的是按时间倒序（最新的第一条），所以newMessages需要反转后添加到开头
          final reversedNewMessages = newMessages.reversed.toList();
          _messages = [...reversedNewMessages, ..._messages];
        }
      } else {
        debugPrint('加载消息失败: ${result['body']['message']}');
        if (!silent && page == 0) {
          _messages = [];
        }
      }
    } catch (e) {
      debugPrint('加载消息失败: $e');
      if (!silent && page == 0) {
        _messages = [];
      }
    } finally {
      if (!silent) {
        if (page == 0) {
          _isLoadingMessages = false;
        } else {
          _isLoadingMoreMessages = false;
        }
      }
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
  /// 对于 SHARE 类型，content 应该存储 post ID
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
      sharePost: null, // SHARE 类型不再需要 sharePost，前端会根据 post ID 获取详情
    );

    // 添加到消息列表末尾（因为列表现在是按时间升序排列，最早的在顶部）
    _messages.add(newMessage);
    notifyListeners();

    try {
      // 如果是分享消息，sharePost 信息已经编码在 content 中
      final result = await ApiService.sendMessage(
        conversationId,
        content,
        type: _convertMessageType(type),
      );

      if (result['statusCode'] == 200) {
        // 使用服务器返回的消息数据（包含正确的ID）
        final serverMessage = Message.fromJson(result['body']);

        // 查找匹配的本地消息（先尝试ID匹配，再尝试内容匹配）
        int foundIndex = _messages.indexWhere((m) => m.id == newMessage.id);

        if (foundIndex == -1) {
          // ID不匹配，尝试基于内容、发送者、时间和类型匹配
          // 这种情况可能发生在轮询已经提前替换了消息
          for (int i = 0; i < _messages.length; i++) {
            final existingMsg = _messages[i];

            // 检查发送者、内容、类型是否相同
            if (existingMsg.senderId == newMessage.senderId &&
                existingMsg.content == newMessage.content &&
                existingMsg.type == newMessage.type &&
                existingMsg.status == MessageStatus.sending) {

              // 检查时间是否接近（3秒内）
              final timeDiff = existingMsg.createdAt.difference(newMessage.createdAt).abs();
              if (timeDiff <= Duration(seconds: 3)) {

                // 如果是媒体消息，检查mediaUrls是否相同
                if (existingMsg.type == MessageType.image || existingMsg.type == MessageType.video || existingMsg.type == MessageType.file) {
                  if (existingMsg.mediaUrls.length != newMessage.mediaUrls.length) {
                    continue;
                  }
                  bool mediaUrlsMatch = true;
                  for (int j = 0; j < existingMsg.mediaUrls.length; j++) {
                    if (existingMsg.mediaUrls[j] != newMessage.mediaUrls[j]) {
                      mediaUrlsMatch = false;
                      break;
                    }
                  }
                  if (!mediaUrlsMatch) {
                    continue;
                  }
                }

                foundIndex = i;
                break;
              }
            }
          }
        }

        if (foundIndex != -1) {
          // 替换本地临时消息为服务器消息
          _messages[foundIndex] = serverMessage;
        } else {
          // 如果没找到匹配的本地消息，添加服务器消息
          _messages.add(serverMessage);
        }
        notifyListeners();

        // 更新会话的最后消息
        _updateLastMessage(conversationId, serverMessage);
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
    String? fileName,
    int? fileSize,
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
        fileName: fileName,
        fileSize: fileSize,
      );

      if (result['statusCode'] == 200) {
        // 使用服务器返回的消息数据（包含正确的ID）
        final serverMessage = Message.fromJson(result['body']);

        // 查找匹配的本地消息（先尝试ID匹配，再尝试内容匹配）
        int foundIndex = _messages.indexWhere((m) => m.id == newMessage.id);

        if (foundIndex == -1) {
          // ID不匹配，尝试基于内容、发送者、时间和类型匹配
          // 这种情况可能发生在轮询已经提前替换了消息
          for (int i = 0; i < _messages.length; i++) {
            final existingMsg = _messages[i];

            // 检查发送者、内容、类型是否相同
            if (existingMsg.senderId == newMessage.senderId &&
                existingMsg.content == newMessage.content &&
                existingMsg.type == newMessage.type &&
                existingMsg.status == MessageStatus.sending) {

              // 检查时间是否接近（3秒内）
              final timeDiff = existingMsg.createdAt.difference(newMessage.createdAt).abs();
              if (timeDiff <= Duration(seconds: 3)) {

                // 对于媒体消息，必须检查mediaUrls是否相同
                if (existingMsg.type == MessageType.image || existingMsg.type == MessageType.video || existingMsg.type == MessageType.file) {
                  if (existingMsg.mediaUrls.length != newMessage.mediaUrls.length) {
                    continue;
                  }
                  bool mediaUrlsMatch = true;
                  for (int j = 0; j < existingMsg.mediaUrls.length; j++) {
                    if (existingMsg.mediaUrls[j] != newMessage.mediaUrls[j]) {
                      mediaUrlsMatch = false;
                      break;
                    }
                  }
                  if (!mediaUrlsMatch) {
                    continue;
                  }
                }

                foundIndex = i;
                break;
              }
            }
          }
        }

        if (foundIndex != -1) {
          // 替换本地临时消息为服务器消息
          _messages[foundIndex] = serverMessage;
        } else {
          // 如果没找到匹配的本地消息，添加服务器消息
          _messages.add(serverMessage);
        }
        notifyListeners();

        // 更新会话的最后消息
        _updateLastMessage(conversationId, serverMessage);
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
      case MessageType.video:
        return 'VIDEO';
      case MessageType.share:
        return 'SHARE';
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