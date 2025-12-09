/// PaperHub 搜索页
///
/// 职责与交互：
/// - 提供统一的搜索入口（关键词/标签/作者），并记录搜索历史。
/// - 展示热搜榜，支持一键带入搜索框。
/// - 管理搜索方式切换（`keyword` | `tag` | `author`）。
/// - 通过 `SearchHistoryService` 持久化搜索历史（底层可基于 SharedPreferences）。
///
/// 设计契约（Contract）：
/// - `_selectedSearchType` 的取值必须在 `_searchTypeOptions` 的 key 集合中。
/// - 搜索提交时会去除首尾空白；若为空则不提交。
/// - 历史记录项包括：id（唯一）、keyword、searchType、timestamp（毫秒）。
/// - UI 仅做演示：提交后 Toast 提示；后续可跳转搜索结果页。
///
/// 性能与体验：
/// - 首次进入加载历史（带 `_isLoading` 占位）。
/// - 热搜与历史均为轻量列表，使用 `SliverToBoxAdapter` 组成滚动区域。
///
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/search_model.dart';
import '../services/search_history_service.dart';
import '../services/api_service.dart';
import 'search_results_screen.dart';

/// 搜索页面（Stateful）
class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  /// 搜索输入框控制器
  final TextEditingController _searchController = TextEditingController();
  /// 控制焦点，用于历史/热搜回填后聚焦输入框
  final FocusNode _searchFocusNode = FocusNode();

  /// 当前选中的搜索方式：'keyword' | 'tag' | 'author'
  String _selectedSearchType = 'keyword';
  /// 搜索方式选择器展开状态（用于控制箭头图标）
  bool _isSearchTypeExpanded = false;
  /// 搜索历史列表（按时间倒序，最新在前，由服务层返回）
  List<SearchHistoryItem> _searchHistory = [];
  /// 历史加载中的占位状态
  bool _isLoading = true;
  /// 历史记录展开状态（false：折叠显示最近5条；true：展开显示全部）
  bool _isHistoryExpanded = false;
  /// 热搜榜单列表
  List<HotSearchItem> _hotSearches = [];
  /// 热搜加载中的占位状态
  bool _isLoadingHotSearches = true;
  /// 热搜加载错误信息
  String? _hotSearchesError;

  // 搜索方式选项
  /// key 为内部值，value 为展示文案；用于渲染选择器与提示语映射。
  /// 合法 key：'keyword' | 'tag' | 'author'。
  final Map<String, String> _searchTypeOptions = {
    'keyword': '关键词',
    'tag': '标签',
    'author': '作者',
  };

  // 搜索提示文本
  /// 与 `_searchTypeOptions` 的 key 对应的占位提示文案。
  /// 若新增搜索方式，请同步补充此映射。
  final Map<String, String> _searchHints = {
    'keyword': '搜索笔记、论文标题',
    'tag': '搜索领域标签',
    'author': '搜索作者名称',
  };

  @override
  void initState() {
    super.initState();
    // 进入页面后加载本地搜索历史。
    _loadSearchHistory();
    // 加载热搜榜单
    _loadHotSearches();
  }

  /// 加载本地搜索历史
  /// - 设置 `_isLoading` 为 true 以展示加载占位
  /// - 调用 `SearchHistoryService.getSearchHistory()` 获取历史
  /// - 结束后恢复 `_isLoading=false` 并渲染历史列表
  Future<void> _loadSearchHistory() async {
    setState(() {
      _isLoading = true;
    });

    final history = await SearchHistoryService.getSearchHistory();

    setState(() {
      _searchHistory = history;
      _isLoading = false;
    });
  }

  /// 加载热搜榜单
  /// - 设置 `_isLoadingHotSearches` 为 true 以展示加载占位
  /// - 调用 `ApiService.getHotSearches()` 获取热搜
  /// - 成功后更新热搜列表，失败时显示错误信息
  Future<void> _loadHotSearches() async {
    setState(() {
      _isLoadingHotSearches = true;
      _hotSearchesError = null; // 清除之前的错误
    });

    try {
      final response = await ApiService.getHotSearches(limit: 20);
      if (response['statusCode'] == 200) {
        final data = response['body'];
        final List<dynamic> items = data['items'] ?? [];

        // 转换为 HotSearchItem 列表
        List<HotSearchItem> hotSearches = items.map((item) {
          return HotSearchItem(
            rank: item['rank'] as int,
            title: item['keyword'] as String,
            tag: item['tag'] as String?,
            heat: (item['heat'] as num).toDouble(),
            searchType: item['searchType'] as String,
          );
        }).toList();

        setState(() {
          _hotSearches = hotSearches;
          _isLoadingHotSearches = false;
        });
      } else {
        // API请求失败，显示错误信息
        final errorMessage = response['body']?['message'] ?? '加载热搜失败';
        setState(() {
          _hotSearches = [];
          _isLoadingHotSearches = false;
          _hotSearchesError = errorMessage;
        });
      }
    } catch (e) {
      // 网络错误或其他异常
      setState(() {
        _hotSearches = [];
        _isLoadingHotSearches = false;
        _hotSearchesError = '网络连接失败，请检查网络后重试';
      });
    }
  }

  /// 修改搜索方式（单选）
  /// - 收起展开面板
  /// - 同步 `_selectedSearchType`，影响搜索框提示文案
  void _onSearchTypeChanged(String type) {
    setState(() {
      _selectedSearchType = type;
      _isSearchTypeExpanded = false;
    });
  }

  /// 提交搜索
  /// 合约：
  /// - 若输入为空（去除首尾空白）则忽略。
  /// - 构造 `SearchHistoryItem` 并调用服务层写入，再刷新历史列表。
  /// - 跳转到搜索结果页面。
  void _onSearchSubmitted(String value) {
    if (value.trim().isEmpty) return;

    // 添加到搜索历史
    final newHistory = SearchHistoryItem(
      id: SearchHistoryService.generateId(),
      keyword: value.trim(),
      searchType: _selectedSearchType,
      timestamp: DateTime.now(),
    );

    SearchHistoryService.addSearchHistory(newHistory).then((_) {
      _loadSearchHistory(); // 重新加载历史记录
    });

    // 跳转到搜索结果页面
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchResultsScreen(
          query: value.trim(),
          searchType: _selectedSearchType,
        ),
      ),
    );
  }

  /// 点击历史记录项：
  /// - 将其 keyword 与 searchType 回填到输入框与当前搜索类型
  /// - 主动请求输入框获取焦点，便于用户直接编辑/提交
  /// - 保存到搜索历史（作为一次新的搜索）
  /// - 直接跳转到搜索结果页面
  void _onHistoryItemTap(SearchHistoryItem item) {
    final trimmedKeyword = item.keyword.trim();
    if (trimmedKeyword.isEmpty) return; // 如果关键词为空，不处理

    setState(() {
      _searchController.text = trimmedKeyword;
      _selectedSearchType = item.searchType;
    });
    _searchFocusNode.requestFocus();

    // 添加到搜索历史（作为一次新的搜索，服务层会处理去重和计数更新）
    final newHistory = SearchHistoryItem(
      id: SearchHistoryService.generateId(),
      keyword: trimmedKeyword,
      searchType: item.searchType,
      timestamp: DateTime.now(),
    );

    SearchHistoryService.addSearchHistory(newHistory).then((_) {
      _loadSearchHistory(); // 重新加载历史记录
    });

    // 直接跳转到搜索结果页面
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchResultsScreen(
          query: trimmedKeyword,
          searchType: item.searchType,
        ),
      ),
    );
  }

  /// 点击热搜项：
  /// - 回填标题到输入框（不改变当前搜索类型）
  /// - 保存到搜索历史（使用当前搜索类型）
  /// - 直接跳转到搜索结果页面（使用当前搜索类型）
  void _onHotSearchTap(HotSearchItem item) {
    final trimmedKeyword = item.title.trim();
    if (trimmedKeyword.isEmpty) return; // 如果关键词为空，不处理

    setState(() {
      _searchController.text = trimmedKeyword;
      // 不设置_selectedSearchType，保持用户当前选择的搜索类型
    });
    _searchFocusNode.requestFocus();

    // 添加到搜索历史（使用当前搜索类型，而不是热搜条目记录的搜索类型）
    final newHistory = SearchHistoryItem(
      id: SearchHistoryService.generateId(),
      keyword: trimmedKeyword,
      searchType: _selectedSearchType, // 使用当前搜索类型
      timestamp: DateTime.now(),
    );

    SearchHistoryService.addSearchHistory(newHistory).then((_) {
      _loadSearchHistory(); // 重新加载历史记录
    });

    // 直接跳转到搜索结果页面（使用当前搜索类型）
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchResultsScreen(
          query: trimmedKeyword,
          searchType: _selectedSearchType, // 使用当前搜索类型
        ),
      ),
    );
  }

  /// 清空全部历史记录
  void _onClearHistory() async {
    await SearchHistoryService.clearSearchHistory();
    _loadSearchHistory();
  }

  /// 删除单条历史记录
  void _onDeleteHistoryItem(String id) async {
    await SearchHistoryService.removeSearchHistory(id);
    _loadSearchHistory();
  }

  @override
  /// 页面骨架：
  /// - 顶部搜索栏（返回、输入框、搜索按钮）
  /// - 内容区为 `CustomScrollView`，依次包含：
  ///   1) 搜索方式选择器（ExpansionTile）
  ///   2) 历史记录区（加载中/空/列表）
  ///   3) 热搜榜区（列表）
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // 顶部搜索栏
            _buildSearchHeader(),

            // 内容区域
            Expanded(
              child: CustomScrollView(
                slivers: [
                  // 搜索方式选择器
                  _buildSearchTypeSelector(),

                  // 历史记录区域
                  _buildHistorySection(),

                  // 热搜榜区域
                  _buildHotSearchSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 顶部搜索栏：
  /// - 返回按钮：`Navigator.pop`
  /// - 输入框：根据 `_selectedSearchType` 切换 hint；右侧清空/搜索图标动态切换
  /// - “搜索”按钮：仅在输入非空时显示
  Widget _buildSearchHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 返回按钮
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),

          // 搜索输入框
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText: _searchHints[_selectedSearchType],
                  hintStyle: const TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : const Icon(Icons.search, color: Colors.grey, size: 20),
                ),
                onChanged: (value) => setState(() {}),
                onSubmitted: _onSearchSubmitted,
              ),
            ),
          ),

          // 搜索按钮
          if (_searchController.text.isNotEmpty)
            TextButton(
              onPressed: () => _onSearchSubmitted(_searchController.text),
              child: const Text('搜索'),
            ),
        ],
      ),
    );
  }

  /// 搜索方式选择器（Sliver）：
  /// - 使用 `ExpansionTile` 展示三个选项（单选 Radio）
  /// - 展开状态同步到 `_isSearchTypeExpanded`，以控制箭头图标
  Widget _buildSearchTypeSelector() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '搜索方式',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ExpansionTile(
                title: Text(_searchTypeOptions[_selectedSearchType]!),
                trailing: Icon(
                  _isSearchTypeExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.grey,
                ),
                initiallyExpanded: false,
                onExpansionChanged: (expanded) {
                  setState(() {
                    _isSearchTypeExpanded = expanded;
                  });
                },
                children: _searchTypeOptions.entries.map((entry) {
                  return ListTile(
                    title: Text(entry.value),
                    leading: Radio<String>(
                      value: entry.key,
                      groupValue: _selectedSearchType,
                      onChanged: (value) => _onSearchTypeChanged(value!),
                    ),
                    onTap: () => _onSearchTypeChanged(entry.key),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 搜索历史区域（Sliver）：
  /// - 加载中：圆形进度条
  /// - 空状态：文案占位
  /// - 否则：列表项 + “清空历史”按钮
  Widget _buildHistorySection() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.only(top: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题栏
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '搜索历史',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  // 清空历史按钮
                  if (_searchHistory.isNotEmpty)
                    TextButton(
                      onPressed: _onClearHistory,
                      child: const Text(
                        '清空历史',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ),
                ],
              ),
            ),

            // 历史记录列表
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_searchHistory.isEmpty)
              _buildEmptyState('暂无搜索历史')
            else
              Column(
                children: [
                  ..._buildHistoryItemList(),
                  if (_searchHistory.length > 5)
                    // 展开/收起按钮
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _isHistoryExpanded = !_isHistoryExpanded;
                            });
                          },
                          child: Text(
                            _isHistoryExpanded ? '收起' : '展开',
                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// 构建历史记录项列表（根据展开状态决定显示数量）
  List<Widget> _buildHistoryItemList() {
    final displayCount = _isHistoryExpanded || _searchHistory.length <= 5
        ? _searchHistory.length
        : 5;
    return _searchHistory
        .take(displayCount)
        .map((item) => _buildHistoryItem(item))
        .toList();
  }

  /// 单条历史记录项
  /// - 左侧历史图标；标题为关键词；副标题为搜索方式文案
  /// - 右侧删除按钮（单条删除）
  Widget _buildHistoryItem(SearchHistoryItem item) {
    return ListTile(
      leading: const Icon(Icons.history, color: Colors.grey, size: 20),
      title: Text(item.keyword),
      subtitle: Text(
        '搜索方式: ${_searchTypeOptions[item.searchType]}',
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.close, size: 18, color: Colors.grey),
        onPressed: () => _onDeleteHistoryItem(item.id),
      ),
      onTap: () => _onHistoryItemTap(item),
    );
  }

  /// 热搜榜区域（Sliver）：
  /// - 从后端API获取实时热搜数据，失败时显示错误信息并提供重试
  /// - 每项展示：排名、标题、标签徽标（新/热）、热度文案
  Widget _buildHotSearchSection() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.only(top: 16, bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题栏
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '热搜榜',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  // 刷新按钮（非加载状态时显示）
                  if (!_isLoadingHotSearches && _hotSearchesError == null)
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      onPressed: _loadHotSearches,
                      tooltip: '刷新热搜榜',
                    ),
                ],
              ),
            ),

            // 加载状态
            if (_isLoadingHotSearches)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            // 错误状态
            else if (_hotSearchesError != null)
              _buildErrorState(_hotSearchesError!)
            // 空状态（无错误但数据为空）
            else if (_hotSearches.isEmpty)
              _buildEmptyState('暂无热搜数据')
            // 热搜列表
            else
              ..._hotSearches
                  .map((item) => _buildHotSearchItem(item))
                  .toList(),
          ],
        ),
      ),
    );
  }

  /// 单条热搜项
  /// - 前三名使用红色强化排名
  /// - 若存在 tag：渲染带边框的小徽标（新/热）
  /// - 右侧展示 `formattedHeat`（热度格式化文案）
  Widget _buildHotSearchItem(HotSearchItem item) {
    Color rankColor = Colors.grey;
    if (item.rank <= 3) {
      rankColor = const Color(0xFFFF2D55); // 前3名用红色
    }

    return ListTile(
      leading: Container(
        width: 24,
        alignment: Alignment.center,
        child: Text(
          item.rank.toString(),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: rankColor,
          ),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              item.title,
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (item.tag != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: item.tag == '热' ? Colors.red[50] : Colors.orange[50],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: item.tag == '热' ? Colors.red : Colors.orange,
                  width: 0.5,
                ),
              ),
              child: Text(
                item.tag!,
                style: TextStyle(
                  fontSize: 10,
                  color: item.tag == '热' ? Colors.red : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      trailing: Text(
        item.formattedHeat,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      onTap: () => _onHotSearchTap(item),
    );
  }

  /// 空状态占位
  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }

  /// 错误状态占位
  Widget _buildErrorState(String errorMessage) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.orange[400]),
          const SizedBox(height: 16),
          Text(
            errorMessage,
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadHotSearches,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('重新加载'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[50],
              foregroundColor: Colors.blue[700],
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  @override
  /// 释放输入与焦点资源，避免内存泄漏
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
}
