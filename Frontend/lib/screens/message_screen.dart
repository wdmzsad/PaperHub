/// PaperHub 消息页面
///
/// 功能：
/// - 显示所有聊天会话列表
/// - 支持搜索会话
/// - 显示最后消息和未读计数
/// - 点击进入聊天详情
/// - 下拉刷新
///
/// 设计风格：
/// - 遵循PaperHub的设计语言（蓝色主题、12px圆角、轻微阴影）
/// - 清晰的信息层次和足够的留白
import 'package:flutter/material.dart';
import '../models/conversation_model.dart';
import '../models/notification_model.dart';
import '../models/post_model.dart';
import '../services/chat_service.dart';
import '../services/api_service.dart';
import '../services/local_storage.dart';
import '../services/unread_service.dart';
import '../widgets/conversation_item.dart';
import 'chat_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'post_detail_screen.dart';
import '../pages/note_editor_page.dart';

// 赞和收藏页面
class LikesAndFavoritesScreen extends StatefulWidget {
  const LikesAndFavoritesScreen({Key? key}) : super(key: key);

  @override
  State<LikesAndFavoritesScreen> createState() => _LikesAndFavoritesScreenState();
}

class _LikesAndFavoritesScreenState extends State<LikesAndFavoritesScreen> {
  List<NotificationItem> _notifications = [];
  bool _isLoading = true;
  int _page = 0;
  final int _pageSize = 20;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications({bool loadMore = false}) async {
    if (!loadMore) {
      setState(() {
        _isLoading = true;
        _page = 0;
      });
    }

    try {
      final resp = await ApiService.getLikesAndFavorites(page: _page, pageSize: _pageSize);
      if (resp['statusCode'] == 200) {
        final body = resp['body'] as Map<String, dynamic>;
        final notifications = (body['notifications'] as List)
            .map((json) => NotificationItem.fromJson(json))
            .toList();

        setState(() {
          if (loadMore) {
            _notifications.addAll(notifications);
          } else {
            _notifications = notifications;
          }
          _hasMore = notifications.length == _pageSize;
          _page++;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inDays > 0) {
      return '${diff.inDays}天前';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}小时前';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }

  IconData _getIcon(NotificationType type) {
    switch (type) {
      case NotificationType.postLike:
      case NotificationType.commentLike:
        return Icons.favorite;
      case NotificationType.postFavorite:
        return Icons.bookmark;
      default:
        return Icons.favorite;
    }
  }

  Color _getIconColor(NotificationType type) {
    switch (type) {
      case NotificationType.postLike:
      case NotificationType.commentLike:
        return Colors.red;
      case NotificationType.postFavorite:
        return Colors.blue;
      default:
        return Colors.red;
    }
  }

  Future<void> _navigateToPostDetail(String postId) async {
    try {
      final resp = await ApiService.getPost(postId);
      if (resp['statusCode'] == 200) {
        final body = resp['body'] as Map<String, dynamic>;
        final post = Post.fromJson(body);
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PostDetailScreen(post: post),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载帖子失败: $e')),
        );
      }
    }
  }

  void _openUserProfile(String userId) {
    if (userId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfilePage(userId: userId),
      ),
    );
  }

  Widget _buildIconBadge(IconData icon, Color color) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0.2,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: scheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '赞和收藏',
          style: TextStyle(
            color: scheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading && _notifications.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? const Center(child: Text('暂无通知'))
              : RefreshIndicator(
                  onRefresh: () => _loadNotifications(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemCount: _notifications.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _notifications.length) {
                        _loadNotifications(loadMore: true);
                        return const Center(child: CircularProgressIndicator());
                      }
                      final notification = _notifications[index];
                      return _buildNotificationItem(
                        notification: notification,
                        icon: _getIcon(notification.type),
                        iconColor: _getIconColor(notification.type),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildNotificationItem({
    required NotificationItem notification,
    required IconData icon,
    required Color iconColor,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final readBg = scheme.surfaceVariant;
    final unreadBg = scheme.primary.withOpacity(0.12);
    final textColor = scheme.onSurface;
    final secondary = scheme.onSurfaceVariant;
    return GestureDetector(
      onTap: () async {
        // 标记为已读
        if (!notification.read) {
          try {
            await ApiService.markNotificationAsRead(notification.id);
          } catch (e) {
            // 忽略错误
          }
        }
        // 跳转到帖子详情
        if (notification.post != null) {
          _navigateToPostDetail(notification.post!.id);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: notification.read ? readBg : unreadBg,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                if (!notification.read) {
                  ApiService.markNotificationAsRead(notification.id);
                }
                _openUserProfile(notification.actor.id);
              },
              child: CircleAvatar(
                radius: 20,
                backgroundImage: notification.actor.avatar != null
                    ? NetworkImage(notification.actor.avatar!)
                    : null,
                child: notification.actor.avatar == null
                    ? Text(
                        notification.actor.name.isNotEmpty
                            ? notification.actor.name[0].toUpperCase()
                            : '?',
                        style: TextStyle(color: scheme.onPrimaryContainer),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.actor.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.content,
                    style: TextStyle(
                      color: secondary,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatTime(notification.createdAt),
                  style: TextStyle(
                    color: secondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                _buildIconBadge(icon, iconColor),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// 新增关注页面
class NewFollowersScreen extends StatefulWidget {
  const NewFollowersScreen({Key? key}) : super(key: key);

  @override
  State<NewFollowersScreen> createState() => _NewFollowersScreenState();
}

class _NewFollowersScreenState extends State<NewFollowersScreen> {
  List<NotificationItem> _notifications = [];
  bool _isLoading = true;
  int _page = 0;
  final int _pageSize = 20;
  bool _hasMore = true;
  final Set<String> _followedUserIds = {};
  final Set<String> _followLoadingUserIds = {};
  final Map<String, bool> _followStatusCache = {};
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = LocalStorage.instance.read('userId');
    _loadNotifications();
  }

  Future<void> _loadNotifications({bool loadMore = false}) async {
    if (!loadMore) {
      setState(() {
        _isLoading = true;
        _page = 0;
      });
    }

    try {
      final resp = await ApiService.getFollows(page: _page, pageSize: _pageSize);
      if (resp['statusCode'] == 200) {
        final body = resp['body'] as Map<String, dynamic>;
        final notifications = (body['notifications'] as List)
            .map((json) => NotificationItem.fromJson(json))
            .toList();
        final resolvedFollowBackIds = await _determineFollowBackIds(notifications);

        setState(() {
          if (loadMore) {
            _notifications.addAll(notifications);
            _followedUserIds.addAll(resolvedFollowBackIds);
          } else {
            _notifications = notifications;
            _followedUserIds
              ..clear()
              ..addAll(resolvedFollowBackIds);
          }
          _hasMore = notifications.length == _pageSize;
          _page++;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inDays > 0) {
      return '${diff.inDays}天前';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}小时前';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }

  Future<void> _navigateToPostDetail(String postId) async {
    try {
      final resp = await ApiService.getPost(postId);
      if (resp['statusCode'] == 200) {
        final body = resp['body'] as Map<String, dynamic>;
        final post = Post.fromJson(body);
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PostDetailScreen(post: post),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载帖子失败: $e')),
        );
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _openUserProfile(String userId) async {
    if (userId.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfilePage(userId: userId),
      ),
    );
    // 从用户主页返回时，刷新关注状态
    await _refreshFollowStatus();
  }

  /// 刷新所有用户的关注状态
  Future<void> _refreshFollowStatus() async {
    if (_notifications.isEmpty) return;
    
    // 重新检查每个用户的关注状态
    final currentUserId = _currentUserId ??= LocalStorage.instance.read('userId');
    if (currentUserId == null || currentUserId.isEmpty) return;

    final actorIds = _notifications
        .map((n) => n.actor.id)
        .where((id) => id.isNotEmpty)
        .toSet();
    
    if (actorIds.isEmpty) return;

    // 清除缓存，强制重新查询
    _followStatusCache.clear();
    
    // 重新确定哪些用户已关注
    final resolvedFollowBackIds = await _determineFollowBackIds(_notifications);
    
    if (mounted) {
      setState(() {
        _followedUserIds
          ..clear()
          ..addAll(resolvedFollowBackIds);
      });
    }
  }

  Future<void> _handleFollowBack(NotificationItem notification) async {
    final userId = notification.actor.id;
    if (userId.isEmpty || _followedUserIds.contains(userId)) return;
    setState(() {
      _followLoadingUserIds.add(userId);
    });

    try {
      final resp = await ApiService.followUser(userId);
      if (resp['statusCode'] != 200) {
        final message = (resp['body'] as Map<String, dynamic>?)?['message'] ?? '回关失败';
        throw Exception(message);
      }
      setState(() {
        _followedUserIds.add(userId);
        _followStatusCache[userId] = true;
      });
      _showSnack('已回关 ${notification.actor.name}');
    } catch (e) {
      _showSnack('回关失败：$e');
    } finally {
      if (mounted) {
        setState(() {
          _followLoadingUserIds.remove(userId);
        });
      }
    }
  }

  Future<Set<String>> _determineFollowBackIds(
    List<NotificationItem> notifications,
  ) async {
    final currentUserId = _currentUserId ??= LocalStorage.instance.read('userId');
    if (currentUserId == null || currentUserId.isEmpty) {
      return {};
    }

    final actorIds = notifications
        .map((n) => n.actor.id)
        .where((id) => id.isNotEmpty)
        .toSet();
    if (actorIds.isEmpty) return {};

    final futures = actorIds.map((actorId) async {
      final cached = _followStatusCache[actorId];
      if (cached != null) {
        return MapEntry(actorId, cached);
      }
      final isFollowed = await _isCurrentUserInFollowers(actorId, currentUserId);
      _followStatusCache[actorId] = isFollowed;
      return MapEntry(actorId, isFollowed);
    });

    final results = await Future.wait(futures);
    final followedIds = <String>{};
    for (final entry in results) {
      if (entry.value) {
        followedIds.add(entry.key);
      }
    }
    return followedIds;
  }

  Future<bool> _isCurrentUserInFollowers(String targetUserId, String currentUserId) async {
    int page = 0;
    const int pageSize = 50;
    while (true) {
      try {
        final resp = await ApiService.getFollowers(
          targetUserId,
          page: page,
          pageSize: pageSize,
        );
        if (resp['statusCode'] != 200) {
          return false;
        }
        final body = resp['body'] as Map<String, dynamic>? ?? {};
        final users = (body['users'] as List?) ?? const [];
        final found = users.any((userJson) {
          final id = (userJson['id'] ?? userJson['userId'])?.toString() ?? '';
          return id == currentUserId;
        });
        if (found) return true;
        if (users.length < pageSize) {
          return false;
        }
        page++;
      } catch (_) {
        return false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cardColor = Theme.of(context).cardColor;
    final onSurface = scheme.onSurface;
    final unreadBg = scheme.primary.withOpacity(0.08);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '新增关注',
          style: TextStyle(
            color: onSurface,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading && _notifications.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? const Center(child: Text('暂无通知'))
              : RefreshIndicator(
                  onRefresh: () => _loadNotifications(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemCount: _notifications.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _notifications.length) {
                        _loadNotifications(loadMore: true);
                        return const Center(child: CircularProgressIndicator());
                      }
                      final notification = _notifications[index];
                      final actorId = notification.actor.id;
                      final isAlreadyFollowed =
                          _followedUserIds.contains(actorId) ||
                              (notification.actor.isFollowed ?? false);
                      return _buildFollowerItem(
                        notification: notification,
                        isFollowed: isAlreadyFollowed,
                        isLoading: _followLoadingUserIds.contains(actorId),
                        onFollow: () => _handleFollowBack(notification),
                        onAvatarTap: () {
                          if (!notification.read) {
                            ApiService.markNotificationAsRead(notification.id);
                          }
                          _openUserProfile(actorId);
                        },
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildFollowerItem({
    required NotificationItem notification,
    required bool isFollowed,
    required bool isLoading,
    required VoidCallback onFollow,
    required VoidCallback onAvatarTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final cardColor = Theme.of(context).cardColor;
    final unreadBg = scheme.primary.withOpacity(0.08);
    return GestureDetector(
      onTap: () async {
        // 标记为已读
        if (!notification.read) {
          try {
            await ApiService.markNotificationAsRead(notification.id);
          } catch (e) {
            // 忽略错误
          }
        }
        _openUserProfile(notification.actor.id);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
              color: notification.read ? cardColor : unreadBg,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                  color: Colors.black.withOpacity(0.05),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: onAvatarTap,
              child: CircleAvatar(
                radius: 24,
                backgroundImage: notification.actor.avatar != null
                    ? NetworkImage(notification.actor.avatar!)
                    : null,
                child: notification.actor.avatar == null
                    ? Text(notification.actor.name.isNotEmpty
                        ? notification.actor.name[0].toUpperCase()
                        : '?')
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.actor.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.content,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              children: [
                Text(
                  _formatTime(notification.createdAt),
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: isFollowed || isLoading ? null : onFollow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isFollowed ? Colors.grey[200] : const Color(0xFF1976D2),
                    foregroundColor:
                        isFollowed ? Colors.grey[700] : Colors.white,
                    disabledBackgroundColor: isFollowed
                        ? Colors.grey[200]
                        : const Color(0xFF1976D2),
                    disabledForegroundColor:
                        isFollowed ? Colors.grey[600] : Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 0,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isFollowed ? '已回关' : '回关',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
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
}

// 评论和@页面
class CommentsAndMentionsScreen extends StatefulWidget {
  const CommentsAndMentionsScreen({Key? key}) : super(key: key);

  @override
  State<CommentsAndMentionsScreen> createState() => _CommentsAndMentionsScreenState();
}

class _CommentsAndMentionsScreenState extends State<CommentsAndMentionsScreen> {
  List<NotificationItem> _notifications = [];
  bool _isLoading = true;
  int _page = 0;
  final int _pageSize = 20;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications({bool loadMore = false}) async {
    if (!loadMore) {
      setState(() {
        _isLoading = true;
        _page = 0;
      });
    }

    try {
      final resp = await ApiService.getCommentsAndMentions(page: _page, pageSize: _pageSize);
      if (resp['statusCode'] == 200) {
        final body = resp['body'] as Map<String, dynamic>;
        final notifications = (body['notifications'] as List)
            .map((json) => NotificationItem.fromJson(json))
            .toList();

        setState(() {
          if (loadMore) {
            _notifications.addAll(notifications);
          } else {
            _notifications = notifications;
          }
          _hasMore = notifications.length == _pageSize;
          _page++;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inDays > 0) {
      return '${diff.inDays}天前';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}小时前';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }

  Future<void> _navigateToPostDetail(String postId) async {
    try {
      final resp = await ApiService.getPost(postId);
      if (resp['statusCode'] == 200) {
        final body = resp['body'] as Map<String, dynamic>;
        final post = Post.fromJson(body);
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PostDetailScreen(post: post),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载帖子失败: $e')),
        );
      }
    }
  }

  void _openUserProfile(String userId) {
    if (userId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfilePage(userId: userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: scheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '评论和@',
          style: TextStyle(
            color: scheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading && _notifications.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? const Center(child: Text('暂无通知'))
              : RefreshIndicator(
                  onRefresh: () => _loadNotifications(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemCount: _notifications.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _notifications.length) {
                        _loadNotifications(loadMore: true);
                        return const Center(child: CircularProgressIndicator());
                      }
                      final notification = _notifications[index];
                      return _buildCommentItem(notification: notification);
                    },
                  ),
                ),
    );
  }

  Widget _buildCommentItem({required NotificationItem notification}) {
    final scheme = Theme.of(context).colorScheme;
    final isUnread = !notification.read;
    final cardColor = isUnread ? scheme.primary.withOpacity(0.12) : scheme.surfaceVariant;
    final secondary = scheme.onSurfaceVariant;
    final textColor = scheme.onSurface;
    final chipBg = scheme.surface.withOpacity(0.6);
    final isMention = notification.type == NotificationType.mention;
    final commentContent = notification.comment?.content ?? '';
    return GestureDetector(
      onTap: () async {
        // 标记为已读
        if (!notification.read) {
          try {
            await ApiService.markNotificationAsRead(notification.id);
          } catch (e) {
            // 忽略错误
          }
        }
        // 跳转到帖子详情
        if (notification.post != null) {
          _navigateToPostDetail(notification.post!.id);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (!notification.read) {
                      ApiService.markNotificationAsRead(notification.id);
                    }
                    _openUserProfile(notification.actor.id);
                  },
                  child: CircleAvatar(
                    radius: 16,
                    backgroundImage: notification.actor.avatar != null
                        ? NetworkImage(notification.actor.avatar!)
                        : null,
                    child: notification.actor.avatar == null
                        ? Text(
                            notification.actor.name.isNotEmpty
                                ? notification.actor.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(color: scheme.onPrimaryContainer),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  notification.actor.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: textColor,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatTime(notification.createdAt),
                  style: TextStyle(
                    color: secondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              commentContent.isNotEmpty ? commentContent : notification.content,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: textColor,
              ),
            ),
            if (notification.post != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      isMention ? Icons.alternate_email : Icons.chat_bubble_outline,
                      color: secondary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        notification.post!.title,
                        style: TextStyle(
                          color: secondary,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// 临时占位的发现页面
class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('发现'),
        backgroundColor: Colors.white,
      ),
      body: const Center(
        child: Text('发现页面开发中...'),
      ),
    );
  }
}

class MessageScreen extends StatefulWidget {
  const MessageScreen({Key? key}) : super(key: key);

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();
  List<Conversation> _filteredConversations = [];
  bool _isSearching = false;
  int _currentIndex = 1; // 默认选中消息页面
  UnreadCount _unreadCount = UnreadCount(likes: 0, follows: 0, comments: 0);
  int _totalUnreadMessages = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadUnreadCount();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _loadUnreadCount() async {
    try {
      final resp = await ApiService.getUnreadNotificationCount();
      if (resp['statusCode'] == 200) {
        final body = resp['body'] as Map<String, dynamic>;
        setState(() {
          _unreadCount = UnreadCount.fromJson(body);
        });
        UnreadService.instance.updateNotificationUnread(_unreadCount);
      }
    } catch (e) {
      // 忽略错误
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await _chatService.loadConversations();
    if (!mounted) return;
    _updateConversationState();
  }

  void _updateConversationState() {
    if (!mounted) return;
    setState(() {
      _filteredConversations = _chatService.conversations;
      _totalUnreadMessages = _chatService.conversations.fold<int>(
        0,
        (sum, c) => sum + c.unreadCount,
      );
    });
    UnreadService.instance.updateChatUnread(_totalUnreadMessages);
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    setState(() {
      _isSearching = query.isNotEmpty;
      _filteredConversations = _chatService.searchConversations(query);
    });
  }

  void _onConversationTap(Conversation conversation) async {
    // 标记为已读
    await _chatService.markAsRead(conversation.id);
    _updateConversationState();

    // 导航到聊天页面
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(conversation: conversation),
      ),
    ).then((_) {
      // 返回时刷新数据
      _loadData();
    });
  }

  Future<void> _onRefresh() async {
    await _loadData();
    await _loadUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(scheme),
      body: SafeArea(
        child: Column(
          children: [
            // 小红书风格的顶部图标导航
            _buildTopIconNavigation(scheme),
            Expanded(
              child: _buildConversationList(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(scheme),
    );
  }

  PreferredSizeWidget _buildAppBar(ColorScheme scheme) {
    return AppBar(
      backgroundColor: scheme.surface,
      elevation: 0,
      title: Text(
        '消息',
        style: TextStyle(
          color: scheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(Icons.search, color: scheme.onSurface),
          onPressed: _showSearch,
        ),
      ],
    );
  }

  // 小红书风格的顶部图标导航
  Widget _buildTopIconNavigation(ColorScheme scheme) {
    return Container(
      color: scheme.surface,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTopNavItem(
            icon: Icons.favorite,
            activeIcon: Icons.favorite,
            label: '赞和收藏',
            badgeCount: _unreadCount.likes,
            backgroundColor: scheme.errorContainer.withOpacity(0.5),
            iconColor: scheme.error,
            onTap: () {
              _navigateToLikesAndFavorites();
              _loadUnreadCount(); // 刷新未读数量
            },
          ),
          _buildTopNavItem(
            icon: Icons.person_add,
            activeIcon: Icons.person_add,
            label: '新增关注',
            badgeCount: _unreadCount.follows,
            backgroundColor: scheme.primaryContainer.withOpacity(0.5),
            iconColor: scheme.primary,
            onTap: () {
              _navigateToNewFollowers();
              _loadUnreadCount(); // 刷新未读数量
            },
          ),
          _buildTopNavItem(
            icon: Icons.chat_bubble,
            activeIcon: Icons.chat_bubble,
            label: '评论和@',
            badgeCount: _unreadCount.comments,
            backgroundColor: scheme.secondaryContainer.withOpacity(0.5),
            iconColor: scheme.secondary,
            onTap: () {
              _navigateToCommentsAndMentions();
              _loadUnreadCount(); // 刷新未读数量
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTopNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required VoidCallback onTap,
    int badgeCount = 0,
    Color? backgroundColor,
    Color? iconColor,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: backgroundColor ?? scheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Icon(
                  icon,
                  color: iconColor ?? scheme.onSurface,
                  size: 24,
                ),
              ),
              if (badgeCount > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      badgeCount > 99 ? '99+' : badgeCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  // 底部导航栏 - 根据home_screen的逻辑重写
  Widget _buildBottomNavigationBar(ColorScheme scheme) {
    return AnimatedBuilder(
      animation: UnreadService.instance,
      builder: (context, _) {
        final badge = UnreadService.instance.totalMessageBadge;
        return BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onBottomNavItemTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: scheme.surface,
          selectedItemColor: scheme.primary,
          unselectedItemColor: scheme.onSurfaceVariant,
          selectedLabelStyle: const TextStyle(fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: '首页',
            ),
            BottomNavigationBarItem(
              icon: _buildMessageNavIcon(false, badge),
              activeIcon: _buildMessageNavIcon(true, badge),
              label: '消息',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.add_circle_outline),
              activeIcon: Icon(Icons.add_circle),
              label: '发布',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: '我的',
            ),
          ],
        );
      },
    );
  }

  void _onBottomNavItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });

    // 根据home_screen的逻辑处理导航
    if (index == 0) {
      // 首页
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
          transitionDuration: Duration.zero,
        ),
      ).then((_) {
        // 当从首页返回时，恢复消息页面高亮
        setState(() {
          _currentIndex = 1;
        });
      });
    } else if (index == 2) {
      // 发布
      Navigator.of(context)
          .push(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const NoteEditorPage(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
              transitionDuration: Duration.zero,
            ),
          )
          .then((_) {
            setState(() {
              _currentIndex = 1;
            });
          });
    } else if (index == 3) {
      // 我的
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const ProfilePage(isMainPage: true),
          transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
          transitionDuration: Duration.zero,
        ),
      ).then((_) {
        // 当从个人页面返回时，恢复消息页面高亮
        setState(() {
          _currentIndex = 1;
        });
      });
    }
    // index == 1 是当前消息页面，不需要处理
  }

  Widget _buildMessageNavIcon(bool active, int badgeCount) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(active ? Icons.chat_bubble : Icons.chat_bubble_outline),
        if (badgeCount > 0)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
              child: Text(
                badgeCount > 99 ? '99+' : badgeCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildConversationList() {
    if (_chatService.isLoadingConversations) {
      return _buildLoadingView();
    }

    if (_filteredConversations.isEmpty) {
      return _buildEmptyView();
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: const Color(0xFF1976D2),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _filteredConversations.length,
        separatorBuilder: (context, index) => const SizedBox(height: 1),
        itemBuilder: (context, index) {
          return ConversationItem(
            conversation: _filteredConversations[index],
            onTap: () => _onConversationTap(_filteredConversations[index]),
          );
        },
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1976D2)),
            strokeWidth: 2,
          ),
          SizedBox(height: 16),
          Text(
            '加载中...',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.message_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _isSearching ? '没有找到相关聊天' : '暂无聊天记录',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isSearching ? '尝试其他关键词' : '开始与同学聊天吧',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // 顶部图标导航的点击处理方法 - 修改为实际跳转
  void _navigateToLikesAndFavorites() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LikesAndFavoritesScreen()),
    ).then((_) async {
      // 返回时批量标记为已读并刷新未读数量
      try {
        await ApiService.markAllNotificationsAsReadByTypes([
          'POST_LIKE',
          'POST_FAVORITE',
          'COMMENT_LIKE',
        ]);
      } catch (e) {
        // 忽略错误
      }
      _loadUnreadCount();
    });
  }

  void _navigateToNewFollowers() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NewFollowersScreen()),
    ).then((_) async {
      // 返回时批量标记为已读并刷新未读数量
      try {
        await ApiService.markAllNotificationsAsReadByTypes([
          'FOLLOW',
        ]);
      } catch (e) {
        // 忽略错误
      }
      _loadUnreadCount();
    });
  }

  void _navigateToCommentsAndMentions() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CommentsAndMentionsScreen()),
    ).then((_) async {
      // 返回时批量标记为已读并刷新未读数量
      try {
        await ApiService.markAllNotificationsAsReadByTypes([
          'COMMENT',
          'MENTION',
        ]);
      } catch (e) {
        // 忽略错误
      }
      _loadUnreadCount();
    });
  }

  void _showSearch() {
    // 显示搜索对话框
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('搜索聊天记录'),
        content: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: '输入关键词搜索...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // 搜索逻辑已经在 _onSearchChanged 中处理
            },
            child: const Text('搜索'),
          ),
        ],
      ),
    );
  }
}