/// 通知数据模型
class NotificationItem {
  final String id;
  final ActorInfo actor;
  final NotificationType type;
  final String content;
  final PostInfo? post;
  final CommentInfo? comment;
  final bool read;
  final DateTime createdAt;

  NotificationItem({
    required this.id,
    required this.actor,
    required this.type,
    required this.content,
    this.post,
    this.comment,
    required this.read,
    required this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id']?.toString() ?? '',
      actor: ActorInfo.fromJson(json['actor'] ?? {}),
      type: NotificationType.fromString(json['type'] ?? ''),
      content: json['content'] ?? '',
      post: json['post'] != null ? PostInfo.fromJson(json['post']) : null,
      comment: json['comment'] != null ? CommentInfo.fromJson(json['comment']) : null,
      read: json['read'] ?? false,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}

/// 通知类型
enum NotificationType {
  postLike,
  postFavorite,
  commentLike,
  comment,
  mention,
  follow;

  static NotificationType fromString(String type) {
    switch (type.toUpperCase()) {
      case 'POST_LIKE':
        return NotificationType.postLike;
      case 'POST_FAVORITE':
        return NotificationType.postFavorite;
      case 'COMMENT_LIKE':
        return NotificationType.commentLike;
      case 'COMMENT':
        return NotificationType.comment;
      case 'MENTION':
        return NotificationType.mention;
      case 'FOLLOW':
        return NotificationType.follow;
      default:
        return NotificationType.comment;
    }
  }
}

/// 用户信息
class ActorInfo {
  final String id;
  final String name;
  final String? avatar;

  ActorInfo({
    required this.id,
    required this.name,
    this.avatar,
  });

  factory ActorInfo.fromJson(Map<String, dynamic> json) {
    return ActorInfo(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      avatar: json['avatar'],
    );
  }
}

/// 帖子信息
class PostInfo {
  final String id;
  final String title;

  PostInfo({
    required this.id,
    required this.title,
  });

  factory PostInfo.fromJson(Map<String, dynamic> json) {
    return PostInfo(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
    );
  }
}

/// 评论信息
class CommentInfo {
  final String id;
  final String content;

  CommentInfo({
    required this.id,
    required this.content,
  });

  factory CommentInfo.fromJson(Map<String, dynamic> json) {
    return CommentInfo(
      id: json['id']?.toString() ?? '',
      content: json['content'] ?? '',
    );
  }
}

/// 未读数量
class UnreadCount {
  final int likes;
  final int follows;
  final int comments;

  UnreadCount({
    required this.likes,
    required this.follows,
    required this.comments,
  });

  factory UnreadCount.fromJson(Map<String, dynamic> json) {
    return UnreadCount(
      likes: json['likes'] ?? 0,
      follows: json['follows'] ?? 0,
      comments: json['comments'] ?? 0,
    );
  }
}

