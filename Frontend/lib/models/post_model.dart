// lib/models/post_model.dart

import 'package:flutter/foundation.dart';

class Author {
  final String id;
  final String name;
  final String avatar; // asset path or network url
  final String? affiliation;

  Author({
    required this.id,
    required this.name,
    required this.avatar,
    this.affiliation,
  });
}

class Attachment {
  final String id;
  final String fileName;
  final String url; // asset path or network url
  final int sizeBytes;

  Attachment({
    required this.id,
    required this.fileName,
    required this.url,
    required this.sizeBytes,
  });
}

class Comment {
  final String id;
  final Author author;
  final String content;
  final String? parentId;  // 父评论ID，用于嵌套回复，顶层评论为 null
  final Author? replyTo;   // 被回复的用户，用于 @ 通知
  int likesCount;
  bool isLiked;
  final DateTime createdAt;
  final List<Comment> replies;  // 子回复列表
  final List<Author> mentions;  // 被@的用户列表
  bool _expanded = true;  // UI 状态：是否展开子回复

  bool get isExpanded => _expanded;
  void toggleExpanded() => _expanded = !_expanded;
  bool get hasReplies => replies.isNotEmpty;
  bool get isReply => parentId != null;

  Comment({
    required this.id,
    required this.author,
    required this.content,
    this.parentId,
    this.replyTo,
    this.likesCount = 0,
    this.isLiked = false,
    this.replies = const [],
    this.mentions = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 创建一个回复
  Comment createReply({
    required String id,
    required Author author,
    required String content,
    Author? replyTo,
  }) {
    return Comment(
      id: id,
      author: author,
      content: content,
      parentId: this.id,
      replyTo: replyTo ?? this.author,
      createdAt: DateTime.now(),
    );
  }

  /// 从 JSON 创建评论（用于 API 响应解析）
  factory Comment.fromJson(Map<String, dynamic> json) {
    // 安全地处理ID（可能是String或数字）
    final idValue = json['id'];
    final id = idValue is String ? idValue : idValue.toString();
    
    // 安全地处理author
    final authorJson = json['author'] as Map<String, dynamic>? ?? {};
    final authorIdValue = authorJson['id'];
    final authorId = authorIdValue is String ? authorIdValue : authorIdValue.toString();
    
    // 安全地处理parentId
    final parentIdValue = json['parentId'];
    final parentId = parentIdValue == null ? null : 
        (parentIdValue is String ? parentIdValue : parentIdValue.toString());
    
    // 安全地处理replyTo
    Author? replyTo;
    if (json['replyTo'] != null) {
      final replyToJson = json['replyTo'] as Map<String, dynamic>;
      final replyToIdValue = replyToJson['id'];
      final replyToId = replyToIdValue is String ? replyToIdValue : replyToIdValue.toString();
      replyTo = Author(
        id: replyToId,
        name: replyToJson['name'] as String? ?? 
              (replyToJson['email'] as String? ?? '未知用户'),
        avatar: replyToJson['avatar'] as String? ?? '',
        affiliation: replyToJson['affiliation'] as String?,
      );
    }
    
    // 解析被@的用户列表
    List<Author> mentions = [];
    if (json['mentions'] != null) {
      final mentionsJson = json['mentions'] as List<dynamic>? ?? [];
      mentions = mentionsJson.map((m) {
        final mentionJson = m as Map<String, dynamic>;
        final mentionIdValue = mentionJson['id'];
        final mentionId = mentionIdValue is String ? mentionIdValue : mentionIdValue.toString();
        return Author(
          id: mentionId,
          name: mentionJson['name'] as String? ?? 
                (mentionJson['email'] as String? ?? '未知用户'),
          avatar: mentionJson['avatar'] as String? ?? '',
          affiliation: mentionJson['affiliation'] as String?,
        );
      }).toList();
    }
    
    return Comment(
      id: id,
      author: Author(
        id: authorId,
        name: authorJson['name'] as String? ?? 
              (authorJson['email'] as String? ?? '未知用户'),
        avatar: authorJson['avatar'] as String? ?? '',
        affiliation: authorJson['affiliation'] as String?,
      ),
      content: json['content'] as String? ?? '',
      parentId: parentId,
      replyTo: replyTo,
      likesCount: (json['likesCount'] as num?)?.toInt() ?? 0,
      isLiked: json['isLiked'] as bool? ?? false,
      replies: (json['replies'] as List<dynamic>?)
              ?.map((e) => Comment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      mentions: mentions,
      createdAt: json['createdAt'] == null
          ? DateTime.now()
          : DateTime.parse(json['createdAt'].toString()),
    );
  }

  /// 转换为 JSON（用于 API 请求）
  Map<String, dynamic> toJson() => {
        'id': id,
        'author': {
          'id': author.id,
          'name': author.name,
          'avatar': author.avatar,
          if (author.affiliation != null) 'affiliation': author.affiliation,
        },
        'content': content,
        if (parentId != null) 'parentId': parentId,
        if (replyTo != null)
          'replyTo': {
            'id': replyTo!.id,
            'name': replyTo!.name,
            'avatar': replyTo!.avatar,
            if (replyTo!.affiliation != null)
              'affiliation': replyTo!.affiliation,
          },
        'likesCount': likesCount,
        'isLiked': isLiked,
        'replies': replies.map((r) => r.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };
}

class Post {
  final String id;
  final String title;
  final String content; // 富文本/纯文本（演示）
  final List<String> media; // 图片 url 列表（可为空）
  final List<Attachment> attachments; // PDF 等附件
  final List<String> externalLinks; // 外部链接列表
  final List<String> tags;
  final Author author;

  // 统计与状态（通常由后端返回）
  int likesCount;
  int commentsCount;
  int viewsCount;
  bool isLiked;
  bool isSaved;

  // 论文 / 元数据（可选）
  final String? doi;
  final String? journal;
  final int? year;
  
  // arXiv 相关元数据（可选）
  final String? arxivId;
  final List<String> arxivAuthors; // arXiv 作者列表
  final String? arxivPublishedDate; // 发布日期（格式：YYYY-MM-DD）
  final List<String> arxivCategories; // arXiv 分类

  // 图片展示相关（保持原来字段以兼容瀑布流计算）
  final double imageAspectRatio;
  final double imageNaturalWidth;
  final double imageNaturalHeight;

  final DateTime createdAt;
  // 可选：帖子下的评论列表（通常由后端分页查询，这里在 Post 载入详情时可填充）
  final List<Comment> comments;

  Post({
    required this.id,
    required this.title,
    required this.content,
    required this.media,
    required this.attachments,
    required this.tags,
    required this.author,
    required this.externalLinks,
    this.comments = const [],
    this.likesCount = 0,
    this.commentsCount = 0,
    this.viewsCount = 0,
    this.isLiked = false,
    this.isSaved = false,
    this.doi,
    this.journal,
    this.year,
    this.arxivId,
    this.arxivAuthors = const [],
    this.arxivPublishedDate,
    this.arxivCategories = const [],
    required this.imageAspectRatio,
    required this.imageNaturalWidth,
    required this.imageNaturalHeight,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double get displayHeight {
    final ratio = imageAspectRatio == 0 ? 1.0 : imageAspectRatio;
    return 200 / ratio;
  }

  /// 从JSON创建Post（用于API响应解析）
  factory Post.fromJson(Map<String, dynamic> json) {
    // 安全地处理ID（可能是String或数字）
    final idValue = json['id'];
    final id = idValue is String ? idValue : idValue.toString();
    
    // 安全地处理author
    final authorJson = json['author'] as Map<String, dynamic>? ?? {};
    final authorIdValue = authorJson['id'];
    final authorId = authorIdValue is String ? authorIdValue : authorIdValue.toString();
    
    return Post(
      id: id,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      media: (json['media'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      attachments: [], // 后端暂时不支持附件，需要后续添加
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],

      externalLinks: (json['externalLinks'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList()
          ?? const [],
          
      author: Author(
        id: authorId,
        name: authorJson['name'] as String? ?? 
              (authorJson['email'] as String? ?? '未知用户'),
        avatar: authorJson['avatar'] as String? ?? '',
        affiliation: authorJson['affiliation'] as String?,
      ),
      likesCount: (json['likesCount'] as num?)?.toInt() ?? 0,
      commentsCount: (json['commentsCount'] as num?)?.toInt() ?? 0,
      viewsCount: (json['viewsCount'] as num?)?.toInt() ?? 0,
      isLiked: json['isLiked'] as bool? ?? false,
      isSaved: json['isSaved'] as bool? ?? false,
      doi: json['doi'] as String?,
      journal: json['journal'] as String?,
      year: (json['year'] as num?)?.toInt(),
      arxivId: json['arxivId'] as String?,
      arxivAuthors: (json['arxivAuthors'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ?? const [],
      arxivPublishedDate: json['arxivPublishedDate'] as String?,
      arxivCategories: (json['arxivCategories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ?? const [],
      imageAspectRatio: (json['imageAspectRatio'] as num?)?.toDouble() ?? 1.5,
      imageNaturalWidth: (json['imageNaturalWidth'] as num?)?.toDouble() ?? 800.0,
      imageNaturalHeight: (json['imageNaturalHeight'] as num?)?.toDouble() ?? 600.0,
      createdAt: json['createdAt'] == null
          ? DateTime.now()
          : DateTime.parse(json['createdAt'].toString()),
    );
  }
}
