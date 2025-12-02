/// 消息气泡组件
///
/// 显示单条消息：
/// - 区分发送和接收的消息样式
/// - 显示消息内容和状态
/// - 支持不同消息类型
/// - 头像和时间显示
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../models/message_model.dart';
import 'video_message_player.dart';
import 'dart:html' as html if (dart.library.io) 'dart:io';

class MessageBubble extends StatefulWidget {
  final Message message;
  final bool showAvatar;
  final bool showTime;
  final VoidCallback? onAvatarTap;

  const MessageBubble({
    Key? key,
    required this.message,
    this.showAvatar = true,
    this.showTime = true,
    this.onAvatarTap,
  }) : super(key: key);

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  VideoPlayerController? _videoController;

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: widget.message.isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.message.isMe && widget.showAvatar) ...[
            _buildAvatar(),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: widget.message.isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                _buildMessageContent(context),
                if (widget.showTime) ...[
                  const SizedBox(height: 4),
                  _buildMessageMeta(),
                ],
              ],
            ),
          ),
          if (widget.message.isMe && widget.showAvatar) ...[
            const SizedBox(width: 8),
            _buildAvatar(),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return GestureDetector(
      onTap: widget.onAvatarTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[200],
        ),
        child: widget.message.senderAvatar != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  widget.message.senderAvatar!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildDefaultAvatar();
                  },
                ),
              )
            : _buildDefaultAvatar(),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    final name = widget.message.senderName;
    final firstChar = name.isNotEmpty ? name[0] : '?';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.message.isMe
              ? [const Color(0xFF1976D2), const Color(0xFF42A5F5)]
              : [Colors.grey[400]!, Colors.grey[600]!],
        ),
      ),
      child: Center(
        child: Text(
          firstChar,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    Widget content;

    switch (widget.message.type) {
      case MessageType.text:
        content = _buildTextMessage(context);
        break;
      case MessageType.image:
        content = _buildImageMessage(context);
        break;
      case MessageType.video:
        content = _buildVideoMessage(context);
        break;
      case MessageType.file:
        content = _buildFileMessage(context);
        break;
      case MessageType.voice:
        content = _buildVoiceMessage(context);
        break;
      case MessageType.system:
        content = _buildSystemMessage();
        break;
      default:
        content = _buildTextMessage(context);
    }

    return content;
  }

  Widget _buildVideoMessage(BuildContext context) {
    final videoUrl = widget.message.fileUrl ?? widget.message.mediaUrls.firstOrNull ?? '';
    if (videoUrl.isEmpty) {
      return _buildTextMessage(context);
    }

    return VideoMessagePlayer(
      videoUrl: videoUrl,
      isMe: widget.message.isMe,
    );
  }

  Widget _buildTextMessage(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: widget.message.isMe ? const Color(0xFF1976D2) : Colors.white,
        borderRadius: BorderRadius.circular(18).copyWith(
          bottomLeft: widget.message.isMe
              ? const Radius.circular(18)
              : const Radius.circular(4),
          bottomRight: widget.message.isMe
              ? const Radius.circular(4)
              : const Radius.circular(18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        widget.message.content,
        style: TextStyle(
          color: widget.message.isMe ? Colors.white : Colors.black87,
          fontSize: 16,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildImageMessage(BuildContext context) {
    if (widget.message.mediaUrls.isEmpty) {
      return _buildTextMessage(context);
    }

    return Column(
      crossAxisAlignment: widget.message.isMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        ...widget.message.mediaUrls.map(
          (url) => GestureDetector(
            onTap: () => _showImagePreview(context, url),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.6,
                maxHeight: 300,
              ),
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[100],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 200,
                      color: Colors.grey[200],
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      color: Colors.grey[200],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                          const SizedBox(height: 8),
                          Text(
                            '图片加载失败',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        if (widget.message.content.isNotEmpty)
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.6,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: widget.message.isMe ? const Color(0xFF1976D2) : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.message.content,
              style: TextStyle(
                color: widget.message.isMe ? Colors.white : Colors.black87,
                fontSize: 14,
              ),
            ),
          ),
      ],
    );
  }

  void _showImagePreview(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileMessage(BuildContext context) {
    final fileUrl = widget.message.fileUrl ?? (widget.message.mediaUrls.isNotEmpty ? widget.message.mediaUrls.first : null);
    if (fileUrl == null) return _buildTextMessage(context);

    final fileName = widget.message.fileName ?? _getFileName(fileUrl);
    final fileSize = widget.message.fileSize;

    return GestureDetector(
      onTap: () => _openFile(fileUrl),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.message.isMe ? const Color(0xFF1976D2) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getFileIconFromName(fileName),
              color: widget.message.isMe ? Colors.white : const Color(0xFF1976D2),
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: TextStyle(
                      color: widget.message.isMe ? Colors.white : Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fileSize != null ? _formatFileSize(fileSize) : _getFileExtension(fileName).toUpperCase(),
                    style: TextStyle(
                      color: widget.message.isMe ? Colors.white70 : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.download,
              color: widget.message.isMe ? Colors.white70 : Colors.grey[400],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon(String url) {
    String ext = _getFileExtension(url).toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
      case 'csv':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.folder_zip;
      case 'txt':
        return Icons.text_snippet;
      case 'exe':
        return Icons.settings_applications;
      case 'mp4':
        return Icons.video_library;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _getFileName(String url) {
    return url.split('/').last.split('?').first;
  }

  String _getFileExtension(String url) {
    String fileName = _getFileName(url);
    if (fileName.contains('.')) {
      return fileName.split('.').last;
    }
    return 'file';
  }

  void _showFilePreview(BuildContext context, String fileUrl) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_getFileName(fileUrl)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_getFileIcon(fileUrl), size: 64, color: const Color(0xFF1976D2)),
            const SizedBox(height: 16),
            Text('文件类型: ${_getFileExtension(fileUrl).toUpperCase()}'),
            const SizedBox(height: 8),
            Text(
              '点击下载按钮保存文件',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              // TODO: 实现文件下载
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('文件下载功能开发中')),
              );
            },
            icon: const Icon(Icons.download),
            label: const Text('下载'),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceMessage(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: widget.message.isMe ? const Color(0xFF1976D2) : Colors.white,
        borderRadius: BorderRadius.circular(18).copyWith(
          bottomLeft: widget.message.isMe
              ? const Radius.circular(18)
              : const Radius.circular(4),
          bottomRight: widget.message.isMe
              ? const Radius.circular(4)
              : const Radius.circular(18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.mic,
            color: widget.message.isMe ? Colors.white : Colors.grey[600],
            size: 18,
          ),
          const SizedBox(width: 8),
          Container(
            width: 80,
            height: 20,
            // 语音波形占位符：使用单个 Row 渲染波形条，避免不必要的嵌套 Stack
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                5,
                (index) => Container(
                  width: 2,
                  height: 12 + (index % 3) * 4,
                  decoration: BoxDecoration(
                    color: widget.message.isMe ? Colors.white : Colors.grey[400],
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            "0:${(widget.message.content.length % 60).toString().padLeft(2, '0')}",
            style: TextStyle(
              color: widget.message.isMe ? Colors.white70 : Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemMessage() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          widget.message.content,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildMessageMeta() {
    return Row(
      mainAxisAlignment: widget.message.isMe
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [
        if (!widget.message.isMe) ...[
          Text(
            _formatTime(widget.message.createdAt),
            style: TextStyle(color: Colors.grey[500], fontSize: 11),
          ),
          const SizedBox(width: 4),
          Text(
            widget.message.senderName,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ] else ...[
          _buildMessageStatus(),
          const SizedBox(width: 4),
          Text(
            _formatTime(widget.message.createdAt),
            style: TextStyle(color: Colors.grey[500], fontSize: 11),
          ),
        ],
      ],
    );
  }

  Widget _buildMessageStatus() {
    IconData icon;
    Color color;

    switch (widget.message.status) {
      case MessageStatus.sending:
        icon = Icons.access_time;
        color = Colors.grey[400]!;
        break;
      case MessageStatus.sent:
        icon = Icons.check;
        color = Colors.grey[400]!;
        break;
      case MessageStatus.delivered:
        icon = Icons.done_all;
        color = Colors.grey[400]!;
        break;
      case MessageStatus.read:
        icon = Icons.done_all;
        color = const Color(0xFF1976D2);
        break;
      case MessageStatus.failed:
        icon = Icons.error_outline;
        color = Colors.red[400]!;
        break;
      default:
        icon = Icons.check;
        color = Colors.grey[400]!;
    }

    return Icon(icon, size: 14, color: color);
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return '昨天 ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.month}/${dateTime.day}';
    }
  }

  IconData _getFileIconFromName(String fileName) {
    String ext = _getFileExtension(fileName).toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
      case 'csv':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.folder_zip;
      case 'txt':
        return Icons.text_snippet;
      case 'exe':
        return Icons.settings_applications;
      case 'mp4':
        return Icons.video_library;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  Future<void> _openFile(String url) async {
    final fileName = widget.message.fileName ?? _getFileName(url);
    final uri = Uri.parse(url);

    // Web平台：使用download属性
    try {
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
    } catch (e) {
      // 非Web平台：直接打开URL
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }
}
