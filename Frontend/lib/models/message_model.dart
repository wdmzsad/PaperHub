/// 消息数据模型
///
/// 支持多种消息类型：文本、图片、文件等
import 'dart:convert';

class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String senderAvatar;
  final String content;
  final MessageType type;
  final List<String> mediaUrls;
  final String? fileUrl;
  final String? fileName;
  final int? fileSize;
  final DateTime createdAt;
  final MessageStatus status;
  final bool isMe;
  final Map<String, dynamic>? sharePost; // 分享的帖子信息（当 type 为 share 时使用）

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.senderAvatar,
    required this.content,
    this.type = MessageType.text,
    this.mediaUrls = const [],
    this.fileUrl,
    this.fileName,
    this.fileSize,
    required this.createdAt,
    this.status = MessageStatus.sent,
    this.isMe = false,
    this.sharePost,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    String typeStr = (json['type'] ?? 'TEXT').toString().toUpperCase();
    MessageType messageType = MessageType.text;
    String content = json['content'] ?? '';
    Map<String, dynamic>? sharePost;

    switch (typeStr) {
      case 'IMAGE':
        messageType = MessageType.image;
        break;
      case 'FILE':
        messageType = MessageType.file;
        break;
      case 'VOICE':
        messageType = MessageType.voice;
        break;
      case 'SYSTEM':
        messageType = MessageType.system;
        break;
      case 'VIDEO':
        messageType = MessageType.video;
      case 'SHARE':
        messageType = MessageType.share;
        // SHARE 类型的 content 存储的是 post ID
        // sharePost 字段会在前端显示时根据 post ID 动态获取
        break;
      default:
        messageType = MessageType.text;
    }

    return Message(
      id: json['id']?.toString() ?? '',
      conversationId: json['conversationId']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      senderName: json['senderName'] ?? '',
      senderAvatar: json['senderAvatar'] ?? '',
      content: content,
      type: messageType,
      mediaUrls: json['mediaUrls'] != null
          ? List<String>.from(json['mediaUrls'])
          : [],
      fileUrl: json['fileUrl'],
      fileName: json['fileName'],
      fileSize: json['fileSize'],
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      status: MessageStatus.values.firstWhere(
        (e) => e.toString() == 'MessageStatus.${json['status']}',
        orElse: () => MessageStatus.sent,
      ),
      isMe: json['isMe'] ?? false,
      sharePost: sharePost,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'content': content,
      'type': type.toString().split('.').last.toUpperCase(),
      'mediaUrls': mediaUrls,
      if (fileUrl != null) 'fileUrl': fileUrl,
      if (fileName != null) 'fileName': fileName,
      if (fileSize != null) 'fileSize': fileSize,
      'createdAt': createdAt.toIso8601String(),
      'status': status.toString().split('.').last,
      'isMe': isMe,
      if (sharePost != null) 'sharePost': sharePost,
    };
  }

  Message copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderName,
    String? senderAvatar,
    String? content,
    MessageType? type,
    List<String>? mediaUrls,
    String? fileUrl,
    String? fileName,
    int? fileSize,
    DateTime? createdAt,
    MessageStatus? status,
    bool? isMe,
    Map<String, dynamic>? sharePost,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      content: content ?? this.content,
      type: type ?? this.type,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      isMe: isMe ?? this.isMe,
      sharePost: sharePost ?? this.sharePost,
    );
  }
}

/// 消息类型枚举
enum MessageType {
  text,    // 文本消息
  image,   // 图片消息
  file,    // 文件消息
  voice,   // 语音消息
  system,  // 系统消息
  video,   // 视频消息
  share,   // 分享消息（帖子）
}

/// 消息状态枚举
enum MessageStatus {
  sending,  // 发送中
  sent,     // 已发送
  delivered, // 已送达
  read,     // 已读
  failed,   // 发送失败
}