/// PaperHub 首页（发现流 + 分区占位）
///
/// 职责与交互：
/// - 展示“发现”瀑布流内容，支持下拉加载更多（懒加载）。
/// - 顶部切换“发现/分区”，分区暂为占位内容。
/// - 右上角搜索入口 -> `SearchScreen`。
/// - 卡片点击 -> `PostDetailScreen`。
/// - 底部导航：消息页、发布弹窗、个人页的跳转与返回后高亮恢复。
///
/// 分页/加载策略：
/// - 初始加载前 6 条（模拟接口返回），后续每次追加 6 条。
/// - 当滚动至底部上方 200 像素时触发加载。
/// - `_isLoading` 防抖，`_hasMore` 控制是否还有数据。
///
/// 组件说明：
/// - 使用 `MasonryGridView` 构建瀑布流（2 列，间距 8）。
/// - 末尾附加一个“加载中/没有更多”指示项（通过 `itemCount` +1 实现）。
///
/// 约定与注意：
/// - `mockPosts` 为演示数据源，后续可替换为异步接口。
/// - `nextEnd = clamp(0, mockPosts.length)` 保证 sublist 不越界。
/// - 导航返回后，通过 `then` 回调恢复首页 tab 高亮（`_currentIndex = 0`）。
/// - 释放资源：在 `dispose` 中释放 `ScrollController`。
///
import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../widgets/post_card.dart';
import 'search_screen.dart';
import 'profile_screen.dart';
import 'message_screen.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'post_detail_screen.dart';
import '../widgets/bottom_navigation.dart';
import '../pages/note_editor_page.dart';
import '../services/api_service.dart';
import '../services/chat_service.dart';
import '../services/unread_service.dart';
import '../models/notification_model.dart';
import '../constants/discipline_constants.dart';

/// 首页入口组件（Stateful）：承载发现流与分区切换
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// 底部导航当前索引（0=首页，1=消息，2=发布，3=我的）。
  int _currentIndex = 0;

  /// 用于监听列表滚动，判断是否接近底部以触发加载更多。
  final ScrollController _scrollController = ScrollController();

  /// 加载中标记，用于防止并发重复加载。
  bool _isLoading = false;

  /// 是否还有更多数据（由当前已加载数量与数据源长度决定）。
  bool _hasMore = true; //  是否还有更多数据
  /// 已加载到页面上的帖子列表。
  final List<Post> _posts = [];
  
  /// 点赞操作防抖集合（防止重复请求）
  final Set<String> _likeInFlight = {};

  /// 顶部 tab 选择（0=发现，1=分区）。
  int _selectedTab = 0; //  0=发现, 1=分区
  final ChatService _chatService = ChatService();

  /// 分区页当前选中的主分区
  String _currentZoneDiscipline = kMainDisciplines.first;

  @override
  void initState() {
    super.initState();
    // 初始化加载首屏数据，并注册滚动监听。
    _loadInitialPosts();
    _scrollController.addListener(_scrollListener);
    _preloadUnreadBadges();
  }

  Future<void> _preloadUnreadBadges() async {
    // 预加载聊天未读
    _chatService.loadConversations();

    // 预加载通知未读
    try {
      final resp = await ApiService.getUnreadNotificationCount();
      if (resp['statusCode'] == 200) {
        final body = resp['body'] as Map<String, dynamic>;
        final count = UnreadCount.fromJson(body);
        UnreadService.instance.updateNotificationUnread(count);
      }
    } catch (_) {
      // 忽略网络异常
    }
  }

  /// 初始加载首屏内容
  Future<void> _loadInitialPosts() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final resp = await ApiService.getPosts(page: 1, pageSize: 6);
      final status = resp['statusCode'] as int? ?? 500;
      final body = resp['body'] as Map<String, dynamic>?;

      print('加载帖子响应: status=$status, body=$body'); // 调试日志

      if (status >= 200 && status < 300 && body != null) {
        final postsData = (body['posts'] as List<dynamic>?) ?? <dynamic>[];
        final total = body['total'] as int? ?? 0;

        print('获取到 ${postsData.length} 条帖子'); // 调试日志
        
        // 调试：打印第一条帖子的原始 JSON 数据（查看后端返回的字段）
        if (postsData.isNotEmpty) {
          print('=== 第一条帖子的原始 JSON 数据 ===');
          print(postsData[0]);
          print('================================');
        }

        final newPosts = postsData
            .map((p) => Post.fromJson(p as Map<String, dynamic>))
            .toList();

        // 调试：打印每个帖子的 imageAspectRatio
        print('=== 帖子 imageAspectRatio 调试信息 ===');
        for (var post in newPosts) {
          print('Post ID: ${post.id}');
          print('  - imageAspectRatio: ${post.imageAspectRatio}');
          print('  - imageNaturalWidth: ${post.imageNaturalWidth}');
          print('  - imageNaturalHeight: ${post.imageNaturalHeight}');
          print('  - media count: ${post.media.length}');
          if (post.media.isNotEmpty) {
            print('  - first media URL: ${post.media.first}');
          }
          print('  - 计算出的宽高比: ${post.imageNaturalWidth / post.imageNaturalHeight}');
          print('---');
        }
        print('=====================================');

        setState(() {
          _posts.clear();
          _posts.addAll(newPosts);
          _hasMore = _posts.length < total;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        // 显示更详细的错误信息
        final errorMsg = body != null && body['message'] != null
            ? '加载失败: ${body['message']}'
            : '加载失败: HTTP $status，请确保后端服务已启动 (http://localhost:8080)';
        print('加载帖子失败: $errorMsg'); // 调试日志

        // 如果后端失败，可以使用模拟数据作为降级方案（可选）
        // 取消下面的注释以启用降级方案
        /*
        if (_posts.isEmpty) {
          // 使用模拟数据作为降级方案
          final mockData = mockPosts.take(6).toList();
          setState(() {
            _posts.addAll(mockData);
            _hasMore = mockData.length < mockPosts.length;
            _isLoading = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('使用演示数据（后端连接失败）'),
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }
        */

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      setState(() {
        _isLoading = false;
      });
      print('加载帖子异常: $e'); // 调试日志
      print('堆栈跟踪: $stackTrace'); // 调试日志
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('网络错误: $e\n请确保后端服务已启动 (http://localhost:8080)'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// 刷新第一页（用于发布后获取最新内容）
  Future<void> _refreshFirstPage() async {
    try {
      final resp = await ApiService.getPosts(page: 1, pageSize: 6);
      final status = resp['statusCode'] as int? ?? 500;
      final body = resp['body'] as Map<String, dynamic>?;

      if (status >= 200 && status < 300 && body != null) {
        final postsData = (body['posts'] as List<dynamic>?) ?? <dynamic>[];
        final total = body['total'] as int? ?? 0;

        final newPosts = postsData
            .map((p) => Post.fromJson(p as Map<String, dynamic>))
            .toList();

        setState(() {
          // 插入新帖子到列表开头，但避免重复
          for (var newPost in newPosts) {
            if (!_posts.any((p) => p.id == newPost.id)) {
              _posts.insert(0, newPost);
            }
          }
          _hasMore = _posts.length < total;
        });
      }
    } catch (e) {
      // 忽略错误
    }
  }

  /// 触底后加载下一页（每次追加 6 条）
  Future<void> _loadMorePosts() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final currentPage = (_posts.length ~/ 6) + 1;
      final resp = await ApiService.getPosts(page: currentPage, pageSize: 6);
      final status = resp['statusCode'] as int? ?? 500;
      final body = resp['body'] as Map<String, dynamic>?;

      if (status >= 200 && status < 300 && body != null) {
        final postsData = (body['posts'] as List<dynamic>?) ?? <dynamic>[];
        final total = body['total'] as int? ?? 0;

        final newPosts = postsData
            .map((p) => Post.fromJson(p as Map<String, dynamic>))
            .toList();

        setState(() {
          _posts.addAll(newPosts);
          _hasMore = _posts.length < total;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 当滚动距离接近底部（距离最大可滚动距离 200 像素以内）时，触发分页加载。
  /// 可根据需求调整 200 的阈值，平衡提前加载与性能。
  void _scrollListener() {
    if (_scrollController.offset >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMorePosts();
    }
  }

  /// 卡片点击 -> 打开详情页
  void _onPostTap(Post post) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PostDetailScreen(post: post)),
    ).then((result) {
      if (result == true) {
        setState(() {
          _posts.removeWhere((p) => p.id == post.id);
        });
        return;
      }
      // 从详情页返回时，只更新当前帖子的点赞状态，不刷新整个列表
      final currentPostIndex = _posts.indexWhere((p) => p.id == post.id);
      if (currentPostIndex != -1) {
        // 重新获取单个帖子详情，同步点赞状态
        _syncPostLikeStatus(post.id);
      }
    });
  }

  /// 同步单个帖子的点赞状态（不影响其他帖子）
  Future<void> _syncPostLikeStatus(String postId) async {
    try {
      final resp = await ApiService.getPost(postId);
      if (resp['statusCode'] == 200) {
        final body = resp['body'] as Map<String, dynamic>;
        final updatedPost = Post.fromJson(body);
        final postIndex = _posts.indexWhere((p) => p.id == postId);
        if (postIndex != -1) {
          setState(() {
            _posts[postIndex].likesCount = updatedPost.likesCount;
            _posts[postIndex].isLiked = updatedPost.isLiked;
          });
        }
      }
    } catch (e) {
      // 忽略错误，不影响用户体验
    }
  }

  /// 顶部搜索图标点击 -> 打开搜索页
  void _onSearchTap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SearchScreen()),
    );
  }

  void _openUserProfile(String userId) {
    Navigator.of(context).pushNamed('/user/$userId');
  }

  /// 处理帖子点赞（乐观更新，不阻塞UI）
  Future<bool> _handlePostLike(Post post) async {
    // 防止重复请求
    if (_likeInFlight.contains(post.id)) {
      return false;
    }

    _likeInFlight.add(post.id);

    try {
      final resp = post.isLiked
          ? await ApiService.unlikePost(post.id)
          : await ApiService.likePost(post.id);

      if (resp['statusCode'] == 200) {
        final body = resp['body'] as Map<String, dynamic>?;
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
                  : _buildZoneTabContent(), // 分区页
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

  /// 瀑布流内容区
  /// - `itemCount` 在加载中时额外 +1 用作显示底部加载指示器。
  /// - 使用 `MasonryGridView.count` 创建 2 列错落网格。
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
          onAuthorTap: () => _openUserProfile(_posts[index].author.id),
          onLikeTap: _handlePostLike,
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

  /// 首屏加载过程中的占位视图
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

  /// 分区首页内容：顶部分区滑条 + 当前分区的瀑布流
  Widget _buildZoneTabContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildZoneSelectorBar(),
        const Divider(height: 1),
        Expanded(
          child: _buildZoneWaterfallGrid(),
        ),
      ],
    );
  }

  /// 顶部分区滑条
  Widget _buildZoneSelectorBar() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemBuilder: (context, index) {
          final discipline = kMainDisciplines[index];
          final selected = discipline == _currentZoneDiscipline;
          final color = kDisciplineColors[discipline] ?? Colors.blue;
          return GestureDetector(
            onTap: () {
              if (_currentZoneDiscipline == discipline) return;
              setState(() {
                _currentZoneDiscipline = discipline;
              });
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? color.withOpacity(0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected ? color : Colors.grey.shade300,
                ),
              ),
              child: Center(
                child: Text(
                  discipline,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected ? color : Colors.black87,
                  ),
                ),
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: kMainDisciplines.length,
      ),
    );
  }

  /// 分区内瀑布流（当前实现复用首页加载的帖子，前端按主分区标签过滤）
  Widget _buildZoneWaterfallGrid() {
    if (_posts.isEmpty) {
      // 复用首页的加载视图
      return _buildInitialLoading();
    }
    final filtered = _posts
        .where(
          (p) => p.tags.contains(_currentZoneDiscipline),
        )
        .toList();

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            '当前分区暂时没有内容，试试切换到其他分区或先在该分区发布一条笔记吧～',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

    return MasonryGridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final post = filtered[index];
        return PostCard(
          post: post,
          onTap: () => _onPostTap(post),
          onAuthorTap: () => _openUserProfile(post.author.id),
          onLikeTap: _handlePostLike,
        );
      },
    );
  }

  /// 底部自定义导航：
  /// - index=1 -> 打开消息页（返回后重置高亮到首页）。
  /// - index=2 -> 打开发布弹窗（占位功能）。
  /// - index=3 -> 打开个人页（返回后重置高亮到首页）。
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
          Navigator.of(context)
              .push(
                MaterialPageRoute(builder: (context) => const NoteEditorPage()),
              )
              .then((_) {
                setState(() {
                  _currentIndex = 0;
                });
                // 发布后刷新列表（重新加载第一页）
                final firstPagePosts = _posts.take(6).length;
                if (firstPagePosts < 6 || _posts.isEmpty) {
                  // 如果当前列表为空或少于6条，重新加载
                  _posts.clear();
                  _hasMore = true;
                  _loadInitialPosts();
                } else {
                  // 否则只重新加载第一页来获取最新发布的帖子
                  _refreshFirstPage();
                }
              });
        } else if (index == 3) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ProfilePage(isMainPage: true)),
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

  @override
  void dispose() {
    // 释放滚动控制器，避免内存泄漏。
    _scrollController.dispose();
    super.dispose();
  }
}
