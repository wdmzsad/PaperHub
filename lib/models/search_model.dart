class HotSearchItem {
  final int rank;
  final String title;
  final String? tag; // '新' 或 '热'
  final double heat; // 热度值
  final String searchType; // 对应的搜索方式

  HotSearchItem({
    required this.rank,
    required this.title,
    this.tag,
    required this.heat,
    required this.searchType,
  });

  // 格式化热度值
  String get formattedHeat {
    if (heat >= 10000) {
      return '${(heat / 10000).toStringAsFixed(1)}万';
    }
    return heat.toStringAsFixed(0);
  }
}

class SearchHistoryItem {
  final String id;
  final String keyword;
  final String searchType;
  final DateTime timestamp;

  SearchHistoryItem({
    required this.id,
    required this.keyword,
    required this.searchType,
    required this.timestamp,
  });

  // 转换为Map用于存储
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'keyword': keyword,
      'searchType': searchType,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  // 从Map创建对象
  static SearchHistoryItem fromMap(Map<String, dynamic> map) {
    return SearchHistoryItem(
      id: map['id'],
      keyword: map['keyword'],
      searchType: map['searchType'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
    );
  }
}

// 模拟热搜数据
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
