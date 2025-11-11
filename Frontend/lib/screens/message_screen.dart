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
import '../services/chat_service.dart';
import '../widgets/conversation_item.dart';
import 'chat_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

// 赞和收藏页面
class LikesAndFavoritesScreen extends StatelessWidget {
  const LikesAndFavoritesScreen({Key? key}) : super(key: key);

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
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          _buildNotificationItem(
            avatar: 'https://via.placeholder.com/40',
            title: '张三',
            subtitle: '赞了你的笔记《机器学习入门指南》',
            time: '2小时前',
            icon: Icons.favorite,
            iconColor: Colors.red,
          ),
          _buildNotificationItem(
            avatar: 'https://via.placeholder.com/40',
            title: '李四',
            subtitle: '收藏了你的笔记《Flutter开发技巧》',
            time: '5小时前',
            icon: Icons.bookmark,
            iconColor: Colors.blue,
          ),
          _buildNotificationItem(
            avatar: 'https://via.placeholder.com/40',
            title: '王五',
            subtitle: '赞了你的评论',
            time: '昨天',
            icon: Icons.favorite,
            iconColor: Colors.red,
          ),
          _buildNotificationItem(
            avatar: 'https://via.placeholder.com/40',
            title: '赵六',
            subtitle: '收藏了你的笔记《Dart编程语言》',
            time: '2天前',
            icon: Icons.bookmark,
            iconColor: Colors.blue,
          ),
          _buildNotificationItem(
            avatar: 'https://via.placeholder.com/40',
            title: '陈七',
            subtitle: '赞了你的笔记《算法与数据结构》',
            time: '3天前',
            icon: Icons.favorite,
            iconColor: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem({
    required String avatar,
    required String title,
    required String subtitle,
    required String time,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
            backgroundImage: NetworkImage(avatar),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
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
                time,
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
    );
  }
}

// 新增关注页面
class NewFollowersScreen extends StatelessWidget {
  const NewFollowersScreen({Key? key}) : super(key: key);

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
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          _buildFollowerItem(
            avatar: 'https://via.placeholder.com/40',
            name: '张三',
            bio: '机器学习爱好者 | 分享AI技术',
            time: '刚刚',
            isMutual: true,
          ),
          _buildFollowerItem(
            avatar: 'https://via.placeholder.com/40',
            name: '李四',
            bio: 'Flutter开发者 | 移动端架构师',
            time: '1小时前',
            isMutual: false,
          ),
          _buildFollowerItem(
            avatar: 'https://via.placeholder.com/40',
            name: '王五',
            bio: '产品设计师 | 用户体验研究者',
            time: '3小时前',
            isMutual: true,
          ),
          _buildFollowerItem(
            avatar: 'https://via.placeholder.com/40',
            name: '赵六',
            bio: '全栈工程师 | 技术博客作者',
            time: '昨天',
            isMutual: false,
          ),
          _buildFollowerItem(
            avatar: 'https://via.placeholder.com/40',
            name: '陈七',
            bio: '算法工程师 | 数据科学家',
            time: '2天前',
            isMutual: true,
          ),
        ],
      ),
    );
  }

  Widget _buildFollowerItem({
    required String avatar,
    required String name,
    required String bio,
    required String time,
    required bool isMutual,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
            backgroundImage: NetworkImage(avatar),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  bio,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (isMutual) ...[
                  const SizedBox(height: 4),
                  Text(
                    '互相关注',
                    style: TextStyle(
                      color: Colors.green[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              Text(
                time,
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
    );
  }
}

// 评论和@页面
class CommentsAndMentionsScreen extends StatelessWidget {
  const CommentsAndMentionsScreen({Key? key}) : super(key: key);

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
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          _buildCommentItem(
            avatar: 'https://via.placeholder.com/40',
            name: '张三',
            content: '这篇笔记写得太好了！特别是关于机器学习基础的部分，对我帮助很大。',
            postTitle: '机器学习入门指南',
            time: '30分钟前',
            isMention: false,
          ),
          _buildCommentItem(
            avatar: 'https://via.placeholder.com/40',
            name: '李四',
            content: '@小明 你之前问的关于Flutter状态管理的问题，可以看看这个实现',
            postTitle: 'Flutter开发技巧',
            time: '2小时前',
            isMention: true,
          ),
          _buildCommentItem(
            avatar: 'https://via.placeholder.com/40',
            name: '王五',
            content: '感谢分享！请问这个项目有GitHub地址吗？想学习一下源码。',
            postTitle: '开源项目推荐',
            time: '5小时前',
            isMention: false,
          ),
          _buildCommentItem(
            avatar: 'https://via.placeholder.com/40',
            name: '赵六',
            content: '@所有人 这个周末有技术分享会，欢迎大家参加！',
            postTitle: '技术交流活动',
            time: '昨天',
            isMention: true,
          ),
          _buildCommentItem(
            avatar: 'https://via.placeholder.com/40',
            name: '陈七',
            content: '写得非常详细，解决了困扰我很久的问题，点赞！',
            postTitle: 'Dart编程语言',
            time: '2天前',
            isMention: false,
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem({
    required String avatar,
    required String name,
    required String content,
    required String postTitle,
    required String time,
    required bool isMention,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
                backgroundImage: NetworkImage(avatar),
              ),
              const SizedBox(width: 8),
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Text(
                time,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
            ),
          ),
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
                    postTitle,
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
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text(
                  '回复',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text(
                  '删除',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
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

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_onSearchChanged);
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
            onTap: () => _navigateToLikesAndFavorites(),
          ),
          _buildTopNavItem(
            icon: Icons.person_add_outlined,
            activeIcon: Icons.person_add,
            label: '新增关注',
            onTap: () => _navigateToNewFollowers(),
          ),
          _buildTopNavItem(
            icon: Icons.chat_bubble_outline,
            activeIcon: Icons.chat_bubble,
            label: '评论和@',
            onTap: () => _navigateToCommentsAndMentions(),
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
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
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