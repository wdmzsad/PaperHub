/// 会话列表项组件
///
/// 显示单个会话的信息：
/// - 头像和名称
/// - 最后消息内容
/// - 时间和未读计数
/// - 在线状态指示器
import 'package:flutter/material.dart';
import '../models/conversation_model.dart';

enum MessageStatus {
  sending,
  failed,
  sent,
  delivered,
  read,
}

class ConversationItem extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;

  const ConversationItem({
    Key? key,
    required this.conversation,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 4),
                    _buildLastMessage(),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildMetaInfo(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Stack(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey[200],
          ),
          child: conversation.displayAvatar != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    conversation.displayAvatar!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildDefaultAvatar();
                    },
                  ),
                )
              : _buildDefaultAvatar(),
        ),
        if (conversation.isOnline && conversation.type == ConversationType.private)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50),
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDefaultAvatar() {
    final name = conversation.displayName;
    final firstChar = name.isNotEmpty ? name[0] : '?';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
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
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            conversation.displayName,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (conversation.type == ConversationType.group)
          Container(
            margin: const EdgeInsets.only(left: 6),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF1976D2).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${conversation.participants.length}',
              style: TextStyle(
                color: const Color(0xFF1976D2),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLastMessage() {
    if (conversation.lastMessage == null) {
      return Text(
        '暂无消息',
        style: TextStyle(
          color: Colors.grey[500],
          fontSize: 14,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final message = conversation.lastMessage!;
    String content = message.content;

    // 根据消息类型显示不同的内容
    final typeString = message.type.toString();
    switch (typeString) {
      case 'MessageType.image':
        content = '[图片]';
        break;
      case 'MessageType.file':
        content = '[文件]';
        break;
      case 'MessageType.voice':
        content = '[语音]';
        break;
      case 'MessageType.system':
        content = '[系统消息]';
        break;
      default:
        break;
    }

    return Row(
      children: [
        if (message.isMe && message.status == MessageStatus.sending) ...[
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
            ),
          ),
          const SizedBox(width: 4),
        ] else if (message.isMe && message.status == MessageStatus.failed) ...[
          Icon(
            Icons.error_outline,
            size: 12,
            color: Colors.red[400],
          ),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Text(
            content,
            style: TextStyle(
              color: conversation.unreadCount > 0 ? Colors.black87 : Colors.grey[600],
              fontSize: 14,
              fontWeight: conversation.unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildMetaInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          _formatTime(conversation.updatedAt),
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        if (conversation.unreadCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF1976D2),
              borderRadius: BorderRadius.circular(10),
            ),
            constraints: const BoxConstraints(
              minWidth: 18,
              minHeight: 18,
            ),
            child: Text(
              conversation.unreadCount > 99 ? '99+' : '${conversation.unreadCount}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          )
        else if (conversation.isTyping)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '正在输入...',
              style: TextStyle(
                color: const Color(0xFF4CAF50),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      // 今天
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return '刚刚';
        }
        return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      }
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      // 昨天
      return '昨天';
    } else if (difference.inDays < 7) {
      // 一周内
      final weekdays = ['一', '二', '三', '四', '五', '六', '日'];
      return '周${weekdays[dateTime.weekday - 1]}';
    } else {
      // 更早
      return '${dateTime.month}/${dateTime.day}';
    }
  }
}