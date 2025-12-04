/// PaperHub 聊天界面
///
/// 功能：
/// - 显示聊天消息列表
/// - 发送文本消息
/// - 实时消息更新
/// - 消息状态指示
/// - 时间分组显示
///
/// 设计风格：
/// - 遵循PaperHub设计语言
/// - 清晰的消息气泡区分
/// - 流畅的动画效果
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';
import '../services/chat_service.dart';
import '../services/api_service.dart';
import '../services/local_storage.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input.dart';
import 'profile_screen.dart';

class ChatScreen extends StatefulWidget {
  final Conversation? conversation;
  final String? conversationId;

  const ChatScreen({
    Key? key,
    this.conversation,
    this.conversationId,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();

  bool _isTyping = false;
  String _typingUser = '';
  bool _loadingConversation = false;
  Conversation? _loadedConversation;
  bool _initialLoadComplete = false;
  int _previousMessageCount = 0;
  String? _currentUserId;

  // 轮询配置
  Timer? _pollingTimer;
  static const Duration _pollingInterval = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _currentUserId = LocalStorage.instance.read('userId');
    _initializeConversation();
    _scrollController.addListener(_scrollListener);
    _chatService.addListener(_onChatServiceChanged);
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _chatService.removeListener(_onChatServiceChanged);
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _onChatServiceChanged() {
    if (mounted && !_chatService.isLoadingMessages) {
      final currentCount = _chatService.messages.length;
      final shouldScroll = currentCount > _previousMessageCount && _isNearBottom();

      setState(() {});

      if (shouldScroll) {
        _scrollToBottom();
      }
      _previousMessageCount = currentCount;
    }
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    return position.maxScrollExtent - position.pixels < 100;
  }

  void _initializeConversation() async {
    if (widget.conversation != null) {
      _chatService.setCurrentConversation(widget.conversation!);
      await _chatService.loadMessages(widget.conversation!.id, page: 0);
      setState(() {
        _initialLoadComplete = true;
        _previousMessageCount = _chatService.messages.length;
      });
      _scrollToBottom();
      _startPolling();
      return;
    }

    if (widget.conversationId != null) {
      setState(() {
        _loadingConversation = true;
      });

      try {
        final result = await ApiService.getConversations();
        if (result['statusCode'] == 200) {
          final List<dynamic> data = result['body'];
          final conversations = data.map((json) => Conversation.fromJson(json)).toList();

          final conversation = conversations.firstWhere(
            (c) => c.id == widget.conversationId,
            orElse: () => Conversation(
              id: widget.conversationId!,
              name: 'Unknown User',
              type: ConversationType.private,
              participants: [],
              updatedAt: DateTime.now(),
            ),
          );

          setState(() {
            _loadedConversation = conversation;
            _loadingConversation = false;
          });

          _chatService.setCurrentConversation(conversation);
          await _chatService.loadMessages(conversation.id, page: 0);
          setState(() {
            _initialLoadComplete = true;
            _previousMessageCount = _chatService.messages.length;
          });
          _scrollToBottom();
          _startPolling();
        } else {
          final fallbackConversation = Conversation(
            id: widget.conversationId!,
            name: 'Unknown User',
            type: ConversationType.private,
            participants: [],
            updatedAt: DateTime.now(),
          );

          setState(() {
            _loadedConversation = fallbackConversation;
            _loadingConversation = false;
          });

          _chatService.setCurrentConversation(fallbackConversation);
          await _chatService.loadMessages(fallbackConversation.id, page: 0);
          setState(() {
            _initialLoadComplete = true;
            _previousMessageCount = _chatService.messages.length;
          });
          _scrollToBottom();
          _startPolling();
        }
      } catch (e) {
        final fallbackConversation = Conversation(
          id: widget.conversationId!,
          name: 'Unknown User',
          type: ConversationType.private,
          participants: [],
          updatedAt: DateTime.now(),
        );

        setState(() {
          _loadedConversation = fallbackConversation;
          _loadingConversation = false;
        });

        _chatService.setCurrentConversation(fallbackConversation);
        await _chatService.loadMessages(fallbackConversation.id, page: 0);
        setState(() {
          _initialLoadComplete = true;
          _previousMessageCount = _chatService.messages.length;
        });
        _scrollToBottom();
        _startPolling();
      }
    }
  }


  Future<void> _loadMoreMessagesIfNeeded() async {
    final conversation = widget.conversation ?? _loadedConversation;
    if (conversation == null) return;

    // 检查是否还有更多消息且当前没有正在加载
    if (_chatService.hasMoreMessages && !_chatService.isLoadingMoreMessages) {
      // 记录加载前距离底部的距离
      double distanceFromBottom = 0;
      if (_scrollController.hasClients) {
        final maxExtent = _scrollController.position.maxScrollExtent;
        final currentOffset = _scrollController.offset;
        distanceFromBottom = maxExtent - currentOffset;
      }

      final int beforeMessageCount = _chatService.messages.length;

      // 加载下一页
      await _chatService.loadMessages(conversation.id, page: _chatService.currentPage + 1);

      // 在下一帧调整滚动位置，保持距离底部的距离不变
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;

        final int afterMessageCount = _chatService.messages.length;
        final int loadedMessageCount = afterMessageCount - beforeMessageCount;

        if (loadedMessageCount > 0) {
          final newMaxExtent = _scrollController.position.maxScrollExtent;
          // 保持原来的距离底部的距离
          final double newOffset = newMaxExtent - distanceFromBottom;
          _scrollController.jumpTo(newOffset.clamp(0.0, newMaxExtent));
        }
      });
    }
  }

  void _scrollListener() {
    // 当用户滚动到底部时，标记消息为已读
    final conversation = widget.conversation ?? _loadedConversation;
    if (conversation != null && _scrollController.offset >= _scrollController.position.maxScrollExtent - 100) {
      _chatService.markAsRead(conversation.id);
    }

    // 当滚动到顶部时，加载更多历史消息
    if (_scrollController.hasClients && _scrollController.offset <= 100) {
      _loadMoreMessagesIfNeeded();
    }
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(_pollingInterval, (timer) {
      _refreshMessages();
    });
  }

  Future<void> _refreshMessages() async {
    final conversation = widget.conversation ?? _loadedConversation;
    if (conversation == null || !_initialLoadComplete) return;

    // 轮询刷新时只获取最新消息（第一页）
    await _chatService.loadMessages(conversation.id, silent: true, page: 0);
  }

  void _onSendMessage(String content) {
    if (content.trim().isEmpty) return;

    final conversation = widget.conversation ?? _loadedConversation;
    if (conversation == null) return;

    _chatService.sendMessage(
      conversationId: conversation.id,
      content: content.trim(),
    );

    _textController.clear();
    _previousMessageCount = _chatService.messages.length;
    _scrollToBottom();
  }

  void _onSendMedia(List<String> mediaUrls, String messageType, String fileName, int fileSize) {
    final conversation = widget.conversation ?? _loadedConversation;
    if (conversation == null) return;

    MessageType type = MessageType.image;
    if (messageType == 'FILE') {
      type = MessageType.file;
    } else if (messageType == 'IMAGE') {
      type = MessageType.image;
    } else if (messageType == 'VIDEO') {
      type = MessageType.video;
    }

    _chatService.sendMessageWithMedia(
      conversationId: conversation.id,
      mediaUrls: mediaUrls,
      type: type,
      fileName: fileName,
      fileSize: fileSize,
    );

    _previousMessageCount = _chatService.messages.length;
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (!mounted) return;

    // 等待下一帧确保列表渲染完成
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      final maxExtent = _scrollController.position.maxScrollExtent;
      if (maxExtent > 0) {
        _scrollController.jumpTo(maxExtent);
      }
    });
  }

  String _formatDateHeader(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    final difference = messageDate.difference(today).inDays;

    switch (difference) {
      case 0:
        return '今天';
      case -1:
        return '昨天';
      default:
        return '${dateTime.month}月${dateTime.day}日';
    }
  }

  void _navigateToUserProfile(String userId) {
    if (userId == _currentUserId) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfilePage()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProfilePage(userId: userId)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: _loadingConversation ? _buildLoadingView() : _buildMessageList(),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final conversation = widget.conversation ?? _loadedConversation;

    if (conversation == null) {
      return AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '加载中...',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black87),
        onPressed: () => Navigator.pop(context),
      ),
      title: GestureDetector(
        onTap: () {
          if (conversation.type == ConversationType.private && conversation.participants.isNotEmpty) {
            final otherUser = conversation.participants.firstWhere((p) => !p.isMe, orElse: () => conversation.participants.first);
            _navigateToUserProfile(otherUser.id);
          }
        },
        child: Row(
          children: [
            _buildAppBarAvatar(conversation),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conversation.displayName,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_isTyping)
                    Text(
                      '$_typingUser 正在输入...',
                      style: TextStyle(
                        color: const Color(0xFF1976D2),
                        fontSize: 12,
                      ),
                    )
                  else if (conversation.type == ConversationType.group)
                    Text(
                      '${conversation.participants.length} 位成员',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert, color: Colors.black87),
          onPressed: _showMoreOptions,
        ),
      ],
    );
  }

  Widget _buildAppBarAvatar(Conversation conversation) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        color: Colors.grey[200],
      ),
      child: conversation.displayAvatar != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Image.network(
                conversation.displayAvatar!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildDefaultAvatar(conversation);
                },
              ),
            )
          : _buildDefaultAvatar(conversation),
    );
  }

  Widget _buildDefaultAvatar(Conversation conversation) {
    final name = conversation.displayName;
    final firstChar = name.isNotEmpty ? name[0] : '?';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1976D2),
            const Color(0xFF42A5F5),
          ],
        ),
      ),
      child: Center(
        child: Text(
          firstChar,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    if (!_initialLoadComplete) {
      return _buildLoadingView();
    }

    final messages = _chatService.messages;
    if (messages.isEmpty) {
      return _buildEmptyView();
    }

    return Column(
      children: [
        // 加载更多指示器
        if (_chatService.isLoadingMoreMessages)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1976D2)),
                ),
              ),
            ),
          ),
        // 消息列表
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(vertical: 16),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index];
              final showDateHeader = index == 0 ||
                  !_isSameDay(messages[index - 1].createdAt, message.createdAt);

              return Column(
                children: [
                  if (showDateHeader) _buildDateHeader(message.createdAt),
                  MessageBubble(
                    message: message,
                    showAvatar: true,
                    onAvatarTap: () => _navigateToUserProfile(message.senderId),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDateHeader(DateTime date) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _formatDateHeader(date),
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1976D2)),
            strokeWidth: 2,
          ),
          SizedBox(height: 16),
          Text(
            '加载消息中...',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '暂无消息',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '开始对话吧',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 3,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ChatInput(
        controller: _textController,
        onSend: _onSendMessage,
        onSendMedia: _onSendMedia,
        hintText: '输入消息...',
      ),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('聊天信息'),
              onTap: () {
                Navigator.pop(context);
                _showChatInfo();
              },
            ),
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('搜索聊天记录'),
              onTap: () {
                Navigator.pop(context);
                // TODO: 实现搜索功能
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('清空聊天记录', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmClearChat();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showChatInfo() {
    final conversation = widget.conversation ?? _loadedConversation;
    if (conversation == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(conversation.displayName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('成员数: ${conversation.participants.length}'),
            const SizedBox(height: 8),
            Text('创建时间: ${_formatDateHeader(conversation.updatedAt)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _confirmClearChat() {
    final conversation = widget.conversation ?? _loadedConversation;
    if (conversation == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空聊天记录'),
        content: Text('确定要清空与 ${conversation.displayName} 的聊天记录吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: 实现清空聊天记录功能
            },
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}