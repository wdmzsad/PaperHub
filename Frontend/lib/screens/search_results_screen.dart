import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/post_model.dart';
import '../widgets/post_card.dart';
import 'post_detail_screen.dart';

/// 搜索结果页面
///
/// 显示帖子搜索结果，支持排序切换（热度/最新）和分页加载
class SearchResultsScreen extends StatefulWidget {
  final String query;
  final String searchType; // 'keyword', 'tag', 'author' - 目前只实现关键词搜索

  const SearchResultsScreen({
    Key? key,
    required this.query,
    this.searchType = 'keyword',
  }) : super(key: key);

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  final List<Post> _posts = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  final int _pageSize = 20;
  String _currentSort = 'hot'; // 'hot' 或 'new'

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  /// 加载帖子（支持分页）
  Future<void> _loadPosts({bool loadMore = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiService.searchPosts(
        query: widget.query,
        sort: _currentSort,
        page: loadMore ? _currentPage + 1 : 1,
        pageSize: _pageSize,
      );

      if (response['statusCode'] == 200) {
        final data = response['body'];
        final List<dynamic> postList = data['posts'] ?? [];
        final int total = data['total'] ?? 0;

        if (loadMore) {
          _currentPage++;
        } else {
          _posts.clear();
          _currentPage = 1;
        }

        // 转换数据为Post对象
        final List<Post> newPosts = postList.map((postData) {
          return Post.fromJson(postData);
        }).toList();

        setState(() {
          _posts.addAll(newPosts);
          _hasMore = _posts.length < total;
        });
      } else {
        // 处理错误
        _showErrorSnackBar('加载失败: ${response['body']['message']}');
      }
    } catch (e) {
      _showErrorSnackBar('网络错误: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 切换排序方式
  void _onSortChanged(String sort) {
    if (_currentSort == sort) return;

    setState(() {
      _currentSort = sort;
    });

    _loadPosts(loadMore: false);
  }

  /// 显示错误提示
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// 构建排序选择器
  Widget _buildSortSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          const Text(
            '排序方式:',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(width: 12),
          ChoiceChip(
            label: const Text('热度'),
            selected: _currentSort == 'hot',
            onSelected: (selected) {
              if (selected) _onSortChanged('hot');
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('最新'),
            selected: _currentSort == 'new',
            onSelected: (selected) {
              if (selected) _onSortChanged('new');
            },
          ),
        ],
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '未找到相关结果',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            '尝试使用其他关键词搜索',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  /// 构建加载更多指示器
  Widget _buildLoadMoreIndicator() {
    if (!_hasMore && _posts.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: const Center(
          child: Text(
            '没有更多内容了',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
      );
    }

    if (_isLoading && _posts.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Container();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('搜索: ${widget.query}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          // 排序选择器
          _buildSortSelector(),

          // 帖子列表
          Expanded(
            child: _posts.isEmpty && !_isLoading
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: () => _loadPosts(loadMore: false),
                    child: ListView.builder(
                      itemCount: _posts.length + 1, // +1 for load more indicator
                      itemBuilder: (context, index) {
                        if (index < _posts.length) {
                          final post = _posts[index];
                          return PostCard(
                            post: post,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PostDetailScreen(post: post),
                                ),
                              );
                            },
                          );
                        } else {
                          // 加载更多指示器
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!_isLoading && _hasMore) {
                              _loadPosts(loadMore: true);
                            }
                          });
                          return _buildLoadMoreIndicator();
                        }
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}