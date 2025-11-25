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
import 'package:flutter/material.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';
import '../services/chat_service.dart';
import '../services/api_service.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input.dart';

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

  @override
  void initState() {
    super.initState();
    _initializeConversation();
    _scrollController.addListener(_scrollListener);
    // 监听ChatService的状态变化
    _chatService.addListener(_onChatServiceChanged);
  }

  @override
  void dispose() {
    _chatService.removeListener(_onChatServiceChanged);
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _onChatServiceChanged() {
    // 当ChatService状态变化时，强制重建UI
    if (mounted) {
      setState(() {});
    }
  }

  void _initializeConversation() async {
    // If conversation object is provided directly, use it
    if (widget.conversation != null) {
      _chatService.setCurrentConversation(widget.conversation!);
      return;
    }

    // If only conversationId is provided, load the conversation from API
    if (widget.conversationId != null) {
      setState(() {
        _loadingConversation = true;
      });

      try {
        // Load conversation details from API
        final result = await ApiService.getConversations();
        if (result['statusCode'] == 200) {
          final List<dynamic> data = result['body'];
          final conversations = data.map((json) => Conversation.fromJson(json)).toList();

          // Find the conversation with matching ID
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
        } else {
          // Fallback: create a basic conversation object
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
        }
      } catch (e) {
        // Fallback on error
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
      }
    }
  }


  void _scrollListener() {
    // 当用户滚动到底部时，标记消息为已读
    final conversation = widget.conversation ?? _loadedConversation;
    if (conversation != null && _scrollController.offset >= _scrollController.position.maxScrollExtent - 100) {
      _chatService.markAsRead(conversation.id);
    }
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
    _scrollToBottom();
  }

  void _onSendMedia(List<String> mediaUrls, String messageType) {
    final conversation = widget.conversation ?? _loadedConversation;
    if (conversation == null) return;

    MessageType type = MessageType.image;
    if (messageType == 'FILE') {
      type = MessageType.file;
    } else if (messageType == 'IMAGE') {
      type = MessageType.image;
    }

    _chatService.sendMessageWithMedia(
      conversationId: conversation.id,
      mediaUrls: mediaUrls,
      type: type,
    );

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
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
      title: Row(
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
                else if (conversation.type == ConversationType.private)
                  Text(
                    conversation.isOnline ? '在线' : '离线',
                    style: TextStyle(
                      color: conversation.isOnline
                          ? const Color(0xFF4CAF50)
                          : Colors.grey[500],
                      fontSize: 12,
                    ),
                  )
                else
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
    if (_chatService.isLoadingMessages) {
      return _buildLoadingView();
    }

    final messages = _chatService.messages;
    if (messages.isEmpty) {
      return _buildEmptyView();
    }

    return ListView.builder(
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
              showAvatar: index == messages.length - 1 ||
                  messages[index + 1].senderId != message.senderId,
            ),
          ],
        );
      },
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
            if (conversation.type == ConversationType.private)
              Text('状态: ${conversation.isOnline ? "在线" : "离线"}')
            else
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