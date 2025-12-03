import 'package:flutter/material.dart';

/// 学科分区常量与推荐标签
///
/// 用途：
/// - 发布笔记时进行分区选择（必选）
/// - 显示帖子分区标签
/// - 分区首页顶部滑条 & 过滤逻辑

/// 13 个主分区（显示名称）
const List<String> kMainDisciplines = [
  '理学',
  '工学',
  '信息科学（CS）',
  '生命科学',
  '医学与健康',
  '经管',
  '社会科学',
  '人文与艺术',
  '教育学',
  '跨学科',
  '科研方法与工具',
  '学术生活',
  '公告区',
];

/// 每个主分区对应的主色（用于标签 / 滑条高亮等）
final Map<String, Color> kDisciplineColors = {
  '理学': const Color(0xFF1976D2),
  '工学': const Color(0xFF388E3C),
  '信息科学（CS）': const Color(0xFF512DA8),
  '生命科学': const Color(0xFF00897B),
  '医学与健康': const Color(0xFFD32F2F),
  '经管': const Color(0xFFF57C00),
  '社会科学': const Color(0xFF5D4037),
  '人文与艺术': const Color(0xFF8E24AA),
  '教育学': const Color(0xFF0097A7),
  '跨学科': const Color(0xFF7B1FA2),
  '科研方法与工具': const Color(0xFF455A64),
  '学术生活': const Color(0xFF689F38),
  '公告区': const Color(0xFF616161),
};

/// 系统推荐的细分类标签（可选），可按主分区分组，也可以在 UI 中统一展示一部分
final Map<String, List<String>> kRecommendedSubTags = {
  '信息科学（CS）': [
    'NLP',
    'CV',
    '机器学习',
    '深度学习',
    '数据挖掘',
    '推荐系统',
  ],
  '生命科学': [
    '生信分析',
    '组学分析',
    '单细胞',
    '结构生物学',
  ],
  '经管': [
    '数据分析',
    '量化研究',
    '实证研究',
  ],
  '科研方法与工具': [
    '数据分析',
    '统计建模',
    '可视化',
    '实验设计',
    '科研写作',
    'LaTeX',
  ],
  '学术生活': [
    '读书笔记',
    '科研心得',
    '会议记录',
  ],
};

/// 从一个帖子标签列表中，找到它所属的主分区（若有），否则返回 null
String? findMainDisciplineFromTags(List<String> tags) {
  for (final tag in tags) {
    if (kMainDisciplines.contains(tag)) return tag;
  }
  return null;
}


