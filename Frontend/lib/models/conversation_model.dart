/// 聊天会话数据模型
///
/// 表示一个私聊或群聊会话

// 引入 Message 模型
import 'message_model.dart';

class Conversation {
  final String id;
  final String name;
  final String? avatar;
  final ConversationType type;
  final Message? lastMessage;
  final int unreadCount;
  final DateTime updatedAt;
  final List<ConversationParticipant> participants;
  final bool isOnline;
  final bool isTyping;

  Conversation({
    required this.id,
    required this.name,
    this.avatar,
    this.type = ConversationType.private,
    this.lastMessage,
    this.unreadCount = 0,
    required this.updatedAt,
    this.participants = const [],
    this.isOnline = false,
    this.isTyping = false,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      avatar: json['avatar'],
      type: ConversationType.values.firstWhere(
        (e) => e.toString() == 'ConversationType.${json['type']}',
        orElse: () => ConversationType.private,
      ),
      lastMessage: json['lastMessage'] != null
          ? Message.fromJson(json['lastMessage'])
          : null,
      unreadCount: json['unreadCount'] ?? 0,
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
      participants: (json['participants'] as List<dynamic>?)
          ?.map((p) => ConversationParticipant.fromJson(p))
          .toList() ?? [],
      isOnline: json['isOnline'] ?? false,
      isTyping: json['isTyping'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatar': avatar,
      'type': type.toString().split('.').last,
      'lastMessage': lastMessage?.toJson(),
      'unreadCount': unreadCount,
      'updatedAt': updatedAt.toIso8601String(),
      'participants': participants.map((p) => p.toJson()).toList(),
      'isOnline': isOnline,
      'isTyping': isTyping,
    };
  }

  /// 获取显示标题（私聊显示对方名称，群聊显示群名）
  String get displayName {
    return type == ConversationType.private && participants.isNotEmpty
        ? participants.firstWhere((p) => !p.isMe).name
        : name;
  }

  /// 获取显示头像
  String? get displayAvatar {
    if (type == ConversationType.private && participants.isNotEmpty) {
      return participants.firstWhere((p) => !p.isMe).avatar;
    }
    return avatar;
  }

  Conversation copyWith({
    String? id,
    String? name,
    String? avatar,
    ConversationType? type,
    Message? lastMessage,
    int? unreadCount,
    DateTime? updatedAt,
    List<ConversationParticipant>? participants,
    bool? isOnline,
    bool? isTyping,
  }) {
    return Conversation(
      id: id ?? this.id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      type: type ?? this.type,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      updatedAt: updatedAt ?? this.updatedAt,
      participants: participants ?? this.participants,
      isOnline: isOnline ?? this.isOnline,
      isTyping: isTyping ?? this.isTyping,
    );
  }
}

/// 会话类型枚举
enum ConversationType {
  private,  // 私聊
  group,    // 群聊
}

/// 会话参与者信息
class ConversationParticipant {
  final String id;
  final String name;
  final String? avatar;
  final bool isMe;
  final bool isOnline;
  final DateTime? lastSeen;

  ConversationParticipant({
    required this.id,
    required this.name,
    this.avatar,
    this.isMe = false,
    this.isOnline = false,
    this.lastSeen,
  });

  factory ConversationParticipant.fromJson(Map<String, dynamic> json) {
    return ConversationParticipant(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      avatar: json['avatar'],
      isMe: json['isMe'] ?? false,
      isOnline: json['isOnline'] ?? false,
      lastSeen: json['lastSeen'] != null
          ? DateTime.parse(json['lastSeen'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatar': avatar,
      'isMe': isMe,
      'isOnline': isOnline,
      'lastSeen': lastSeen?.toIso8601String(),
    };
  }
}