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
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
import '../services/notification_websocket_service.dart';
import '../models/notification_model.dart';
import '../services/local_storage.dart';
import '../services/browse_history_service.dart';
import '../constants/discipline_constants.dart';
import '../models/user_profile.dart';
import '../constants/app_colors.dart';
import '../utils/font_utils.dart';

/// 首页入口组件（Stateful）：承载发现流与分区切换
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    Key? key,
    this.themeModeNotifier,
    this.onThemeModeChanged,
    this.onThemeToggle,
  }) : super(key: key);

  final ValueNotifier<ThemeMode>? themeModeNotifier;
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  final VoidCallback? onThemeToggle;

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
  /// 0=关注, 1=发现, 2=分区
  int _selectedTab = 1;
  final ChatService _chatService = ChatService();

  /// 分区页当前选中的主分区
  String _currentZoneDiscipline = kMainDisciplines.first;

  /// 分区页帖子列表（独立于发现页）
  final List<Post> _zonePosts = [];

  /// 分区页加载状态
  bool _zoneLoading = false;

  /// 分区页是否还有更多数据
  bool _zoneHasMore = true;

  /// 分区页当前页码
  int _zonePage = 1;

  /// 关注页帖子列表与加载状态
  final List<Post> _followingPosts = [];
  bool _followingLoading = false;
  bool _followingHasMore = true;
  int _followingPage = 1;
  bool _followingHasNew = false;
  /// 最近一次“已在关注页看过”的顶部帖子 ID（用于跨页面防止红点反复出现）
  String? _lastFollowingTopPostIdSeen;
  final ScrollController _followingScrollController = ScrollController();

  /// 已浏览过的帖子ID集合（用于在关注流中标记未读红点）
  final Set<String> _viewedPostIds = {};

  /// 当前用户刚发布的帖子（优先展示在发现页顶部，直到刷新/离开）
  Post? _pinnedSelfPost;

  /// 是否对发现流使用“热度排序”（用户画像不足或推荐分过低时启用）
  bool _useHotRanking = false;

  UserProfile? _currentUserProfile;

  @override
  void initState() {
    super.initState();
    // 初始化加载首屏数据，并注册滚动监听。
    _loadInitialPosts();
    _scrollController.addListener(_scrollListener);
    _followingScrollController.addListener(_followingScrollListener);
    _preloadUnreadBadges();
    _loadViewedPostIds();
    _evaluateUserSignals();
    _loadLastFollowingSeenFromStorage();
    // 初始进入首页也要检查关注流，便于及时展示红点
    _refreshFollowingFeed();

    // 检查WebSocket连接状态
    _checkWebSocketConnection();
  }

  /// 检查WebSocket连接状态
  Future<void> _checkWebSocketConnection() async {
    try {
      // 延迟执行，确保其他初始化完成
      await Future.delayed(const Duration(seconds: 2));
      await NotificationWebSocketService.instance.checkAndReconnect();
    } catch (e) {
      print('检查WebSocket连接失败: $e');
    }
  }

  /// 加载当前用户的浏览历史，用于关注流“未读”标记
  Future<void> _loadViewedPostIds() async {
    try {
      final userId = LocalStorage.instance.read('userId')?.toString() ?? '';
      if (userId.isEmpty) return;
      final historyItems = await BrowseHistoryService.getHistory(userId);
      setState(() {
        _viewedPostIds
          ..clear()
          ..addAll(historyItems.map((e) => e.postId));
      });
    } catch (_) {
      // 忽略错误，不影响主流程
    }
  }

  /// 加载分区帖子
  Future<void> _loadZonePosts() async {
    if (_zoneLoading || !_zoneHasMore) return;

    setState(() {
      _zoneLoading = true;
    });

    try {
      final resp = await ApiService.getPosts(
        page: _zonePage,
        pageSize: 12,
        disciplineTag: _currentZoneDiscipline,
      );
      final status = resp['statusCode'] as int? ?? 500;
      final body = resp['body'] as Map<String, dynamic>?;

      if (status >= 200 && status < 300 && body != null) {
        final postsData = (body['posts'] as List<dynamic>?) ?? [];
        final total = body['total'] as int? ?? postsData.length;
        final newPosts = postsData
            .map((e) => Post.fromJson(e as Map<String, dynamic>))
            .toList();

        setState(() {
          _zonePosts.addAll(newPosts);
          _zoneHasMore = _zonePosts.length < total;
          _zonePage += 1;
          _zoneLoading = false;
        });
      } else {
        setState(() {
          _zoneLoading = false;
        });
      }
    } catch (_) {
      setState(() {
        _zoneLoading = false;
      });
    }
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
      // 首页默认使用推荐接口（已登录时会根据兴趣排序，未登录则等价于按时间排序）
      final resp = await ApiService.getRecommendedPosts(page: 1, pageSize: 6);
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

        final bool useHot = _shouldUseHotRankingOnChunk(newPosts);
        final List<Post> ordered = useHot ? _sortedByHeat(newPosts) : newPosts;

        // 检查是否有“刚发布的新帖子”需要置顶展示
        Post? pinnedFromStorage = _consumeLastCreatedPostForPin(ordered);

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
          _useHotRanking = useHot;
          if (pinnedFromStorage != null) {
            _pinnedSelfPost = pinnedFromStorage;
          }
          _posts.clear();
          _posts.addAll(ordered);
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
      final resp = await ApiService.getRecommendedPosts(page: 1, pageSize: 6);
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
              if (_useHotRanking) {
                _posts.add(newPost);
              } else {
                _posts.insert(0, newPost);
              }
            }
          }
          if (_useHotRanking) {
            _posts
              ..clear()
              ..addAll(_sortedByHeat([..._posts]));
          }
          _hasMore = _posts.length < total;
        });
      }
    } catch (e) {
      // 忽略错误
    }

    // 同步刷新关注流，方便在其他页面刷新时获取最新关注动态
    _refreshFollowingFeed();
  }

  /// 手动刷新推荐流：回到顶部、清空现有列表并重新请求第一页
  Future<void> _reloadDiscoverFeed() async {
    if (_isLoading) return;

    // 回到顶部避免加载时跳动
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }

    setState(() {
      _pinnedSelfPost = null;
      _posts.clear();
      _hasMore = true;
    });

    await Future.wait([
      _loadInitialPosts(),
      _refreshFollowingFeed(),
    ]);
  }

  /// 触底后加载下一页（每次追加 6 条）
  Future<void> _loadMorePosts() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final currentPage = (_posts.length ~/ 6) + 1;
      final resp = await ApiService.getRecommendedPosts(page: currentPage, pageSize: 6);
      final status = resp['statusCode'] as int? ?? 500;
      final body = resp['body'] as Map<String, dynamic>?;

      if (status >= 200 && status < 300 && body != null) {
        final postsData = (body['posts'] as List<dynamic>?) ?? <dynamic>[];
        final total = body['total'] as int? ?? 0;

        final newPosts = postsData
            .map((p) => Post.fromJson(p as Map<String, dynamic>))
            .toList();

        final bool useHot = _shouldUseHotRankingOnChunk(newPosts);
        final combined = [..._posts, ...newPosts];
        final ordered = useHot ? _sortedByHeat(combined) : combined;

        setState(() {
          _useHotRanking = useHot;
          _posts
            ..clear()
            ..addAll(ordered);
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

  /// 关注流：初次加载
  Future<void> _loadInitialFollowingPosts() async {
    if (_followingLoading) return;

    setState(() {
      _followingLoading = true;
    });

    try {
      final resp = await ApiService.getFollowingPosts(page: 1, pageSize: 6);
      final status = resp['statusCode'] as int? ?? 500;
      final body = resp['body'] as Map<String, dynamic>?;

      if (status >= 200 && status < 300 && body != null) {
        final postsData = (body['posts'] as List<dynamic>?) ?? <dynamic>[];
        final total = body['total'] as int? ?? 0;

        final newPosts = postsData
            .map((p) => Post.fromJson(p as Map<String, dynamic>))
            .toList();

        // 如果还没有记录“看过的关注顶部帖子”，先记录一次，避免新建 Home 实例时误亮红点
        if (_lastFollowingTopPostIdSeen == null && newPosts.isNotEmpty) {
          _updateLastFollowingSeen(newPosts.first.id);
        }

        final bool hasNewFollowing = _shouldShowFollowingBadge(newPosts);

        setState(() {
          _followingPosts
            ..clear()
            ..addAll(newPosts);
          _followingHasMore = _followingPosts.length < total;
          _followingPage = 2;
          _followingLoading = false;
          if (_selectedTab == 0 && newPosts.isNotEmpty) {
            _updateLastFollowingSeen(newPosts.first.id);
          }
          if (hasNewFollowing) {
            _followingHasNew = true;
          }
        });
      } else {
        setState(() {
          _followingLoading = false;
        });
      }
    } catch (_) {
      setState(() {
        _followingLoading = false;
      });
    }
  }

  /// 关注流：加载更多
  Future<void> _loadMoreFollowingPosts() async {
    if (_followingLoading || !_followingHasMore) return;

    setState(() {
      _followingLoading = true;
    });

    try {
      final resp = await ApiService.getFollowingPosts(
        page: _followingPage,
        pageSize: 6,
      );
      final status = resp['statusCode'] as int? ?? 500;
      final body = resp['body'] as Map<String, dynamic>?;

      if (status >= 200 && status < 300 && body != null) {
        final postsData = (body['posts'] as List<dynamic>?) ?? <dynamic>[];
        final total = body['total'] as int? ?? 0;

        final newPosts = postsData
            .map((p) => Post.fromJson(p as Map<String, dynamic>))
            .toList();

        setState(() {
          _followingPosts.addAll(newPosts);
          _followingHasMore = _followingPosts.length < total;
          _followingPage += 1;
          _followingLoading = false;
          if (_selectedTab != 0 && newPosts.isNotEmpty) {
            _followingHasNew = true;
          }
        });
      } else {
        setState(() {
          _followingLoading = false;
        });
      }
    } catch (_) {
      setState(() {
        _followingLoading = false;
      });
    }
  }

  /// 刷新关注流（用于其他页面触发的全局刷新）
  Future<void> _refreshFollowingFeed() async {
    if (_followingLoading) return;
    setState(() {
      _followingLoading = true;
    });

    try {
      final resp = await ApiService.getFollowingPosts(page: 1, pageSize: 6);
      final status = resp['statusCode'] as int? ?? 500;
      final body = resp['body'] as Map<String, dynamic>?;

      if (status >= 200 && status < 300 && body != null) {
        final postsData = (body['posts'] as List<dynamic>?) ?? <dynamic>[];
        final total = body['total'] as int? ?? 0;
        final newPosts = postsData
            .map((p) => Post.fromJson(p as Map<String, dynamic>))
            .toList();

        // 如果还没有记录“看过的关注顶部帖子”，先记录一次，避免新建 Home 实例时误亮红点
        if (_lastFollowingTopPostIdSeen == null && newPosts.isNotEmpty) {
          _updateLastFollowingSeen(newPosts.first.id);
        }

        final bool hasNewFollowing = _shouldShowFollowingBadge(newPosts);

        setState(() {
          _followingPosts
            ..clear()
            ..addAll(newPosts);
          _followingHasMore = _followingPosts.length < total;
          _followingPage = 2;
          _followingLoading = false;
          if (_selectedTab == 0 && newPosts.isNotEmpty) {
            _lastFollowingTopPostIdSeen = newPosts.first.id;
          }
          // 不在关注页时展示红点提示
          if (hasNewFollowing) {
            _followingHasNew = true;
          }
        });
      } else {
        setState(() {
          _followingLoading = false;
        });
      }
    } catch (_) {
      setState(() {
        _followingLoading = false;
      });
    }
  }

  /// 从本地缓存中读取“刚刚发布的新帖子”，用于在首页临时置顶展示一条
  /// - 如果推荐流中已经包含这条帖子，会从列表中移除以避免重复
  /// - 只消费一次，读取后会清空本地缓存
  Post? _consumeLastCreatedPostForPin(List<Post> currentList) {
    try {
      final raw = LocalStorage.instance.read('lastCreatedPost');
      if (raw == null || raw is! String || raw.trim().isEmpty) {
        return null;
      }
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final pinned = Post.fromJson(decoded);

      // 避免与推荐流中的相同帖子重复展示
      currentList.removeWhere((p) => p.id == pinned.id);

      // 仅消费一次：清空本地缓存
      LocalStorage.instance.write('lastCreatedPost', '');
      return pinned;
    } catch (e) {
      print('读取本地 lastCreatedPost 失败: $e');
      return null;
    }
  }

  /// 判断关注流是否有新帖子需要显示红点
  bool _shouldShowFollowingBadge(List<Post> newPosts) {
    if (newPosts.isEmpty) return false;
    final String? latestId = newPosts.first.id;
    if (latestId == null || latestId.isEmpty) return false;
    // 已在关注页则不显示红点；仅当有新的顶部帖子且未在关注页时展示
    return _selectedTab != 0 && latestId != _lastFollowingTopPostIdSeen;
  }

  /// 从本地存储恢复最近一次“已看过的关注顶部帖子”
  void _loadLastFollowingSeenFromStorage() {
    try {
      final raw = LocalStorage.instance.read('lastFollowingTopIdSeen');
      if (raw is String && raw.trim().isNotEmpty) {
        _lastFollowingTopPostIdSeen = raw.trim();
      }
    } catch (e) {
      print('读取 lastFollowingTopIdSeen 失败: $e');
    }
  }

  /// 更新最近一次“已看过的关注顶部帖子”，并持久化到本地
  void _updateLastFollowingSeen(String? id) {
    if (id == null || id.isEmpty) return;
    _lastFollowingTopPostIdSeen = id;
    try {
      LocalStorage.instance.write('lastFollowingTopIdSeen', id);
    } catch (e) {
      print('写入 lastFollowingTopIdSeen 失败: $e');
    }
  }

  /// 关注流滚动监听
  void _followingScrollListener() {
    if (_followingScrollController.offset >=
        _followingScrollController.position.maxScrollExtent - 200) {
      _loadMoreFollowingPosts();
    }
  }

  /// 卡片点击 -> 打开详情页
  void _onPostTap(Post post) {
    // 本地立即标记为已浏览，移除“未读”红点
    if (!_viewedPostIds.contains(post.id)) {
      setState(() {
        _viewedPostIds.add(post.id);
      });
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PostDetailScreen(post: post)),
    ).then((result) {
      if (result == true) {
        setState(() {
          if (_pinnedSelfPost?.id == post.id) {
            _pinnedSelfPost = null;
          }
          _posts.removeWhere((p) => p.id == post.id);
        });
        return;
      }
      // 从详情页返回时，只更新当前帖子的点赞状态，不刷新整个列表
      final currentPostIndex = _posts.indexWhere((p) => p.id == post.id);
      if (currentPostIndex != -1) {
        // 重新获取单个帖子详情，同步点赞状态
        _syncPostLikeStatus(post.id);
      } else if (_pinnedSelfPost?.id == post.id) {
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
        } else if (_pinnedSelfPost?.id == postId) {
          setState(() {
            _pinnedSelfPost!.likesCount = updatedPost.likesCount;
            _pinnedSelfPost!.isLiked = updatedPost.isLiked;
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
        } else if (_pinnedSelfPost?.id == post.id) {
          setState(() {
            _pinnedSelfPost!.likesCount =
                updatedLikesCount ?? _pinnedSelfPost!.likesCount;
            _pinnedSelfPost!.isLiked =
                updatedIsLiked ?? !_pinnedSelfPost!.isLiked;
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部导航栏
            _buildTopBar(),

            // 内容区域
            Expanded(
              child: _selectedTab == 0
                  ? _buildFollowingTabContent()
                  : _selectedTab == 1
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
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surface,
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
          // Logo和PaperHub文字
          Row(
            children: [
              Image.asset(
                'assets/images/logo.png',
                height: 32,
                width: 32,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox(width: 32, height: 32);
                },
              ),
              const SizedBox(width: 8),
              Text(
                'PaperHub',
                style: FontUtils.textStyle(
                  text: 'PaperHub',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),

          // 中间按钮组
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTabButton("关注", 0, showUnreadDot: _followingHasNew),
                const SizedBox(width: 24),
                _buildTabButton("发现", 1),
                const SizedBox(width: 24),
                _buildTabButton("分区", 2),
              ],
            ),
          ),

          // 搜索图标
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.themeModeNotifier != null)
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: widget.themeModeNotifier!,
                  builder: (_, mode, __) {
                    final isDark = mode == ThemeMode.dark;
                    return IconButton(
                      tooltip: isDark ? '切换日间模式' : '切换夜间模式',
                      icon: Icon(
                        isDark ? Icons.dark_mode : Icons.light_mode,
                        color: scheme.onSurface.withOpacity(0.8),
                      ),
                      onPressed: widget.onThemeToggle ??
                          () {
                            final next = isDark ? ThemeMode.light : ThemeMode.dark;
                            widget.onThemeModeChanged?.call(next);
                          },
                    );
                  },
                ),
              InkWell(
                onTap: _onSearchTap,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(6.0),
                  child: Icon(Icons.search,
                      color: scheme.onSurface.withOpacity(0.7), size: 22),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  //  顶部“发现 / 分区”按钮样式
  Widget _buildTabButton(String label, int index, {bool showUnreadDot = false}) {
    final bool selected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        final bool wasSelected = _selectedTab == index;
        setState(() {
          _selectedTab = index;
          if (index == 0) {
            _followingHasNew = false; // 进入关注页后红点立即消失
            if (_followingPosts.isNotEmpty) {
              // 记录当前关注流顶部帖子，后续刷新用于判断是否有新内容
              _lastFollowingTopPostIdSeen = _followingPosts.first.id;
            }
          }
          // 离开发现页即清除置顶的“我刚发的”帖子
          if (index != 1) {
            _pinnedSelfPost = null;
          }
        });

        // 懒加载关注流 / 分区内容
        if (index == 0 && _followingPosts.isEmpty && !_followingLoading) {
          _loadInitialFollowingPosts();
        } else if (index == 2 &&
            _zonePosts.isEmpty &&
            !_zoneLoading &&
            _zoneHasMore) {
          _loadZonePosts();
        } else if (index == 1 && !_isLoading) {
          // 从其他 tab 切回发现时，触发一次关注流刷新以获取最新关注动态
          _refreshFollowingFeed();
        }

        // 点击“发现”文案时，触发刷新推荐流（小红书同款）
        if (index == 1 && wasSelected) {
          _reloadDiscoverFeed();
        } else if (index == 1 && _posts.isEmpty && !_isLoading) {
          // 切换回发现页且列表为空时补充首屏数据
          _loadInitialPosts();
        }
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Text(
            label,
            style: FontUtils.textStyle(
              text: label,
              fontSize: 16,
              fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
          if (showUnreadDot)
            Positioned(
              right: -12,
              top: -6,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 瀑布流内容区
  /// - `itemCount` 在加载中时额外 +1 用作显示底部加载指示器。
  /// - 使用 `MasonryGridView.count` 创建 2 列错落网格。
  Widget _buildWaterfallGrid() {
    final bool hasPinned = _pinnedSelfPost != null;
    final int baseCount = _posts.length + (hasPinned ? 1 : 0);
    final int totalCount = baseCount + (_isLoading ? 1 : 0);

    return MasonryGridView.count(
      controller: _scrollController,
      crossAxisCount: 2,
      crossAxisSpacing: 3,
      mainAxisSpacing: 3,
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      itemCount: totalCount,
      itemBuilder: (context, index) {
        if (index == baseCount) {
          return _buildLoadMoreIndicator();
        }
        final Post target =
            hasPinned ? (index == 0 ? _pinnedSelfPost! : _posts[index - 1]) : _posts[index];
        return PostCard(
          post: target,
          onTap: () => _onPostTap(target),
          onAuthorTap: () => _openUserProfile(target.author.id),
          onLikeTap: _handlePostLike,
        );
      },
    );
  }

  /// 检查用户画像信号，决定是否使用热度排序兜底
  Future<void> _evaluateUserSignals() async {
    try {
      final resp = await ApiService.getCurrentUserProfile();
      if (resp['statusCode'] == 200) {
        final body = resp['body'] as Map<String, dynamic>?;
        if (body != null) {
          final profile = UserProfile.fromJson(body);
          final bool missingDirections = profile.researchDirections.isEmpty;
          setState(() {
            _currentUserProfile = profile;
            _useHotRanking = missingDirections || _useHotRanking;
          });
          if (_useHotRanking && _posts.isNotEmpty) {
            _sortDiscoverByHeat();
          }
          return;
        }
      }
    } catch (_) {
      // 忽略异常，尝试读取本地缓存
    }

    try {
      final cached = LocalStorage.instance.read('currentUser');
      if (cached != null) {
        final decoded = jsonDecode(cached) as Map<String, dynamic>;
        final profile = UserProfile.fromJson(decoded);
        final bool missingDirections = profile.researchDirections.isEmpty;
        setState(() {
          _currentUserProfile = profile;
          _useHotRanking = missingDirections || _useHotRanking;
        });
        if (_useHotRanking && _posts.isNotEmpty) {
          _sortDiscoverByHeat();
        }
      }
    } catch (_) {
      // 忽略本地读取异常
    }
  }

  double _computeHeat(Post p) =>
      p.likesCount +
      p.commentsCount * 0.5 +
      p.searchHistoryScore * 1.0;

  List<Post> _sortedByHeat(List<Post> list) {
    final sorted = [...list];
    sorted.sort((a, b) => _computeHeat(b).compareTo(_computeHeat(a)));
    return sorted;
  }

  void _sortDiscoverByHeat() {
    final sorted = _sortedByHeat(_posts);
    setState(() {
      _posts
        ..clear()
        ..addAll(sorted);
    });
  }

  bool _shouldUseHotRankingOnChunk(List<Post> chunk) {
    if (chunk.isEmpty) return _useHotRanking;
    final weakRecommendation = chunk.every((p) => p.recommendationScore < 2);
    return _useHotRanking || weakRecommendation;
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

  /// 关注页内容：如果没有数据显示占位，否则使用瀑布流布局
  Widget _buildFollowingTabContent() {
    if (_followingLoading && _followingPosts.isEmpty) {
      return _buildInitialLoading();
    }

    if (_followingPosts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            '还没有关注的人的动态，去发现页多关注一些优质作者吧～',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

    return MasonryGridView.count(
      controller: _followingScrollController,
      crossAxisCount: 2,
      crossAxisSpacing: 3,
      mainAxisSpacing: 3,
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      itemCount: _followingPosts.length + (_followingLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _followingPosts.length) {
          return _buildLoadMoreIndicator();
        }
        final post = _followingPosts[index];
        return PostCard(
          post: post,
          onTap: () => _onPostTap(post),
          onAuthorTap: () => _openUserProfile(post.author.id),
          onLikeTap: _handlePostLike,
        );
      },
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
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final textColor = isDark ? Colors.white : Colors.black87;
          return GestureDetector(
            onTap: () {
              if (_currentZoneDiscipline == discipline) return;
              setState(() {
                _currentZoneDiscipline = discipline;
                // 切换分区时重置状态并加载新分区的数据
                _zonePosts.clear();
                _zonePage = 1;
                _zoneHasMore = true;
              });
              _loadZonePosts();
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? color.withOpacity(isDark ? 0.3 : 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected
                      ? color
                      : (isDark ? Colors.white24 : Colors.grey.shade300),
                ),
              ),
              child: Center(
                child: Text(
                  discipline,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal,
                    color: textColor,
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

  /// 分区内瀑布流（使用后端标签过滤）
  Widget _buildZoneWaterfallGrid() {
    // 使用独立的帖子列表和加载状态
    if (_zonePosts.isEmpty && _zoneLoading) {
      return _buildInitialLoading();
    }

    if (_zonePosts.isEmpty) {
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
      crossAxisSpacing: 3,
      mainAxisSpacing: 3,
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      itemCount: _zonePosts.length,
      itemBuilder: (context, index) {
        final post = _zonePosts[index];
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
          if (index != 0) {
            _pinnedSelfPost = null; // 离开首页清除置顶的自发帖子
          }
        });
        if (index == 1) {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const MessageScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
              transitionDuration: Duration.zero,
            ),
          ).then((_) {
            // 当从消息页面返回时，恢复首页高亮
            setState(() {
              _currentIndex = 0;
            });
          });
        } else if (index == 2) {
          Navigator.of(context)
              .push(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => const NoteEditorPage(),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
                  transitionDuration: Duration.zero,
                ),
              )
              .then((result) {
                setState(() {
                  _currentIndex = 0;
                });
                if (result is Post) {
                  setState(() {
                    _selectedTab = 1;
                    _pinnedSelfPost = result;
                    _posts.removeWhere((p) => p.id == result.id);
                  });
                  return;
                }
                // 发布结果未知/失败时保持原逻辑
                final firstPagePosts = _posts.take(6).length;
                if (firstPagePosts < 6 || _posts.isEmpty) {
                  _posts.clear();
                  _hasMore = true;
                  _loadInitialPosts();
                } else {
                  _refreshFirstPage();
                }
              });
        } else if (index == 3) {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const ProfilePage(isMainPage: true),
              transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
              transitionDuration: Duration.zero,
            ),
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
    _followingScrollController.dispose();
    super.dispose();
  }
}
