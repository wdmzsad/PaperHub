// lib/screens/follow_list_screen.dart
/// 关注/粉丝/互相关注列表页面
import 'package:flutter/material.dart';
import '../models/user_summary.dart';
import '../services/api_service.dart';
import '../services/local_storage.dart';
import 'profile_screen.dart';

class FollowListScreen extends StatefulWidget {
  final String userId;
  final String? initialTab; // 'following', 'followers', 'mutual'
  
  const FollowListScreen({
    Key? key,
    required this.userId,
    this.initialTab,
  }) : super(key: key);

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTabIndex = 0;
  bool _hasRelationshipChanges = false;
  late final bool _isViewingSelf;
  late final List<GlobalKey<_FollowTabState>> _tabKeys;

  @override
  void initState() {
    super.initState();

    final currentUserId = LocalStorage.instance.read('userId')?.toString();
    _isViewingSelf = currentUserId != null && currentUserId == widget.userId;

    final tabCount = _isViewingSelf ? 3 : 2;
    _tabKeys = List.generate(
      tabCount,
      (_) => GlobalKey<_FollowTabState>(),
    );
    
    // 根据初始tab设置当前索引（在仅两栏时忽略 mutual）
    if (widget.initialTab == 'followers') {
      _currentTabIndex = 1;
    } else if (widget.initialTab == 'mutual' && _isViewingSelf) {
      _currentTabIndex = 2;
    }

    _tabController = TabController(
      length: _tabKeys.length,
      vsync: this,
      initialIndex: _currentTabIndex,
    );
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _currentTabIndex = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _hasRelationshipChanges);
        return false;
      },
      child: Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context, _hasRelationshipChanges),
        ),
        title: const Text(
          '关注与粉丝',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.black87,
              indicatorWeight: 2,
              labelColor: Colors.black87,
              unselectedLabelColor: Colors.grey[600],
              labelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.normal,
              ),
              tabs: [
                const Tab(text: '关注'),
                const Tab(text: '粉丝'),
                if (_isViewingSelf) const Tab(text: '互相关注'),
              ],
            ),
          ),
        ),
      ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _FollowTab(
              key: _tabKeys[0],
              userId: widget.userId,
              type: 'following',
              onRelationshipChanged: _handleRelationshipChanged,
              onProfileReturned: _reloadAllTabs,
            ),
            _FollowTab(
              key: _tabKeys[1],
              userId: widget.userId,
              type: 'followers',
              onRelationshipChanged: _handleRelationshipChanged,
              onProfileReturned: _reloadAllTabs,
            ),
            if (_isViewingSelf)
              _FollowTab(
                key: _tabKeys[2],
                userId: widget.userId,
                type: 'mutual',
                onRelationshipChanged: _handleRelationshipChanged,
                onProfileReturned: _reloadAllTabs,
              ),
          ],
        ),
      ),
    );
  }

  void _handleRelationshipChanged(String sourceType, UserSummary user) {
    _hasRelationshipChanges = true;
    for (var i = 0; i < _tabKeys.length; i++) {
      final key = _tabKeys[i];
      final tabType = _tabTypeForIndex(i);
      if (tabType == sourceType) continue;
      key.currentState?.applyExternalUpdate(user);
    }
  }

  /// 从个人主页返回后，可能发生了关注关系变化，统一刷新所有Tab
  void _reloadAllTabs() {
    for (final key in _tabKeys) {
      key.currentState?.reload();
    }
    _hasRelationshipChanges = true;
  }

  String _tabTypeForIndex(int index) {
    if (index == 0) return 'following';
    if (index == 1) return 'followers';
    // 仅在查看自己的时候才会存在第三个互相关注 Tab
    return 'mutual';
  }
}

/// 单个Tab的内容（关注/粉丝/互相关注）
class _FollowTab extends StatefulWidget {
  final String userId;
  final String type; // 'following', 'followers', 'mutual'
  final void Function(String sourceType, UserSummary user)? onRelationshipChanged;
  /// 从某个用户的个人主页返回时回调，用于让上层统一刷新其他Tab
  final VoidCallback? onProfileReturned;

  const _FollowTab({
    Key? key,
    required this.userId,
    required this.type,
    this.onRelationshipChanged,
    this.onProfileReturned,
  }) : super(key: key);

  @override
  State<_FollowTab> createState() => _FollowTabState();
}

class _FollowTabState extends State<_FollowTab>
    with AutomaticKeepAliveClientMixin<_FollowTab> {
  List<UserSummary> _users = [];
  bool _isFetching = false;
  bool _refreshing = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 0;
  final int _pageSize = 20;
  final ScrollController _scrollController = ScrollController();
  String? _forbiddenMessage;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadUsers({bool loadMore = false}) async {
    if (_isFetching || (loadMore && (!_hasMore || _forbiddenMessage != null))) return;
    setState(() {
      _isFetching = true;
      if (loadMore) {
        _loadingMore = true;
      } else {
        _refreshing = _users.isNotEmpty;
        _page = 0;
        if (_users.isEmpty) {
          _refreshing = false;
        }
        // 手动刷新时清除之前的禁止访问提示，重新尝试
        _forbiddenMessage = null;
      }
    });

    try {
      final resp = await _fetchUsers(page: _page);

      if (resp['statusCode'] == 200) {
        final body = resp['body'] as Map<String, dynamic>?;
        if (body == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('加载失败: 响应数据为空')),
            );
          }
          return;
        }

        final usersData = (body['users'] as List<dynamic>?) ??
            (body['data'] as List<dynamic>?) ??
            (body['followers'] as List<dynamic>?) ??
            (body['following'] as List<dynamic>?) ??
            [];

        final users = usersData
            .map((e) {
              try {
                return UserSummary.fromJson(e as Map<String, dynamic>);
              } catch (_) {
                return null;
              }
            })
            .whereType<UserSummary>()
            .map((user) {
              if (widget.type == 'followers') {
                return user.copyWith(isFollower: user.isFollower ?? true);
              }
              if (widget.type == 'following') {
                return user.copyWith(isFollowing: user.isFollowing ?? true);
              }
              return user;
            })
            .toList();

        final total = (body['total'] as num?)?.toInt() ??
            (body['count'] as num?)?.toInt() ??
            users.length;

        setState(() {
          if (loadMore) {
            _users.addAll(users);
            _page++;
          } else {
            _users = users;
            _page = 1;
          }
          _hasMore = _users.length < total;
        });
      } else if (resp['statusCode'] == 403) {
        // 隐私限制：对方隐藏了该列表
        final message =
            (resp['body'] as Map<String, dynamic>?)?['message'] ?? '对方已隐藏该列表';
        setState(() {
          _forbiddenMessage = message;
          _users = [];
          _hasMore = false;
        });
      } else {
        final message =
            (resp['body'] as Map<String, dynamic>?)?['message'] ?? '未知错误';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('加载失败: $message (${resp['statusCode']})')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFetching = false;
          _refreshing = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _isFetching) return;
    await _loadUsers(loadMore: true);
  }

  /// 对外提供的刷新接口，供上层在需要时强制刷新当前Tab
  void reload() {
    _loadUsers();
  }

  void _handleLocalChange(UserSummary user) {
    setState(() {
      _upsertOrRemove(user);
    });
    widget.onRelationshipChanged?.call(widget.type, user);
  }

  void _upsertOrRemove(UserSummary user) {
    final shouldExist = _shouldDisplay(user);
    final index = _users.indexWhere((u) => u.id == user.id);
    if (shouldExist) {
      if (index >= 0) {
        _users[index] = user;
      } else {
        _users.insert(0, user);
      }
    } else {
      if (index >= 0) {
        _users.removeAt(index);
      }
    }
  }

  bool _shouldDisplay(UserSummary user) {
    switch (widget.type) {
      case 'following':
        return user.isFollowing ?? false;
      case 'followers':
        return user.isFollower ?? false;
      case 'mutual':
        return (user.isFollowing ?? false) && (user.isFollower ?? false);
      default:
        return false;
    }
  }

  void applyExternalUpdate(UserSummary user) {
    if (!_shouldDisplay(user) &&
        !_users.any((element) => element.id == user.id)) {
      return;
    }
    setState(() {
      _upsertOrRemove(user);
    });
  }

  @override
  bool get wantKeepAlive => true;

  Future<Map<String, dynamic>> _fetchUsers({required int page}) {
    switch (widget.type) {
      case 'followers':
        return ApiService.getFollowers(
          widget.userId,
          page: page,
          pageSize: _pageSize,
        );
      case 'mutual':
        return ApiService.getMutualFollowers(
          widget.userId,
          page: page,
          pageSize: _pageSize,
        );
      default:
        return ApiService.getFollowing(
          widget.userId,
          page: page,
          pageSize: _pageSize,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_forbiddenMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Text(
            _forbiddenMessage!,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_isFetching && _users.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              widget.type == 'mutual'
                  ? '暂无互相关注'
                  : widget.type == 'followers'
                      ? '暂无粉丝'
                      : '暂无关注',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => _loadUsers(),
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _users.length + (_hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _users.length) {
                return _loadingMore
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : const SizedBox.shrink();
              }

              final user = _users[index];
              return _UserListItem(
                key: ValueKey('${widget.type}-${user.id}'),
                user: user,
                type: widget.type,
                onStateChanged: () => _loadUsers(),
                onProfileReturned: widget.onProfileReturned,
                onRelationshipChanged: (updated) =>
                    widget.onRelationshipChanged?.call(widget.type, updated),
                onFollowChanged: _handleLocalChange,
              );
            },
          ),
        ),
        if (_refreshing)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.transparent,
            ),
          ),
      ],
    );
  }
}

/// 用户列表项
class _UserListItem extends StatelessWidget {
  final UserSummary user;
  final String type;
  final ValueChanged<UserSummary>? onRelationshipChanged;
  final ValueChanged<UserSummary>? onFollowChanged;
  /// 当前列表项所在的Tab刷新回调
  final VoidCallback? onStateChanged;
  /// 从个人主页返回时通知上层（FollowListScreen）统一刷新所有Tab
  final VoidCallback? onProfileReturned;

  const _UserListItem({
    Key? key,
    required this.user,
    required this.type,
    this.onRelationshipChanged,
    this.onFollowChanged,
    this.onStateChanged,
    this.onProfileReturned,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUserId = LocalStorage.instance.read('userId')?.toString();
    final isMe = currentUserId != null && currentUserId == user.id;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfilePage(userId: user.id),
          ),
        ).then((_) {
          // 返回后刷新当前Tab
          onStateChanged?.call();
          // 同时通知上层刷新其他Tab，避免关注/互关列表不同步
          onProfileReturned?.call();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // 头像
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: _getAvatarImage(user.avatar),
                ),
                if (type == 'mutual')
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: Colors.blue,
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // 用户信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (user.bio != null && user.bio!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      user.bio!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            // 如果这一项就是当前登录用户自己，则不显示关注按钮
            if (!isMe)
              _FollowActionButton(
                key: ValueKey('follow-btn-${type}-${user.id}'),
                user: user,
                listType: type,
                onStateChanged: onStateChanged,
                onFollowChanged: onFollowChanged,
              ),
          ],
        ),
      ),
    );
  }

  ImageProvider _getAvatarImage(String avatar) {
    if (avatar.startsWith('http')) {
      return NetworkImage(avatar);
    }
    return const AssetImage('images/DefaultAvatar.png');
  }
}

/// 关注操作按钮（支持关注/回关/互关提示）
class _FollowActionButton extends StatefulWidget {
  final UserSummary user;
  final String listType;
  final VoidCallback? onStateChanged;
  final ValueChanged<UserSummary>? onFollowChanged;

  const _FollowActionButton({
    Key? key,
    required this.user,
    required this.listType,
    this.onStateChanged,
    this.onFollowChanged,
  }) : super(key: key);

  @override
  State<_FollowActionButton> createState() => _FollowActionButtonState();
}

class _FollowActionButtonState extends State<_FollowActionButton> {
  late bool _isFollowing;
  late bool _isFollower;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _syncFromWidget();
  }

  @override
  void didUpdateWidget(covariant _FollowActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id ||
        oldWidget.user.isFollowing != widget.user.isFollowing ||
        oldWidget.user.isFollower != widget.user.isFollower ||
        oldWidget.listType != widget.listType) {
      _syncFromWidget();
    }
  }

  void _syncFromWidget() {
    _isFollowing = widget.user.isFollowing ??
        (widget.user.isMutual == true ? true : null) ??
        (widget.listType == 'following' || widget.listType == 'mutual');
    _isFollower = widget.user.isFollower ??
        (widget.user.isMutual == true ? true : null) ??
        (widget.listType == 'followers' || widget.listType == 'mutual');
  }

  bool get _isMutual => _isFollowing && _isFollower;
  bool get _needsFollowBack => !_isFollowing && _isFollower;

  Future<void> _handlePressed() async {
    if (_isProcessing || widget.user.id.isEmpty) return;
    if (_isFollowing) {
      final confirmed = await _confirmUnfollow();
      if (confirmed != true) return;
      await _performUnfollow();
    } else {
      await _performFollow();
    }
  }

  Future<void> _performFollow() async {
    setState(() => _isProcessing = true);
    try {
      final resp = await ApiService.followUser(widget.user.id);
      if (resp['statusCode'] != 200) {
        final message = (resp['body'] as Map<String, dynamic>?)?['message'] ?? '操作失败';
        throw Exception(message);
      }
      if (!mounted) return;
      setState(() {
        _isFollowing = true;
        _isProcessing = false;
      });
      _emitChange();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失败: $e')),
      );
    }
  }

  Future<void> _performUnfollow() async {
    setState(() => _isProcessing = true);
    try {
      final resp = await ApiService.unfollowUser(widget.user.id);
      if (resp['statusCode'] != 200) {
        final message = (resp['body'] as Map<String, dynamic>?)?['message'] ?? '操作失败';
        throw Exception(message);
      }
      if (!mounted) return;
      setState(() {
        _isFollowing = false;
        _isProcessing = false;
      });
      _emitChange();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失败: $e')),
      );
    }
  }

  Future<bool?> _confirmUnfollow() async {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('不再关注该作者？'),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.grey[200],
                foregroundColor: Colors.black87,
              ),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFFDE0E0),
                foregroundColor: const Color(0xFFD32F2F),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('不再关注'),
            ),
          ],
        );
      },
    );
  }

  ButtonStyle _buttonStyle() {
    final baseShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(20));
    if (_needsFollowBack) {
      return OutlinedButton.styleFrom(
        backgroundColor: const Color(0xFFE6F0FF),
        foregroundColor: const Color(0xFF1C64D9),
        side: const BorderSide(color: Color(0xFFA0C4FF)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        shape: baseShape,
      );
    }
    if (_isMutual) {
      return OutlinedButton.styleFrom(
        backgroundColor: const Color(0xFFF5F5F5),
        foregroundColor: Colors.grey[700],
        side: const BorderSide(color: Color(0xFFE0E0E0)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: baseShape,
      );
    }
    if (_isFollowing) {
      return OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[700],
        side: BorderSide(color: Colors.grey[300]!),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: baseShape,
      );
    }
    return OutlinedButton.styleFrom(
      backgroundColor: const Color(0xFF1A73E8),
      foregroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFF1A73E8)),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      shape: baseShape,
    );
  }

  String get _label {
    if (_isMutual) return '互相关注';
    if (_needsFollowBack) return '回关';
    if (_isFollowing) return '已关注';
    return '关注';
  }

  void _emitChange() {
    final updated = widget.user.copyWith(
      isFollowing: _isFollowing,
      isFollower: _isFollower,
      isMutual: _isMutual,
    );
    widget.onFollowChanged?.call(updated);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.user.id.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 36,
      child: OutlinedButton(
        onPressed: _isProcessing ? null : _handlePressed,
        style: _buttonStyle(),
        child: _isProcessing
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                _label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

