class Post {
  final String id;
  final String title;
  final String imageUrl;
  final String userAvatar;
  final String userId;
  final double imageAspectRatio;
  final double imageNaturalWidth;
  final double imageNaturalHeight;

  Post({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.userAvatar,
    required this.userId,
    required this.imageAspectRatio,
    required this.imageNaturalWidth,
    required this.imageNaturalHeight,
  });

  double get displayHeight {
    return 200 / imageAspectRatio;
  }
}

// 原始 6 条
final List<Post> _basePosts = [
  Post(
    id: '1',
    title: '深度学习在自然语言处理中的应用研究',
    imageUrl: 'images/imageUrl1.png',
    userAvatar: 'images/userAvatar1.png',
    userId: 'AI_researcher',
    imageAspectRatio: 1.5,
    imageNaturalWidth: 991,
    imageNaturalHeight: 1037,
  ),
  Post(
    id: '2',
    title: '量子计算的最新突破与未来展望',
    imageUrl: 'images/imageUrl2.png',
    userAvatar: 'images/userAvatar2.png',
    userId: 'quantum_physicist',
    imageAspectRatio: 1.25,
    imageNaturalWidth: 1262,
    imageNaturalHeight: 727,
  ),
  Post(
    id: '3',
    title: '新型材料在能源存储中的应用',
    imageUrl: 'images/imageUrl3.jpg',
    userAvatar: 'images/userAvatar3.png',
    userId: 'material_scientist',
    imageAspectRatio: 1.75,
    imageNaturalWidth: 1056,
    imageNaturalHeight: 816,
  ),
  Post(
    id: '4',
    title: '机器学习模型优化策略分析',
    imageUrl: 'images/imageUrl4.png',
    userAvatar: 'images/userAvatar4.png',
    userId: 'ml_engineer',
    imageAspectRatio: 1.125,
    imageNaturalWidth: 1506,
    imageNaturalHeight: 836,
  ),
  Post(
    id: '5',
    title: '生物信息学中的算法创新',
    imageUrl: 'images/imageUrl5.jpg',
    userAvatar: 'images/userAvatar5.png',
    userId: 'bioinformatics',
    imageAspectRatio: 1.375,
    imageNaturalWidth: 1400,
    imageNaturalHeight: 742,
  ),
  Post(
    id: '6',
    title: '计算机视觉在医疗影像中的应用',
    imageUrl: 'images/imageUrl6.jpg',
    userAvatar: 'images/userAvatar6.png',
    userId: 'cv_researcher',
    imageAspectRatio: 1.625,
    imageNaturalWidth: 578,
    imageNaturalHeight: 437,
  ),
];

// 生成 20 条模拟数据
List<Post> mockPosts = List.generate(20, (i) {
  final base = _basePosts[i % _basePosts.length];
  return Post(
    id: (i + 1).toString(),
    title: '${base.title}（扩展样例 ${i + 1}）',
    imageUrl: base.imageUrl,
    userAvatar: base.userAvatar,
    userId: '${base.userId}_${i + 1}',
    imageAspectRatio: base.imageAspectRatio,
    imageNaturalWidth: base.imageNaturalWidth,
    imageNaturalHeight: base.imageNaturalHeight,
  );
});
