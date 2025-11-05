import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/search_model.dart';
import '../services/search_history_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  String _selectedSearchType = 'keyword';
  bool _isSearchTypeExpanded = false;
  List<SearchHistoryItem> _searchHistory = [];
  bool _isLoading = true;

  // 搜索方式选项
  final Map<String, String> _searchTypeOptions = {
    'keyword': '关键词',
    'tag': '标签', 
    'author': '作者',
  };

  // 搜索提示文本
  final Map<String, String> _searchHints = {
    'keyword': '搜索笔记、论文标题',
    'tag': '搜索领域标签',
    'author': '搜索作者名称',
  };

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
  }

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

  void _onSearchTypeChanged(String type) {
    setState(() {
      _selectedSearchType = type;
      _isSearchTypeExpanded = false;
    });
  }

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
    
    // 暂时显示提示，后续可以跳转到搜索结果页
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('搜索: $value (${_searchTypeOptions[_selectedSearchType]})'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onHistoryItemTap(SearchHistoryItem item) {
    setState(() {
      _searchController.text = item.keyword;
      _selectedSearchType = item.searchType;
    });
    _searchFocusNode.requestFocus();
  }

  void _onHotSearchTap(HotSearchItem item) {
    setState(() {
      _searchController.text = item.title;
      _selectedSearchType = item.searchType;
    });
    _searchFocusNode.requestFocus();
  }

  void _onClearHistory() async {
    await SearchHistoryService.clearSearchHistory();
    _loadSearchHistory();
  }

  void _onDeleteHistoryItem(String id) async {
    await SearchHistoryService.removeSearchHistory(id);
    _loadSearchHistory();
  }

  @override
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

  Widget _buildSearchTypeSelector() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: Colors.grey[200]!),
          ),
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_searchHistory.isNotEmpty)
                    TextButton(
                      onPressed: _onClearHistory,
                      child: const Text(
                        '清空历史',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
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
              ..._searchHistory.map((item) => _buildHistoryItem(item)).toList(),
          ],
        ),
      ),
    );
  }

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
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '热搜榜',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            // 热搜列表
            ...mockHotSearches.map((item) => _buildHotSearchItem(item)).toList(),
          ],
        ),
      ),
    );
  }

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
        style: const TextStyle(
          fontSize: 12,
          color: Colors.grey,
        ),
      ),
      onTap: () => _onHotSearchTap(item),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.search_off,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
}