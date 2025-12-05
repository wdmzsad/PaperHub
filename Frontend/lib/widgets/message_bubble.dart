/// 消息气泡组件
///
/// 显示单条消息：
/// - 区分发送和接收的消息样式
/// - 显示消息内容和状态
/// - 支持不同消息类型
/// - 头像和时间显示
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/message_model.dart';
import '../models/post_model.dart';
import '../screens/post_detail_screen.dart';
import '../services/api_service.dart';
import 'video_message_player.dart';
import 'dart:html' as html if (dart.library.io) 'dart:io';

class MessageBubble extends StatefulWidget {
  // 缓存帖子详情的 Future，避免反复加载
  static final Map<String, Future<Map<String, dynamic>>> postCache = {};

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
  AudioPlayer? _audioPlayer;
  bool _isPlayingAudio = false;
  Duration _audioDuration = Duration.zero;
  Duration _audioPosition = Duration.zero;

  @override
  void dispose() {
    _videoController?.dispose();
    _audioPlayer?.dispose();
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
      case MessageType.share:
        content = _buildShareMessage(context);
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
    final voiceUrl = widget.message.fileUrl ?? widget.message.mediaUrls.firstOrNull ?? '';
    if (voiceUrl.isEmpty) return _buildTextMessage(context);

    return GestureDetector(
      onTap: () => _toggleAudioPlayback(voiceUrl),
      child: Container(
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
              _isPlayingAudio ? Icons.pause : Icons.play_arrow,
              color: widget.message.isMe ? Colors.white : const Color(0xFF1976D2),
              size: 20,
            ),
            const SizedBox(width: 8),
            Container(
              width: 80,
              height: 20,
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
              _formatDuration(_isPlayingAudio ? _audioPosition : _audioDuration),
              style: TextStyle(
                color: widget.message.isMe ? Colors.white70 : Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleAudioPlayback(String audioUrl) async {
    print('[AudioPlayer] 切换播放状态，URL: $audioUrl');

    if (_audioPlayer == null) {
      print('[AudioPlayer] 初始化播放器');
      _audioPlayer = AudioPlayer();
      _audioPlayer!.onDurationChanged.listen((duration) {
        print('[AudioPlayer] 时长变化: ${duration.inSeconds}s');
        if (mounted) {
          setState(() {
            _audioDuration = duration;
          });
        }
      });
      _audioPlayer!.onPositionChanged.listen((position) {
        if (mounted) {
          setState(() {
            _audioPosition = position;
          });
        }
      });
      _audioPlayer!.onPlayerComplete.listen((_) {
        print('[AudioPlayer] 播放完成');
        if (mounted) {
          setState(() {
            _isPlayingAudio = false;
            _audioPosition = Duration.zero;
          });
        }
      });
    }

    try {
      if (_isPlayingAudio) {
        print('[AudioPlayer] 暂停播放');
        await _audioPlayer!.pause();
        setState(() {
          _isPlayingAudio = false;
        });
      } else {
        print('[AudioPlayer] 开始播放');
        await _audioPlayer!.play(UrlSource(audioUrl));
        setState(() {
          _isPlayingAudio = true;
        });
      }
    } catch (e) {
      print('[AudioPlayer] 播放错误: $e');
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
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

  Widget _buildShareMessage(BuildContext context) {
    // SHARE 类型的 content 存储的是 post ID
    final postId = widget.message.content;
    if (postId.isEmpty) {
      return _buildTextMessage(context);
    }

    // 使用缓存的 Future，避免反复加载
    if (!MessageBubble.postCache.containsKey(postId)) {
      MessageBubble.postCache[postId] = _loadPostDetails(postId);
    }

    // 使用 FutureBuilder 根据 post ID 获取帖子详情
    return FutureBuilder<Map<String, dynamic>>(
      future: MessageBubble.postCache[postId],
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!, width: 0.5),
            ),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!, width: 0.5),
            ),
            child: const Center(
              child: Text('加载帖子失败', style: TextStyle(color: Colors.grey)),
            ),
          );
        }

        final post = snapshot.data!;
        final title = post['title']?.toString() ?? '无标题';
        final content = post['content']?.toString() ?? '';
        final authorName = post['author']?['name']?.toString() ?? '未知用户';
        final authorAvatar = post['author']?['avatar']?.toString();
        final media = post['media'] as List<dynamic>?;
        final firstImage = media != null && media.isNotEmpty ? media[0].toString() : null;
        final likesCount = (post['likesCount'] as num?)?.toInt() ?? 0;
        final commentsCount = (post['commentsCount'] as num?)?.toInt() ?? 0;
        final imageAspectRatio = (post['imageAspectRatio'] as num?)?.toDouble();
        final imageNaturalWidth = (post['imageNaturalWidth'] as num?)?.toDouble();
        final imageNaturalHeight = (post['imageNaturalHeight'] as num?)?.toDouble();

        return GestureDetector(
          onTap: () async {
            // 获取帖子详情并导航
            try {
              final result = await ApiService.getPost(postId);
              if (result['statusCode'] == 200) {
                final postData = result['body'] as Map<String, dynamic>;
                final postObj = Post.fromJson(postData);
                if (context.mounted) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PostDetailScreen(post: postObj),
                    ),
                  );
                }
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('获取帖子详情失败: ${result['body']['message'] ?? '未知错误'}')),
                  );
                }
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('获取帖子详情失败: $e')),
                );
              }
            }
          },
          child: _SharePostCard(
            cardWidth: (MediaQuery.of(context).size.width * 0.75).clamp(200.0, 280.0),
            title: title,
            authorName: authorName,
            authorAvatar: authorAvatar,
            firstImage: firstImage,
            likesCount: likesCount,
            commentsCount: commentsCount,
            imageAspectRatio: imageAspectRatio,
            imageNaturalWidth: imageNaturalWidth,
            imageNaturalHeight: imageNaturalHeight,
          ),
        );
      },
    );
  }

  // 根据 post ID 获取帖子详情
  Future<Map<String, dynamic>> _loadPostDetails(String postId) async {
    try {
      final result = await ApiService.getPost(postId);
      if (result['statusCode'] == 200 && result['body'] != null) {
        final body = result['body'] as Map<String, dynamic>?;
        if (body != null && body.isNotEmpty) {
          return body;
        } else {
          // 如果响应体为空，抛出异常
          throw Exception('服务器返回空响应体');
        }
      } else {
        throw Exception(result['body']?['message'] ?? '获取帖子失败');
      }
    } catch (e) {
      // 如果加载失败，从缓存中移除，以便下次重试
      MessageBubble.postCache.remove(postId);
      rethrow;
    }
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
        color = Colors.blue[400]!;
        break;
      case MessageStatus.failed:
        icon = Icons.error;
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

// 分享帖子卡片组件（独立组件，支持图片高度自适应）
class _SharePostCard extends StatefulWidget {
  final double cardWidth;
  final String title;
  final String authorName;
  final String? authorAvatar;
  final String? firstImage;
  final int likesCount;
  final int commentsCount;
  final double? imageAspectRatio;
  final double? imageNaturalWidth;
  final double? imageNaturalHeight;

  const _SharePostCard({
    required this.cardWidth,
    required this.title,
    required this.authorName,
    this.authorAvatar,
    this.firstImage,
    required this.likesCount,
    required this.commentsCount,
    this.imageAspectRatio,
    this.imageNaturalWidth,
    this.imageNaturalHeight,
  });

  @override
  State<_SharePostCard> createState() => _SharePostCardState();
}

class _SharePostCardState extends State<_SharePostCard> {
  double? _actualImageWidth;
  double? _actualImageHeight;
  bool _isLoadingImageSize = false;

  @override
  void initState() {
    super.initState();
    // 如果后端没有提供尺寸信息，尝试从图片加载时获取
    if (widget.firstImage != null && 
        (widget.imageAspectRatio == null || widget.imageAspectRatio == 0) &&
        (widget.imageNaturalWidth == null || widget.imageNaturalWidth == 0)) {
      _loadImageSize();
    }
  }

  Future<void> _loadImageSize() async {
    if (_isLoadingImageSize || widget.firstImage == null) return;
    
    setState(() {
      _isLoadingImageSize = true;
    });

    try {
      final imageProvider = NetworkImage(widget.firstImage!);
      final ImageStream stream = imageProvider.resolve(const ImageConfiguration());
      final Completer<void> completer = Completer<void>();
      
      ImageStreamListener? listener;
      listener = ImageStreamListener((ImageInfo info, bool synchronousCall) {
        if (!mounted) return;
        
        final image = info.image;
        setState(() {
          _actualImageWidth = image.width.toDouble();
          _actualImageHeight = image.height.toDouble();
          _isLoadingImageSize = false;
        });
        
        stream.removeListener(listener!);
        if (!completer.isCompleted) {
          completer.complete();
        }
      }, onError: (exception, stackTrace) {
        stream.removeListener(listener!);
        if (!completer.isCompleted) {
          completer.complete();
        }
        if (mounted) {
          setState(() {
            _isLoadingImageSize = false;
          });
        }
      });
      
      stream.addListener(listener);
      await completer.future;
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingImageSize = false;
        });
      }
    }
  }

  double _calculateImageHeight() {
    if (widget.firstImage == null) return 120.0;
    
    double aspect = 1.5; // 默认宽高比
    
    // 优先使用实际加载的图片尺寸
    if (_actualImageWidth != null && _actualImageHeight != null && 
        _actualImageWidth! > 0 && _actualImageHeight! > 0) {
      aspect = _actualImageWidth! / _actualImageHeight!;
    }
    // 其次使用后端返回的 imageAspectRatio
    else if (widget.imageAspectRatio != null && widget.imageAspectRatio! > 0) {
      aspect = widget.imageAspectRatio!;
    } 
    // 再次使用 imageNaturalWidth 和 imageNaturalHeight
    else if (widget.imageNaturalWidth != null && widget.imageNaturalHeight != null && 
             widget.imageNaturalWidth! > 0 && widget.imageNaturalHeight! > 0) {
      aspect = widget.imageNaturalWidth! / widget.imageNaturalHeight!;
    }
    
    // 根据宽高比计算高度，限制在合理范围内
    final calculatedHeight = widget.cardWidth / aspect;
    return calculatedHeight.clamp(150.0, 400.0);
  }

  @override
  Widget build(BuildContext context) {
    final imageHeight = _calculateImageHeight();
    
    return Container(
      width: widget.cardWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 帖子图片（自适应高度，参考首页样式）
          if (widget.firstImage != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Container(
                width: widget.cardWidth,
                height: imageHeight,
                color: Colors.grey[100],
                child: Image.network(
                  widget.firstImage!,
                  width: widget.cardWidth,
                  height: imageHeight,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      width: widget.cardWidth,
                      height: imageHeight,
                      color: Colors.grey[100],
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                              : null,
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: widget.cardWidth,
                      height: imageHeight,
                      color: Colors.grey[100],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image_outlined, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            '图片加载失败',
                            style: TextStyle(color: Colors.grey[500], fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            )
          else
            // 没有图片时显示占位符
            Container(
              width: widget.cardWidth,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Center(
                child: Icon(Icons.article_outlined, size: 48, color: Colors.grey[400]),
              ),
            ),
          // 帖子内容区域（参考首页样式：紧凑布局）
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题（参考首页样式）
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                // 用户信息 + 统计信息（参考首页样式）
                Row(
                  children: [
                    // 头像
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.grey[300],
                      child: widget.authorAvatar != null && widget.authorAvatar!.isNotEmpty
                          ? ClipOval(
                              child: Image.network(
                                widget.authorAvatar!,
                                width: 24,
                                height: 24,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.person,
                                    size: 16,
                                    color: Colors.grey,
                                  );
                                },
                              ),
                            )
                          : const Icon(
                              Icons.person,
                              size: 16,
                              color: Colors.grey,
                            ),
                    ),
                    const SizedBox(width: 6),
                    // 作者名称
                    Expanded(
                      child: Text(
                        widget.authorName,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // 统计信息
                    if (widget.likesCount > 0 || widget.commentsCount > 0) ...[
                      Icon(Icons.favorite_outline, size: 12, color: Colors.grey[500]),
                      const SizedBox(width: 2),
                      Text(
                        _formatCount(widget.likesCount),
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.comment_outlined, size: 12, color: Colors.grey[500]),
                      const SizedBox(width: 2),
                      Text(
                        _formatCount(widget.commentsCount),
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 格式化数字显示（如：1000 -> 1k）
  String _formatCount(int count) {
    if (count < 1000) {
      return count.toString();
    } else if (count < 10000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    } else {
      return '${(count / 10000).toStringAsFixed(1)}w';
    }
  }
}
