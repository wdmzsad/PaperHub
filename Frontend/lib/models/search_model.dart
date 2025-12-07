/// PaperHub 前端模型：搜索
///
/// 本文件定义：
/// - HotSearchItem：表示热搜榜单中的一条目
/// - SearchHistoryItem：表示一次搜索历史记录
///
/// 设计约定与数据契约（Contract）：
/// - rank >= 1 且用于排序展示；同一时间应唯一。
/// - tag 允许为 '新' | '热' | null（null 表示普通项）。
/// - heat 为相对热度值（非百分比），建议范围 >= 0。
/// - searchType 允许值：'keyword' | 'author' | 'tag'，用于驱动前端的不同搜索路径。
/// - SearchHistoryItem.timestamp 使用本地时区的 DateTime，序列化为毫秒时间戳。
///
/// 使用建议：
/// - UI 可根据 tag 渲染标记（如“新”“热”徽标），根据 rank 渲染前 3 名的特殊样式。
/// - formattedHeat 仅做展示层格式化，不参与任何排序或计算。
/// - 当接入真实后端时，确保后端返回字段与本数据模型保持一致或在适配层转换。
///
/// 热搜条目数据模型
///
/// 用于表示热搜榜单中的单个项目。
class HotSearchItem {
  /// 排名
  final int rank;
  /// 热搜标题
  final String title;
  /// 标签，例如 '新' 或 '热'
  /// 允许值：
  /// - '新'：表示新近上榜/新增话题
  /// - '热'：表示当前热度较高
  /// - null：无特殊标记
  final String? tag;
  /// 热度值
  /// 单位：相对热度分（非百分比），用于展示排序与强弱对比。
  /// 建议范围：>= 0；来源可为后端统计或前端模拟。
  final double heat;
  /// 对应的搜索方式，例如 'keyword', 'author', 'tag'
  /// 允许值：'keyword' | 'author' | 'tag'。
  /// 用途：根据此类型决定触发的搜索 API 或过滤逻辑。
  final String searchType;

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
  /// 示例：
  /// - 9800 -> '9800'
  /// - 12500 -> '1.3万'
  /// 注意：此格式化仅影响展示，不改变原始数值。
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
  /// 示例：'深度学习'、'李沐'、'Python' 等。
  final String keyword;
  /// 搜索类型
  /// 与 HotSearchItem.searchType 含义一致，便于历史回放时决定搜索路径。
  final String searchType;
  /// 搜索操作的时间戳
  /// 使用本地时间的 DateTime。持久化时将转换为毫秒时间戳（ since epoch ）。
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
  /// 返回的键包含：
  /// - 'id'：String
  /// - 'keyword'：String
  /// - 'searchType'：String（'keyword' | 'author' | 'tag'）
  /// - 'timestamp'：int（毫秒）
  /// 注意：请保持此 Schema 稳定，以避免存量数据解析失败。
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
  /// 要求传入的 map 至少包含键：'id'、'keyword'、'searchType'、'timestamp'（毫秒）。
  /// 若缺失键或类型不匹配，调用方应在外层做校验或容错处理。
  static SearchHistoryItem fromMap(Map<String, dynamic> map) {
    return SearchHistoryItem(
      id: map['id'],
      keyword: map['keyword'],
      searchType: map['searchType'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
    );
  }

  /// 从云端API数据创建对象
  ///
  /// 云端API返回的数据结构包含：
  /// - 'id': 数字ID (需要转换为String)
  /// - 'keyword': 字符串
  /// - 'searchType': 字符串 ('keyword' | 'tag' | 'author')
  /// - 'searchCount': 数字 (搜索次数)
  /// - 'createdAt': ISO字符串
  /// - 'updatedAt': ISO字符串
  /// 使用 updatedAt 作为时间戳
  static SearchHistoryItem fromCloudData(Map<String, dynamic> map) {
    // 处理ID，可能是数字或字符串
    final id = map['id']?.toString() ?? '';

    // 处理时间戳，优先使用 updatedAt，其次 createdAt，最后当前时间
    DateTime timestamp;
    try {
      final updatedAtStr = map['updatedAt']?.toString();
      if (updatedAtStr != null && updatedAtStr.isNotEmpty) {
        timestamp = DateTime.parse(updatedAtStr);
      } else {
        final createdAtStr = map['createdAt']?.toString();
        if (createdAtStr != null && createdAtStr.isNotEmpty) {
          timestamp = DateTime.parse(createdAtStr);
        } else {
          timestamp = DateTime.now();
        }
      }
    } catch (e) {
      timestamp = DateTime.now();
    }

    return SearchHistoryItem(
      id: id,
      keyword: map['keyword']?.toString() ?? '',
      searchType: map['searchType']?.toString() ?? 'keyword',
      timestamp: timestamp,
    );
  }
}

/// 模拟的热搜数据列表
///
/// 在没有后端API时，用于前端页面展示的静态热搜数据。
/// 特性：
/// - 数据按 rank 升序排列，便于直接展示。
/// - 覆盖三类 searchType：'keyword'、'tag'、'author'，用于联调 UI 与交互逻辑。
/// - 可作为单元测试或组件示例数据的固定输入。
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
