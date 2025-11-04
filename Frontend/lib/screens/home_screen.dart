import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../widgets/post_card.dart';
import 'search_screen.dart';
import 'profile_screen.dart';
import 'message_screen.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'post_detail_screen.dart';
import '../widgets/bottom_navigation.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _hasMore = true; //  是否还有更多数据
  final List<Post> _posts = [];

  int _selectedTab = 0; //  0=发现, 1=分区

  @override
  void initState() {
    super.initState();
    _loadInitialPosts();
    _scrollController.addListener(_scrollListener);
  }

void _loadInitialPosts() {
    // 初始加载前 6 个
    final int initialCount = mockPosts.length >= 6 ? 6 : mockPosts.length;
    setState(() {
      _posts.addAll(mockPosts.take(initialCount));
      _hasMore = _posts.length < mockPosts.length;
    });
  }

  void _loadMorePosts() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    await Future.delayed(const Duration(seconds: 2));

    // 计算下一批加载数量（每次加载 6 个）
    final int nextStart = _posts.length;
    final int nextEnd = (nextStart + 6).clamp(0, mockPosts.length);

    setState(() {
      _posts.addAll(mockPosts.sublist(nextStart, nextEnd));
      _isLoading = false;
      _hasMore = _posts.length < mockPosts.length;
    });
  }


  void _scrollListener() {
    if (_scrollController.offset >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMorePosts();
    }
  }

  void _onPostTap(Post post) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PostDetailScreen(post: post)),
    );
  }


  void _onSearchTap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SearchScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // 顶部导航栏
            _buildTopBar(),

            // 内容区域
            Expanded(
              child: _selectedTab == 0
                  ? (_posts.isEmpty
                        ? _buildInitialLoading()
                        : _buildWaterfallGrid())
                  : _buildZonePlaceholder(), // 分区占位
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  // 顶部栏
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 中间按钮组
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTabButton("发现", 0),
                const SizedBox(width: 24),
                _buildTabButton("分区", 1),
              ],
            ),
          ),

          // 搜索图标
          InkWell(
            onTap: _onSearchTap,
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.all(6.0),
              child: Icon(Icons.search, color: Colors.grey, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  //  顶部“发现 / 分区”按钮样式
  Widget _buildTabButton(String label, int index) {
    final bool selected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
      },
      child: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          color: selected ? Colors.black : Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildWaterfallGrid() {
    return MasonryGridView.count(
      controller: _scrollController,
      crossAxisCount: 2,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      itemCount: _posts.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _posts.length) {
          return _buildLoadMoreIndicator();
        }
        return PostCard(
          post: _posts[index],
          onTap: () => _onPostTap(_posts[index]),
        );
      },
    );
  }

  // 根据是否还有更多，显示“加载中”或“没有更多内容了”
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

  Widget _buildInitialLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('加载中...', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  //  分区占位内容
  Widget _buildZonePlaceholder() {
    return const Center(
      child: Text('分区内容开发中...', style: TextStyle(color: Colors.grey)),
    );
  }

  Widget _buildBottomNavigationBar() {
      return BottomNavigation(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
            if (index == 1) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MessageScreen()),
          ).then((_) {
            // 当从消息页面返回时，恢复首页高亮
            setState(() {
              _currentIndex = 0;
            });
          });
        } else if (index == 2) {
          _showPublishDialog();
        } else if (index == 3) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ProfilePage()),
          ).then((_) {
            // 当从个人页面返回时，恢复首页高亮
            setState(() {
              _currentIndex = 0;
            });
          });
        }
      },
      context: context,
    );
  }



  void _showPublishDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('发布笔记'),
        content: const Text('发布功能开发中...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
