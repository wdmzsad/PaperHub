import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../services/api_service.dart';
import '../models/post_model.dart';
import '../models/user_summary.dart';
import '../widgets/post_card.dart';
import 'post_detail_screen.dart';
import 'profile_screen.dart';

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
  final List<UserSummary> _users = []; // 用户搜索结果（仅当 searchType == 'author'）
  bool _isLoading = false;
  bool _isLoadingUsers = false;
  bool _hasMore = true;
  bool _hasMoreUsers = true;
  int _currentPage = 1;
  int _userPage = 0;
  final int _pageSize = 20;
  final int _userPageSize = 10; // 每次加载用户的数量
  String _currentSort = 'hot'; // 'hot' 或 'new'
  bool _showAllUsers = false; // 是否展开显示所有用户
  final Set<String> _likeInFlight = {}; // 防止重复点赞请求
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// 滚动监听：当接近底部时加载更多
  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _loadPosts(loadMore: true);
    }
  }

  /// 加载搜索结果（根据搜索类型分发）
  Future<void> _loadPosts({bool loadMore = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.searchType == 'author') {
        await _loadAuthorSearch(loadMore: loadMore);
      } else {
        await _loadKeywordSearch(loadMore: loadMore);
      }
    } catch (e) {
      _showErrorSnackBar('网络错误: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 加载关键词/标签搜索
  Future<void> _loadKeywordSearch({bool loadMore = false}) async {
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

      final List<Post> newPosts = postList.map((postData) {
        return Post.fromJson(postData);
      }).toList();

      setState(() {
        _posts.addAll(newPosts);
        _hasMore = _posts.length < total;
      });
    } else {
      _showErrorSnackBar('加载失败: ${response['body']['message']}');
    }
  }

  /// 加载作者搜索
  Future<void> _loadAuthorSearch({bool loadMore = false}) async {
    // 如果是加载更多，且没有更多用户了，则直接返回
    if (loadMore && !_hasMoreUsers) return;

    // 1. 加载用户
    if (!loadMore) {
      // 重置状态
      _users.clear();
      _posts.clear();
      _userPage = 0;
      _hasMoreUsers = true;
      _showAllUsers = false;
    }

    setState(() {
      _isLoadingUsers = true;
    });

    try {
      // 搜索用户
      final userResponse = await ApiService.searchUsers(
        query: widget.query,
        type: 'all',
        page: _userPage,
        pageSize: _userPageSize,
      );

      if (userResponse['statusCode'] == 200) {
        final userData = userResponse['body'];
        final List<dynamic> userList = userData['users'] ?? [];
        final int userTotal = userData['total'] ?? 0;

        final List<UserSummary> newUsers = userList.map((userData) {
          return UserSummary.fromJson(userData);
        }).toList();

        setState(() {
          _users.addAll(newUsers);
          _hasMoreUsers = _users.length < userTotal;
          _userPage++;
        });

      } else {
        _showErrorSnackBar('用户搜索失败: ${userResponse['body']['message']}');
      }
    } catch (e) {
      _showErrorSnackBar('用户搜索错误: $e');
    } finally {
      setState(() {
        _isLoadingUsers = false;
      });
    }
  }


  /// 打开用户主页
  void _openUserProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfilePage(userId: userId),
      ),
    );
  }

  /// 处理帖子点赞（与首页保持一致）
  Future<bool> _handlePostLike(Post post) async {
    // 防止重复请求
    if (_likeInFlight.contains(post.id)) {
      return false;
    }

    _likeInFlight.add(post.id);

    try {
      final response = post.isLiked
          ? await ApiService.unlikePost(post.id)
          : await ApiService.likePost(post.id);

      if (response['statusCode'] == 200) {
        final body = response['body'] as Map<String, dynamic>?;
        final updatedLikesCount = (body?['likesCount'] as num?)?.toInt();
        final updatedIsLiked = body?['isLiked'] as bool?;

        // 更新帖子状态（只更新单个帖子，不刷新整个列表）
        final postIndex = _posts.indexWhere((p) => p.id == post.id);
        if (postIndex != -1) {
          setState(() {
            _posts[postIndex].likesCount =
                updatedLikesCount ?? _posts[postIndex].likesCount;
            _posts[postIndex].isLiked =
                updatedIsLiked ?? !_posts[postIndex].isLiked;
          });
        }

        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('点赞失败: $e');
      return false;
    } finally {
      _likeInFlight.remove(post.id);
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

  /// 构建用户搜索结果区域（仅当搜索类型为'author'时显示）
  Widget _buildUserSection() {
    if (widget.searchType != 'author' || _users.isEmpty) {
      return Container();
    }

    // 决定显示多少用户
    final usersToShow = _showAllUsers ? _users : _users.take(5).toList();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          const Text(
            '相关用户',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // 用户列表
          ...usersToShow.map((user) => _buildUserItem(user)).toList(),

          // 查看更多/收起按钮
          if (_users.length > 5)
            Container(
              alignment: Alignment.center,
              margin: const EdgeInsets.only(top: 8),
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _showAllUsers = !_showAllUsers;
                  });
                },
                child: Text(
                  _showAllUsers ? '收起用户列表' : '查看更多用户 (${_users.length})',
                  style: const TextStyle(color: Colors.blue),
                ),
              ),
            ),

        ],
      ),
    );
  }

  /// 构建单个用户项
  Widget _buildUserItem(UserSummary user) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      leading: CircleAvatar(
        backgroundImage: NetworkImage(user.avatar),
        radius: 20,
      ),
      title: Text(
        user.displayName,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: user.bio != null && user.bio!.isNotEmpty
          ? Text(
              user.bio!,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (user.isFollowing == true)
            const Text(
              '已关注',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: Colors.grey, size: 16),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfilePage(userId: user.id),
          ),
        );
      },
    );
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    final String message;
    if (widget.searchType == 'author') {
      message = '未找到相关用户';
    } else {
      message = '未找到相关结果';
    }

    final String hint;
    if (widget.searchType == 'author') {
      hint = '尝试使用其他名称搜索';
    } else if (widget.searchType == 'tag') {
      hint = '尝试使用其他标签搜索';
    } else {
      hint = '尝试使用其他关键词搜索';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            hint,
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  /// 构建加载更多指示器
  Widget _buildLoadMoreIndicator() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    } else if (!_hasMore) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('没有更多内容了', style: TextStyle(color: Colors.grey)),
        ),
      );
    } else {
      return const SizedBox();
    }
  }

  /// 构建作者搜索的页面主体（只显示用户列表）
  Widget _buildAuthorSearchBody() {
    return Column(
      children: [
        // 用户搜索结果区域
        Expanded(
          child: _users.isEmpty && !_isLoadingUsers
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: () => _loadAuthorSearch(loadMore: false),
                  child: ListView(
                    children: [
                      _buildUserSection(),
                      // 加载更多指示器
                      if (_isLoadingUsers)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      // 加载更多按钮
                      if (_hasMoreUsers && !_isLoadingUsers)
                        Container(
                          alignment: Alignment.center,
                          margin: const EdgeInsets.all(16.0),
                          child: TextButton(
                            onPressed: () => _loadAuthorSearch(loadMore: true),
                            child: const Text(
                              '加载更多用户',
                              style: TextStyle(color: Colors.blue),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  /// 构建帖子搜索的页面主体（显示排序器和帖子网格）
  Widget _buildPostSearchBody() {
    return Column(
      children: [
        // 排序选择器
        _buildSortSelector(),
        // 帖子列表
        Expanded(
          child: _posts.isEmpty && !_isLoading
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: () => _loadPosts(loadMore: false),
                  child: MasonryGridView.count(
                    controller: _scrollController,
                    crossAxisCount: 2,
                    crossAxisSpacing: 3,
                    mainAxisSpacing: 3,
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                    itemCount: _posts.length + (_isLoading ? 1 : 0),
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
                          onAuthorTap: () => _openUserProfile(post.author.id),
                          onLikeTap: (post) => _handlePostLike(post),
                        );
                      } else {
                        return _buildLoadMoreIndicator();
                      }
                    },
                  ),
                ),
        ),
      ],
    );
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
      body: widget.searchType == 'author'
          ? _buildAuthorSearchBody()
          : _buildPostSearchBody(),
    );
  }
}