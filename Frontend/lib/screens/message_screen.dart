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
import '../widgets/conversation_item.dart';
import 'chat_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'post_detail_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '赞和收藏',
          style: TextStyle(
            color: Colors.black87,
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
          color: notification.read ? Colors.white : Colors.blue[50],
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
            CircleAvatar(
              radius: 20,
              backgroundImage: notification.actor.avatar != null
                  ? NetworkImage(notification.actor.avatar!)
                  : null,
              child: notification.actor.avatar == null
                  ? Text(notification.actor.name.isNotEmpty
                      ? notification.actor.name[0].toUpperCase()
                      : '?')
                  : null,
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
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.content,
                    style: TextStyle(
                      color: Colors.grey[600],
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
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Icon(icon, color: iconColor, size: 16),
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
      final resp = await ApiService.getFollows(page: _page, pageSize: _pageSize);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '新增关注',
          style: TextStyle(
            color: Colors.black87,
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
                      return _buildFollowerItem(notification: notification);
                    },
                  ),
                ),
    );
  }

  Widget _buildFollowerItem({required NotificationItem notification}) {
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
        // 可以跳转到用户主页
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: notification.read ? Colors.white : Colors.blue[50],
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
            CircleAvatar(
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1976D2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    '回关',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '评论和@',
          style: TextStyle(
            color: Colors.black87,
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
          color: notification.read ? Colors.white : Colors.blue[50],
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
                CircleAvatar(
                  radius: 16,
                  backgroundImage: notification.actor.avatar != null
                      ? NetworkImage(notification.actor.avatar!)
                      : null,
                  child: notification.actor.avatar == null
                      ? Text(notification.actor.name.isNotEmpty
                          ? notification.actor.name[0].toUpperCase()
                          : '?')
                      : null,
                ),
                const SizedBox(width: 8),
                Text(
                  notification.actor.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatTime(notification.createdAt),
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              commentContent.isNotEmpty ? commentContent : notification.content,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
              ),
            ),
            if (notification.post != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      isMention ? Icons.alternate_email : Icons.chat_bubble_outline,
                      color: Colors.grey[500],
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        notification.post!.title,
                        style: TextStyle(
                          color: Colors.grey[600],
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
    setState(() {
      _filteredConversations = _chatService.conversations;
    });
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
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            // 小红书风格的顶部图标导航
            _buildTopIconNavigation(),
            Expanded(
              child: _buildConversationList(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: const Text(
        '消息',
        style: TextStyle(
          color: Colors.black87,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.black87),
          onPressed: _showSearch,
        ),
      ],
    );
  }

  // 小红书风格的顶部图标导航
  Widget _buildTopIconNavigation() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTopNavItem(
            icon: Icons.favorite_border,
            activeIcon: Icons.favorite,
            label: '赞和收藏',
            badgeCount: _unreadCount.likes,
            onTap: () {
              _navigateToLikesAndFavorites();
              _loadUnreadCount(); // 刷新未读数量
            },
          ),
          _buildTopNavItem(
            icon: Icons.person_add_outlined,
            activeIcon: Icons.person_add,
            label: '新增关注',
            badgeCount: _unreadCount.follows,
            onTap: () {
              _navigateToNewFollowers();
              _loadUnreadCount(); // 刷新未读数量
            },
          ),
          _buildTopNavItem(
            icon: Icons.chat_bubble_outline,
            activeIcon: Icons.chat_bubble,
            label: '评论和@',
            badgeCount: _unreadCount.comments,
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
  }) {
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
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Icon(
                  icon,
                  color: Colors.black87,
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
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // 底部导航栏 - 根据home_screen的逻辑重写
  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: _onBottomNavItemTapped,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF1976D2),
      unselectedItemColor: Colors.grey[600],
      selectedLabelStyle: const TextStyle(fontSize: 12),
      unselectedLabelStyle: const TextStyle(fontSize: 12),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: '首页',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_bubble_outline),
          activeIcon: Icon(Icons.chat_bubble),
          label: '消息',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.explore_outlined),
          activeIcon: Icon(Icons.explore),
          label: '发现',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: '我的',
        ),
      ],
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
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      ).then((_) {
        // 当从首页返回时，恢复消息页面高亮
        setState(() {
          _currentIndex = 1;
        });
      });
    } else if (index == 2) {
      // 发现
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const DiscoverScreen()),
      ).then((_) {
        // 当从发现页面返回时，恢复消息页面高亮
        setState(() {
          _currentIndex = 1;
        });
      });
    } else if (index == 3) {
      // 我的
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ProfilePage()),
      ).then((_) {
        // 当从个人页面返回时，恢复消息页面高亮
        setState(() {
          _currentIndex = 1;
        });
      });
    }
    // index == 1 是当前消息页面，不需要处理
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
    );
  }

  void _navigateToNewFollowers() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NewFollowersScreen()),
    );
  }

  void _navigateToCommentsAndMentions() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CommentsAndMentionsScreen()),
    );
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