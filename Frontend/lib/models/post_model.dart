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
    return Comment(
      id: json['id'] as String,
      author: Author(
        id: json['author']['id'] as String,
        name: json['author']['name'] as String,
        avatar: json['author']['avatar'] as String,
        affiliation: json['author']['affiliation'] as String?,
      ),
      content: json['content'] as String,
      parentId: json['parentId'] as String?,
      replyTo: json['replyTo'] == null
          ? null
          : Author(
              id: json['replyTo']['id'] as String,
              name: json['replyTo']['name'] as String,
              avatar: json['replyTo']['avatar'] as String,
              affiliation: json['replyTo']['affiliation'] as String?,
            ),
      likesCount: json['likesCount'] as int? ?? 0,
      isLiked: json['isLiked'] as bool? ?? false,
      replies: (json['replies'] as List<dynamic>?)
              ?.map((e) => Comment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
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
    this.comments = const [],
    this.likesCount = 0,
    this.commentsCount = 0,
    this.viewsCount = 0,
    this.isLiked = false,
    this.isSaved = false,
    this.doi,
    this.journal,
    this.year,
    required this.imageAspectRatio,
    required this.imageNaturalWidth,
    required this.imageNaturalHeight,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double get displayHeight {
    final ratio = imageAspectRatio == 0 ? 1.0 : imageAspectRatio;
    return 200 / ratio;
  }
}

// 基础样例数据（含 author、attachment、tags、content、media）
final List<Post> _basePosts = [
  Post(
    id: '1',
    title: '深度学习在自然语言处理中的应用研究',
    content:
        '本文笔记总结了 Transformer 架构在 NLP 中的作用，包含实验设置、数据集说明以及若干改进点建议。',
    media: ['images/imageUrl1.png'],
    attachments: [
      Attachment(id: 'a1', fileName: 'paper1.pdf', url: 'assets/papers/paper1.pdf', sizeBytes: 123456),
    ],
    tags: ['深度学习', 'NLP', 'Transformer'],
    author: Author(id: 'AI_researcher', name: 'Alice Zhang', avatar: 'images/userAvatar1.png', affiliation: '某大学·计算机学院'),
    likesCount: 120,
    commentsCount: 18,
    viewsCount: 1024,
    isLiked: false,
    isSaved: false,
    doi: '10.1234/example.doi.1',
    journal: 'Journal of AI Research',
    year: 2023,
    imageAspectRatio: 1.5,
    imageNaturalWidth: 991,
    imageNaturalHeight: 1037,
    createdAt: DateTime.now().subtract(Duration(hours: 3)),
  ),
  Post(
    id: '2',
    title: '量子计算的最新突破与未来展望',
    content: '本条笔记摘录了三篇重要论文与研究方向建议，包含关键公式与实验结果讨论。',
    media: ['images/imageUrl2.png'],
    attachments: [],
    tags: ['量子计算', '综述'],
    author: Author(id: 'quantum_physicist', name: 'Dr. Li Wei', avatar: 'images/userAvatar2.png', affiliation: '量子研究所'),
    likesCount: 86,
    commentsCount: 12,
    viewsCount: 840,
    isLiked: false,
    isSaved: true,
    doi: null,
    journal: null,
    year: null,
    imageAspectRatio: 1.25,
    imageNaturalWidth: 1262,
    imageNaturalHeight: 727,
    createdAt: DateTime.now().subtract(Duration(days: 1, hours: 2)),
  ),
  Post(
    id: '3',
    title: '新型材料在能源存储中的应用',
    content: '实验数据、材料制备步骤与性能对比表均记录在附件的 PDF 中，参见附录。',
    media: ['images/imageUrl3.jpg'],
    attachments: [
      Attachment(id: 'a3', fileName: 'supplementary.pdf', url: 'assets/papers/supp3.pdf', sizeBytes: 456789),
    ],
    tags: ['材料', '能源'],
    author: Author(id: 'material_scientist', name: 'Chen Ming', avatar: 'images/userAvatar3.png', affiliation: '材料学院'),
    likesCount: 54,
    commentsCount: 7,
    viewsCount: 412,
    isLiked: false,
    isSaved: false,
    doi: '10.5678/materials.2022',
    journal: 'Materials Today',
    year: 2022,
    imageAspectRatio: 1.75,
    imageNaturalWidth: 1056,
    imageNaturalHeight: 816,
    createdAt: DateTime.now().subtract(Duration(days: 2)),
  ),
  // ... 保留原 4/5/6 项（改写为带 author/attachments 等）
  Post(
    id: '4',
    title: '机器学习模型优化策略分析',
    content: '包含超参搜索、正则化技巧和模型压缩方法的实践建议。',
    media: ['images/imageUrl4.png'],
    attachments: [],
    tags: ['机器学习', '模型优化'],
    author: Author(id: 'ml_engineer', name: 'Wang Lei', avatar: 'images/userAvatar4.png'),
    likesCount: 71,
    commentsCount: 9,
    viewsCount: 600,
    isLiked: false,
    isSaved: false,
    doi: null,
    journal: null,
    year: null,
    imageAspectRatio: 1.125,
    imageNaturalWidth: 1506,
    imageNaturalHeight: 836,
    createdAt: DateTime.now().subtract(Duration(hours: 12)),
  ),
  Post(
    id: '5',
    title: '生物信息学中的算法创新',
    content: '讨论了高维基因表达数据的降维与聚类方法，以及若干开源工具链。',
    media: ['images/imageUrl5.jpg'],
    attachments: [],
    tags: ['生物信息学', '算法'],
    author: Author(id: 'bioinformatics', name: 'Zhao Rui', avatar: 'images/userAvatar5.png'),
    likesCount: 38,
    commentsCount: 4,
    viewsCount: 290,
    isLiked: false,
    isSaved: false,
    doi: null,
    journal: null,
    year: null,
    imageAspectRatio: 1.375,
    imageNaturalWidth: 1400,
    imageNaturalHeight: 742,
    createdAt: DateTime.now().subtract(Duration(days: 5)),
  ),
  Post(
    id: '6',
    title: '计算机视觉在医疗影像中的应用',
    content: '我们记录了数据预处理流程和常见 pitfalls，建议采样策略参考附表。',
    media: ['images/imageUrl6.jpg'],
    attachments: [],
    tags: ['计算机视觉', '医疗'],
    author: Author(id: 'cv_researcher', name: 'Liu Yang', avatar: 'images/userAvatar6.png'),
    likesCount: 99,
    commentsCount: 20,
    viewsCount: 1500,
    isLiked: true,
    isSaved: true,
    doi: '10.9012/cvmed.2021',
    journal: 'Medical Imaging',
    year: 2021,
    imageAspectRatio: 1.625,
    imageNaturalWidth: 578,
    imageNaturalHeight: 437,
    createdAt: DateTime.now().subtract(Duration(hours: 48)),
  ),
];

// 生成 20 条模拟数据（扩展 base）
List<Post> mockPosts = List.generate(20, (i) {
  final base = _basePosts[i % _basePosts.length];
  return Post(
    id: (i + 1).toString(),
    title: '${base.title}（扩展样例 ${i + 1}）',
    content: base.content + '\n\n（扩展示例内容，用于演示）',
    media: List<String>.from(base.media),
    attachments: List<Attachment>.from(base.attachments),
    tags: List<String>.from(base.tags),
    author: Author(
      id: '${base.author.id}_$i',
      name: '${base.author.name} · ${i + 1}',
      avatar: base.author.avatar,
      affiliation: base.author.affiliation,
    ),
    likesCount: base.likesCount + (i % 7),
    commentsCount: base.commentsCount + (i % 5),
    viewsCount: base.viewsCount + i * 10,
    isLiked: (i % 6 == 0),
    isSaved: (i % 10 == 0),
    doi: base.doi,
    journal: base.journal,
    year: base.year,
    imageAspectRatio: base.imageAspectRatio,
    imageNaturalWidth: base.imageNaturalWidth,
    imageNaturalHeight: base.imageNaturalHeight,
    createdAt: DateTime.now().subtract(Duration(hours: i * 2)),
  );
});
