/// 热搜条目数据模型
///
/// 用于表示热搜榜单中的单个项目。
class HotSearchItem {
  /// 排名
  final int rank;
  /// 热搜标题
  final String title;
  /// 标签，例如 '新' 或 '热'
  final String? tag; // '新' 或 '热'
  /// 热度值
  final double heat; // 热度值
  /// 对应的搜索方式，例如 'keyword', 'author', 'tag'
  final String searchType; // 对应的搜索方式

  /// [HotSearchItem] 的构造函数
  HotSearchItem({
    required this.rank,
    required this.title,
    this.tag,
    required this.heat,
    required this.searchType,
  });

  /// 格式化热度值
  ///
  /// 如果热度值大于等于10000，则显示为'x.x万'的形式。
  /// 否则，直接显示为整数。
  String get formattedHeat {
    if (heat >= 10000) {
      return '${(heat / 10000).toStringAsFixed(1)}万';
    }
    return heat.toStringAsFixed(0);
  }
}

/// 搜索历史条目数据模型
///
/// 用于表示用户的单条搜索历史记录。
class SearchHistoryItem {
  /// 唯一标识符
  final String id;
  /// 搜索的关键词
  final String keyword;
  /// 搜索类型
  final String searchType;
  /// 搜索操作的时间戳
  final DateTime timestamp;

  /// [SearchHistoryItem] 的构造函数
  SearchHistoryItem({
    required this.id,
    required this.keyword,
    required this.searchType,
    required this.timestamp,
  });

  /// 转换为Map用于存储
  ///
  /// 将 [SearchHistoryItem] 对象转换为一个Map，便于序列化和存储（例如在本地数据库中）。
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'keyword': keyword,
      'searchType': searchType,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  /// 从Map创建对象
  ///
  /// 从一个Map对象反序列化为 [SearchHistoryItem] 对象。
  static SearchHistoryItem fromMap(Map<String, dynamic> map) {
    return SearchHistoryItem(
      id: map['id'],
      keyword: map['keyword'],
      searchType: map['searchType'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
    );
  }
}

/// 模拟的热搜数据列表
///
/// 在没有后端API时，用于前端页面展示的静态热搜数据。
List<HotSearchItem> mockHotSearches = [
  HotSearchItem(
    rank: 1,
    title: '深度学习',
    tag: '热',
    heat: 125.6,
    searchType: 'keyword',
  ),
  HotSearchItem(
    rank: 2,
    title: '机器学习',
    tag: '热',
    heat: 98.3,
    searchType: 'keyword',
  ),
  HotSearchItem(
    rank: 3,
    title: '计算机视觉',
    tag: '新',
    heat: 76.2,
    searchType: 'keyword',
  ),
  HotSearchItem(
    rank: 4,
    title: '自然语言处理',
    tag: null,
    heat: 65.8,
    searchType: 'keyword',
  ),
  HotSearchItem(
    rank: 5,
    title: '强化学习',
    tag: null,
    heat: 54.1,
    searchType: 'keyword',
  ),
  HotSearchItem(
    rank: 6,
    title: '神经网络',
    tag: null,
    heat: 48.7,
    searchType: 'keyword',
  ),
  HotSearchItem(
    rank: 7,
    title: '人工智能',
    tag: null,
    heat: 42.3,
    searchType: 'keyword',
  ),
  HotSearchItem(
    rank: 8,
    title: '数据挖掘',
    tag: null,
    heat: 38.9,
    searchType: 'keyword',
  ),
  HotSearchItem(
    rank: 9,
    title: 'Python',
    tag: '新',
    heat: 35.4,
    searchType: 'tag',
  ),
  HotSearchItem(
    rank: 10,
    title: 'TensorFlow',
    tag: null,
    heat: 32.1,
    searchType: 'tag',
  ),
  HotSearchItem(
    rank: 11,
    title: 'PyTorch',
    tag: null,
    heat: 29.8,
    searchType: 'tag',
  ),
  HotSearchItem(
    rank: 12,
    title: 'Transformer',
    tag: null,
    heat: 27.5,
    searchType: 'keyword',
  ),
  HotSearchItem(
    rank: 13,
    title: 'GAN',
    tag: null,
    heat: 25.3,
    searchType: 'keyword',
  ),
  HotSearchItem(
    rank: 14,
    title: 'CNN',
    tag: null,
    heat: 23.6,
    searchType: 'keyword',
  ),
  HotSearchItem(
    rank: 15,
    title: 'RNN',
    tag: null,
    heat: 21.9,
    searchType: 'keyword',
  ),
  HotSearchItem(
    rank: 16,
    title: '李沐',
    tag: null,
    heat: 19.7,
    searchType: 'author',
  ),
  HotSearchItem(
    rank: 17,
    title: '吴恩达',
    tag: null,
    heat: 18.2,
    searchType: 'author',
  ),
  HotSearchItem(
    rank: 18,
    title: 'Yoshua Bengio',
    tag: null,
    heat: 16.8,
    searchType: 'author',
  ),
  HotSearchItem(
    rank: 19,
    title: 'Yann LeCun',
    tag: null,
    heat: 15.4,
    searchType: 'author',
  ),
  HotSearchItem(
    rank: 20,
    title: 'Geoffrey Hinton',
    tag: null,
    heat: 14.1,
    searchType: 'author',
  ),
];
