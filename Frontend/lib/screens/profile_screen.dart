import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/post_model.dart';
import '../models/user_profile.dart';
import 'admin_mode_screen.dart';
import '../models/user_summary.dart';
import '../pages/login_page.dart';
import '../pages/note_editor_page.dart';
import '../services/api_service.dart';
import '../services/local_storage.dart';
import '../services/chat_service.dart';
import '../services/browse_history_service.dart';
import '../widgets/bottom_navigation.dart';
import '../widgets/post_card.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'home_screen.dart';
import 'message_screen.dart';
import 'post_detail_screen.dart';
import 'chat_screen.dart';
import 'follow_list_screen.dart';
import 'privacy_settings_screen.dart';

class ProfilePage extends StatefulWidget {
  final String? userId;
  /// 是否作为主页面显示（显示底部导航栏和菜单按钮）
  final bool isMainPage;
  
  const ProfilePage({
    super.key, 
    this.userId,
    this.isMainPage = false,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with TickerProviderStateMixin {
  int _currentIndex = 3;
  UserProfile? _profile;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _currentUserId;
  bool? _isFollowing;
  List<Post> _authoredPosts = [];
  List<Post> _favoritePosts = [];
  bool _loadingAuthored = false;
  bool _loadingFavorites = false;
  bool _hasMoreAuthored = true;
  bool _hasMoreFavorites = true;
  int _authoredPage = 1;
  int _favoritesPage = 1;

  final Set<String> _likeInFlight = {};

  @override
  void initState() {
    super.initState();
    _currentUserId = LocalStorage.instance.read('userId');
    _loadProfile();
  }

  bool get _isViewingSelf {
    if (widget.userId == null) return true;
    if (_currentUserId == null) return false;
    return widget.userId == _currentUserId;
  }

  Future<void> _loadProfile({bool forceNetwork = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      Map<String, dynamic>? payload;

      if (_isViewingSelf && !forceNetwork) {
        final cached = LocalStorage.instance.read('currentUser');
        if (cached != null) {
          payload = jsonDecode(cached) as Map<String, dynamic>;
        }
      }

      if (payload == null) {
        final resp = widget.userId == null
            ? await ApiService.getCurrentUserProfile()
            : await ApiService.getUserProfile(widget.userId!);
        if (resp['statusCode'] != 200) {
          final message =
              (resp['body'] as Map<String, dynamic>?)?['message'] ?? '加载失败';
          throw Exception(message);
        }
        payload = resp['body'] as Map<String, dynamic>;
        if (_isViewingSelf) {
          await LocalStorage.instance.write('currentUser', jsonEncode(payload));
          final id = payload['id'];
          if (id != null) {
            await LocalStorage.instance.write('userId', id.toString());
            _currentUserId = id.toString();
          }
        }
      }

      setState(() {
        _profile = UserProfile.fromJson(payload!);
        _isFollowing = _profile!.isFollowing;
        _loading = false;
      });
      // 根据隐私设置决定是否加载收藏列表
      await Future.wait([
        _loadUserPosts(refresh: true),
        if (_canViewFavorites) _loadFavoritePosts(refresh: true),
      ]);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _handleRefresh() => _loadProfile(forceNetwork: true);

  bool get _canViewFavorites {
    if (_profile == null) return false;
    // 自己总是可以看到自己的收藏
    if (_isViewingSelf) return true;
    // 查看他人主页时，只有对方公开收藏才可以看到
    return _profile!.publicFavorites;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // 上面已经完整实现了 `_openBrowseHistory`，下面重复的几份定义是合并冲突遗留，需要删除。

  Future<void> _openBrowseHistory() async {
    final userId = _currentUserId ?? LocalStorage.instance.read('userId');
    if (userId == null || userId.isEmpty) {
      _showSnack('未登录，无法查看浏览历史');
      return;
    }

    final history = await BrowseHistoryService.getHistory(userId);
    if (!mounted) return;

    if (history.isEmpty) {
      _showSnack('暂无浏览历史');
      return;
    }

    // 先根据历史记录批量拉取帖子详情，构造 Post 列表用于 PostCard 展示
    final List<Post> posts = [];
    for (final item in history) {
      try {
        final resp = await ApiService.getPost(item.postId);
        final status = resp['statusCode'] as int? ?? 500;
        if (status == 200) {
          final body = resp['body'] as Map<String, dynamic>;
          posts.add(Post.fromJson(body));
        } else if (status == 404) {
          // 帖子不存在时，顺便清理这条历史
          await BrowseHistoryService.removeByPostId(userId, item.postId);
        }
      } catch (_) {
        // 忽略单条失败，继续加载其他帖子
      }
    }

    if (!mounted) return;

    if (posts.isEmpty) {
      _showSnack('浏览的帖子都已不存在或加载失败');
      return;
    }

    final rootContext = context; // Store the context before the async gap.

    await showModalBottomSheet(
      context: rootContext,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '浏览历史',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          await BrowseHistoryService.clearHistory(userId);
                          Navigator.of(sheetContext).pop();
                          // Check for mounted again after async operation
                          if (mounted) {
                            _showSnack('浏览历史已清空');
                          }
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('清空'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: MasonryGridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 3,
                    mainAxisSpacing: 3,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                    itemCount: posts.length,
                    itemBuilder: (ctx, index) {
                      final post = posts[index];
                      return PostCard(
                        post: post,
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          // 使用外层 context 打开详情，避免使用已销毁的上下文
                          _openPostDetail(post);
                        },
                        onAuthorTap: () {
                          if (post.author.id != _currentUserId) {
                            Navigator.of(sheetContext).pop();
                            Navigator.of(rootContext)
                                .pushNamed('/user/${post.author.id}');
                          }
                        },
                        onLikeTap: _handlePostLike,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAvatarViewer(String? avatar) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image(
                  image: _resolveAvatar(avatar),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 20,
              left: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAvatarDirectly() async {
    if (!_isViewingSelf || _profile == null) return;
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1024,
    );
    if (picked == null) return;

    final ext = picked.name.split('.').last.toLowerCase();
    const allowed = ['png', 'jpg', 'jpeg', 'gif', 'webp'];
    if (!allowed.contains(ext)) {
      _showSnack('仅支持 png/jpg/jpeg/gif/webp 格式');
      return;
    }

    setState(() => _saving = true);
    try {
      final bytes = await picked.readAsBytes();
      final uploadResp = await ApiService.uploadAvatarBytes(
        bytes,
        picked.name,
      );
      if (uploadResp['statusCode'] != 200) {
        final message =
            (uploadResp['body'] as Map<String, dynamic>?)?['message'] ?? '头像上传失败';
        throw Exception(message);
      }
      final body = uploadResp['body'] as Map<String, dynamic>;
      final avatarUrl = (body['url'] ?? body['avatar'])?.toString();

      final resp = await ApiService.updateProfile(
        displayName: _profile!.displayName,
        bio: _profile!.bio,
        researchDirections: _profile!.researchDirections,
        avatarUrl: avatarUrl,
      );
      if (resp['statusCode'] != 200) {
        final message =
            (resp['body'] as Map<String, dynamic>?)?['message'] ?? '保存失败';
        throw Exception(message);
      }
      await _loadProfile(forceNetwork: true);
      _showSnack('头像已更新');
    } catch (e) {
      _showSnack('上传失败：$e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showBackgroundViewer(String? background) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image(
                  image: _resolveBackground(background),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            if (_isViewingSelf)
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: FloatingActionButton.extended(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _pickBackgroundDirectly();
                    },
                    backgroundColor: Colors.white.withOpacity(0.9),
                    icon: const Icon(Icons.image, color: Colors.black87),
                    label: const Text(
                      '更换背景图',
                      style: TextStyle(color: Colors.black87),
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 20,
              left: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickBackgroundDirectly() async {
    if (!_isViewingSelf || _profile == null) return;
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (picked == null) return;
    final ext = picked.name.split('.').last.toLowerCase();
    const allowed = ['png', 'jpg', 'jpeg', 'gif', 'webp'];
    if (!allowed.contains(ext)) {
      _showSnack('仅支持 png/jpg/jpeg/gif/webp 格式');
      return;
    }

    setState(() => _saving = true);
    try {
      final bytes = await picked.readAsBytes();
      final uploadResp = await ApiService.uploadBackgroundBytes(
        bytes,
        picked.name,
      );
      if (uploadResp['statusCode'] != 200) {
        final message =
            (uploadResp['body'] as Map<String, dynamic>?)?['message'] ??
            '背景图上传失败';
        throw Exception(message);
      }
      final body = uploadResp['body'] as Map<String, dynamic>;
      final backgroundUrl = (body['url'] ?? body['background'])?.toString();

      final resp = await ApiService.updateProfile(
        displayName: _profile!.displayName,
        bio: _profile!.bio,
        researchDirections: _profile!.researchDirections,
        backgroundImage: backgroundUrl,
      );
      if (resp['statusCode'] != 200) {
        final message =
            (resp['body'] as Map<String, dynamic>?)?['message'] ?? '保存失败';
        throw Exception(message);
      }
      await _loadProfile(forceNetwork: true);
      _showSnack('背景图已更新');
    } catch (e) {
      _showSnack('上传失败：$e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _openEditProfileSheet() async {
    if (!_isViewingSelf || _profile == null) return;
    final result = await showModalBottomSheet<_ProfileEditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProfileEditSheet(profile: _profile!),
    );

    if (result != null) {
      await _submitProfileChanges(result);
    }
  }

  Future<void> _openDirectionsSheet() async {
    if (!_isViewingSelf || _profile == null) return;
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _DirectionsEditSheet(directions: _profile!.researchDirections),
    );
    if (result != null) {
      await _submitDirectionChanges(result);
    }
  }

  Future<void> _openFollowList(bool showFollowers, {bool mutual = false}) async {
    if (_profile == null) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FollowListScreen(
          userId: _profile!.id,
          initialTab: mutual ? 'mutual' : (showFollowers ? 'followers' : 'following'),
        ),
      ),
    );
    if (changed == true) {
      await _loadProfile(forceNetwork: true);
    }
  }

  Future<void> _toggleFollow() async {
    if (_profile == null || _isViewingSelf || _profile!.id.isEmpty) return;
    final targetId = _profile!.id;
    final originalFollowers = _profile!.followersCount;
    final prev = _isFollowing ?? false;
    final next = !prev;
    setState(() {
      final updated = next
          ? originalFollowers + 1
          : (originalFollowers > 0 ? originalFollowers - 1 : 0);
      _isFollowing = next;
      _profile = _profile!.copyWith(followersCount: updated, isFollowing: next);
    });
    try {
      final resp = next
          ? await ApiService.followUser(targetId)
          : await ApiService.unfollowUser(targetId);
      if (resp['statusCode'] != 200) {
        throw Exception(
          (resp['body'] as Map<String, dynamic>?)?['message'] ?? '操作失败',
        );
      }
    } catch (e) {
      setState(() {
        final restored = originalFollowers;
        _isFollowing = prev;
        _profile = _profile!.copyWith(
          followersCount: restored,
          isFollowing: prev,
        );
      });
      _showSnack('操作失败：$e');
    }
  }

  void _startPrivateChat() {
    if (_profile == null || _isViewingSelf) return;

    final targetUserId = _profile!.id;

    // Show loading indicator
    setState(() {
      _saving = true;
    });

    ChatService().createOrGetPrivateConversation(targetUserId).then((conversation) {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }

      if (conversation != null) {
        // Navigate to chat interface with the full conversation object
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChatScreen(conversation: conversation),
          ),
        );
      } else {
        _showSnack('创建会话失败，请稍后重试');
      }
    }).catchError((error) {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
      _showSnack('创建会话失败：$error');
    });
  }

  void _openPostDetail(Post post) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
    ).then((result) {
      if (result == true) {
        setState(() {
          _authoredPosts.removeWhere((p) => p.id == post.id);
          _favoritePosts.removeWhere((p) => p.id == post.id);
        });
        return;
      }
      _loadProfile(forceNetwork: true);
    });
  }

  Future<void> _submitDirectionChanges(List<String> directions) async {
    setState(() => _saving = true);
    try {
      final resp = await ApiService.updateProfile(
        displayName: _profile!.displayName,
        researchDirections: directions,
      );
      if (resp['statusCode'] != 200) {
        final message =
            (resp['body'] as Map<String, dynamic>?)?['message'] ?? '保存失败';
        throw Exception(message);
      }
      await _loadProfile(forceNetwork: true);
      _showSnack('研究方向已更新');
    } catch (e) {
      _showSnack('更新失败：$e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _submitProfileChanges(_ProfileEditResult result) async {
    setState(() => _saving = true);
    try {
      final avatarUrl = await _uploadAvatarIfNeeded(result);
      final backgroundUrl = await _uploadBackgroundIfNeeded(result);
      final resp = await ApiService.updateProfile(
        displayName: result.displayName,
        bio: result.bio,
        researchDirections: result.researchDirections,
        avatarUrl: avatarUrl,
        backgroundImage: backgroundUrl,
      );
      if (resp['statusCode'] != 200) {
        final message =
            (resp['body'] as Map<String, dynamic>?)?['message'] ?? '保存失败';
        throw Exception(message);
      }
      await _loadProfile(forceNetwork: true);
      _showSnack('资料已更新');
    } catch (e) {
      _showSnack('保存失败：$e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _loadUserPosts({bool refresh = false}) async {
    if (_profile == null) return;
    if (_loadingAuthored) return;
    setState(() {
      _loadingAuthored = true;
      if (refresh) {
        _authoredPage = 1;
        _hasMoreAuthored = true;
        _authoredPosts = [];
      }
    });
    final page = refresh ? 1 : _authoredPage;
    try {
      final resp = await ApiService.getUserPosts(
        _profile!.id,
        page: page,
        pageSize: 10,
      );
      if (resp['statusCode'] == 200) {
        final body = resp['body'] as Map<String, dynamic>?;
        final data = (body?['posts'] as List<dynamic>?) ?? [];
        final total = body?['total'] as int? ?? data.length;
        final newPosts = data
            .map((item) => Post.fromJson(item as Map<String, dynamic>))
            .toList();
        setState(() {
          if (refresh) {
            _authoredPosts = newPosts;
          } else {
            _authoredPosts.addAll(newPosts);
          }
          _hasMoreAuthored = _authoredPosts.length < total;
          _authoredPage = page + 1;
        });
      }
    } catch (e) {
      _showSnack('加载我的笔记失败：$e');
    } finally {
      if (mounted) {
        setState(() => _loadingAuthored = false);
      }
    }
  }

  Future<void> _loadFavoritePosts({bool refresh = false}) async {
    if (_profile == null) return;
    // 如果正在查看他人主页且对方未公开收藏，则不加载收藏
    if (!_isViewingSelf && !_canViewFavorites) return;
    if (_loadingFavorites) return;
    setState(() {
      _loadingFavorites = true;
      if (refresh) {
        _favoritesPage = 1;
        _hasMoreFavorites = true;
        _favoritePosts = [];
      }
    });
    final page = refresh ? 1 : _favoritesPage;
    try {
      final resp = await ApiService.getUserFavorites(
        _profile!.id,
        page: page,
        pageSize: 10,
      );
      if (resp['statusCode'] == 200) {
        final body = resp['body'] as Map<String, dynamic>?;
        final data = (body?['posts'] as List<dynamic>?) ?? [];
        final total = body?['total'] as int? ?? data.length;
        final newPosts = data
            .map((item) => Post.fromJson(item as Map<String, dynamic>))
            .toList();
        setState(() {
          if (refresh) {
            _favoritePosts = newPosts;
          } else {
            _favoritePosts.addAll(newPosts);
          }
          _hasMoreFavorites = _favoritePosts.length < total;
          _favoritesPage = page + 1;
        });
      }
    } catch (e) {
      _showSnack('加载收藏失败：$e');
    } finally {
      if (mounted) {
        setState(() => _loadingFavorites = false);
      }
    }
  }

  Future<String?> _uploadAvatarIfNeeded(_ProfileEditResult result) async {
    if (result.avatarBytes == null || result.avatarBytes!.isEmpty) return null;
    final uploadResp = await ApiService.uploadAvatarBytes(
      result.avatarBytes!,
      result.avatarFileName ?? 'avatar.png',
    );
    if (uploadResp['statusCode'] != 200) {
      final message =
          (uploadResp['body'] as Map<String, dynamic>?)?['message'] ?? '头像上传失败';
      throw Exception(message);
    }
    final body = uploadResp['body'] as Map<String, dynamic>;
    return (body['url'] ?? body['avatar'])?.toString();
  }

  Future<String?> _uploadBackgroundIfNeeded(_ProfileEditResult result) async {
    if (result.backgroundBytes == null || result.backgroundBytes!.isEmpty)
      return null;
    final uploadResp = await ApiService.uploadBackgroundBytes(
      result.backgroundBytes!,
      result.backgroundFileName ?? 'background.png',
    );
    if (uploadResp['statusCode'] != 200) {
      final message =
          (uploadResp['body'] as Map<String, dynamic>?)?['message'] ??
          '背景图上传失败';
      throw Exception(message);
    }
    final body = uploadResp['body'] as Map<String, dynamic>;
    return (body['url'] ?? body['background'])?.toString();
  }

  ImageProvider<Object> _resolveAvatar(String? avatar) {
    if (avatar == null || avatar.isEmpty) {
      return const AssetImage('images/DefaultAvatar.png');
    }
    if (avatar.startsWith('http')) {
      return NetworkImage(avatar);
    }
    if (avatar.startsWith('assets/')) {
      return AssetImage(avatar);
    }
    return AssetImage(avatar);
  }

  ImageProvider<Object> _resolveBackground(String? bg) {
    if (bg == null || bg.isEmpty) {
      return const AssetImage('images/profile_bg.jpg');
    }
    if (bg.startsWith('http')) {
      return NetworkImage(bg);
    }
    if (bg.startsWith('assets/')) {
      return AssetImage(bg);
    }
    return AssetImage(bg);
  }

  Drawer? _buildDrawer() {
    if (!_isViewingSelf) return null;
    final hasAdminAccess =
        _profile != null && _profile!.role.toUpperCase() != 'USER';
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            child: Text(
              '菜单',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          if (hasAdminAccess)
            ListTile(
              leading: const Icon(Icons.admin_panel_settings),
              title: const Text('管理员模式'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminModeScreen(role: _profile!.role),
                  ),
                );
              },
            ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('隐私设置'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PrivacySettingsScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('浏览历史'),
            onTap: () async {
              Navigator.pop(context);
              await _openBrowseHistory();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('登出'),
            onTap: () async {
              Navigator.pop(context);
              await ApiService.logout();
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => LoginPage()),
              );
            },
          ),
        ],
      ),
    );
  }

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

        // 更新帖子状态
        final authoredIndex = _authoredPosts.indexWhere((p) => p.id == post.id);
        if (authoredIndex != -1) {
          setState(() {
            _authoredPosts[authoredIndex].likesCount =
                updatedLikesCount ?? _authoredPosts[authoredIndex].likesCount;
            _authoredPosts[authoredIndex].isLiked =
                updatedIsLiked ?? !_authoredPosts[authoredIndex].isLiked;
          });
        }

        final favoriteIndex = _favoritePosts.indexWhere((p) => p.id == post.id);
        if (favoriteIndex != -1) {
          setState(() {
            _favoritePosts[favoriteIndex].likesCount =
                updatedLikesCount ?? _favoritePosts[favoriteIndex].likesCount;
            _favoritePosts[favoriteIndex].isLiked =
                updatedIsLiked ?? !_favoritePosts[favoriteIndex].isLiked;
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        drawer: _buildDrawer(),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        // 只有从底部导航栏进入自己的主页时才显示底部导航栏
        bottomNavigationBar: (_isViewingSelf && widget.isMainPage) 
            ? _buildBottomNavigationBar() 
            : null,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _handleRefresh,
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 12),
                  Text(_error!),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => _loadProfile(forceNetwork: true),
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    if (_profile == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 200, child: Center(child: Text('暂无资料'))),
        ],
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          if (_saving) const LinearProgressIndicator(minHeight: 2),
          _buildHeader(_profile!),
          _buildResearchDirections(_profile!),
          _buildTabsSection(),
        ],
      ),
    );
  }

  Widget _buildHeader(UserProfile profile) {
    return GestureDetector(
      onTap: _isViewingSelf ? () => _showBackgroundViewer(profile.backgroundImage) : null,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          image: DecorationImage(
            image: _resolveBackground(profile.backgroundImage),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.45),
              BlendMode.darken,
            ),
          ),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(
            top: 32,
            bottom: 24,
            left: 20,
            right: 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 左上角：如果是主页面显示菜单按钮，否则显示返回按钮
                  if (_isViewingSelf && widget.isMainPage)
                    Builder(
                      builder: (ctx) => IconButton(
                        icon: const Icon(Icons.menu, color: Colors.white),
                        onPressed: () => Scaffold.of(ctx).openDrawer(),
                      ),
                    )
                  else if (Navigator.canPop(context))
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  else
                    const SizedBox(width: 48), // 占位保持布局一致
                  
                  // 右上角：如果不是主页面但是自己的主页，显示菜单按钮
                  if (_isViewingSelf && !widget.isMainPage && Navigator.canPop(context))
                    Builder(
                      builder: (ctx) => IconButton(
                        icon: const Icon(Icons.menu, color: Colors.white),
                        onPressed: () => Scaffold.of(ctx).openDrawer(),
                      ),
                    ),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => _showAvatarViewer(profile.avatar),
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundImage: _resolveAvatar(profile.avatar),
                        ),
                        if (_isViewingSelf)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _pickAvatarDirectly,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.black87,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.displayName,
                          style: const TextStyle(
                            fontSize: 22,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (profile.bio != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            profile.bio!,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          profile.email,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                        if (profile.statusMessage != null &&
                            profile.statusMessage!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            profile.statusMessage!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_isViewingSelf)
                    IconButton(
                      onPressed: _openEditProfileSheet,
                      icon: const Icon(Icons.edit, color: Colors.white),
                    )
                  else
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: _toggleFollow,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: (_isFollowing ?? false)
                                ? Colors.white.withOpacity(0.2)
                                : Colors.blueAccent,
                            foregroundColor: Colors.white,
                          ),
                          child: Text((_isFollowing ?? false) ? '已关注' : '关注'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _startPrivateChat,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('私聊'),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  // Use theme surface so the card follows dark backgrounds
                  color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatItem(
                      title: '关注',
                      count: profile.followingCount,
                      onTap: () => _openFollowList(false),
                    ),
                    _StatItem(
                      title: '粉丝',
                      count: profile.followersCount,
                      onTap: () => _openFollowList(true),
                    ),
                    _StatItem(
                      title: '被收藏',
                      count: profile.favoritesReceivedCount,
                    ),
                    _StatItem(title: '点赞', count: profile.likesCount),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResearchDirections(UserProfile profile) {
    final directions = profile.researchDirections;
    final scheme = Theme.of(context).colorScheme;
    final cardColor = scheme.surfaceVariant;
    final textColor = scheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '研究方向',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: directions.isEmpty
                ? Text(
                    '还没有填写研究方向',
                    style: TextStyle(color: textColor.withOpacity(0.6)),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: directions.map((d) => _buildDirectionChip(d, scheme)).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionChip(String label, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surface.withOpacity(0.8),
        border: Border.all(color: scheme.primary.withOpacity(0.6), width: 1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(color: scheme.onSurface, fontSize: 14),
      ),
    );
  }

  Widget _buildTabsSection() {
    final scheme = Theme.of(context).colorScheme;
    final cardColor = scheme.surfaceVariant;
    final onSurface = scheme.onSurface;
    final primary = scheme.primary;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          TabBar(
            labelColor: primary,
            unselectedLabelColor: onSurface.withOpacity(0.7),
            indicatorColor: primary,
            tabs: [
              Tab(text: '笔记'),
              Tab(text: '收藏'),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 600,
            child: TabBarView(
              children: [
                _buildPostGridContent(
                  posts: _authoredPosts,
                  isLoading: _loadingAuthored,
                  hasMore: _hasMoreAuthored,
                  loader: _loadUserPosts,
                ),
                _canViewFavorites
                    ? _buildPostGridContent(
                        posts: _favoritePosts,
                        isLoading: _loadingFavorites,
                        hasMore: _hasMoreFavorites,
                        loader: _loadFavoritePosts,
                      )
                    : Center(
                        child: Text(
                          _isViewingSelf
                              ? '你目前未公开收藏给其他用户'
                              : '对方已隐藏收藏',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostGridContent({
    required List<Post> posts,
    required bool isLoading,
    required bool hasMore,
    required Future<void> Function({bool refresh}) loader,
  }) {
    if (posts.isEmpty && !isLoading) {
      return RefreshIndicator(
        onRefresh: () => loader(refresh: true),
        child: ListView(
          children: const [
            SizedBox(height: 180),
            Center(child: Text('暂无数据')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => loader(refresh: true),
      child: MasonryGridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 3,
        mainAxisSpacing: 3,
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        itemCount: posts.length + (hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == posts.length) {
            if (isLoading) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Center(
                child: TextButton.icon(
                  onPressed: () => loader(refresh: false),
                  icon: const Icon(Icons.refresh),
                  label: const Text('加载更多'),
                ),
              ),
            );
          }
          final post = posts[index];
          return PostCard(
            post: post,
            onTap: () => _openPostDetail(post),
            onAuthorTap: () {
              if (post.author.id != _currentUserId) {
                Navigator.of(context).pushNamed('/user/${post.author.id}');
              }
            },
            onLikeTap: _handlePostLike,
          );
        },
      ),
    );
  }

  String _formatPostTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return dt.toLocal().toString().split('.').first;
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigation(
      currentIndex: _currentIndex,
      onTap: (index) {
        setState(() => _currentIndex = index);

        if (index == 0) {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
              transitionDuration: Duration.zero,
            ),
          ).then((_) => setState(() => _currentIndex = 3));
        } else if (index == 1) {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const MessageScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
              transitionDuration: Duration.zero,
            ),
          ).then((_) => setState(() => _currentIndex = 3));
        } else if (index == 2) {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const NoteEditorPage(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
              transitionDuration: Duration.zero,
            ),
          ).then((_) => setState(() => _currentIndex = 0));
        } else if (index == 3) {
          if (!_isViewingSelf) {
            // 从其他页面进入自己的主页，显示为主页面
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => const ProfilePage(isMainPage: true),
                transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
                transitionDuration: Duration.zero,
              ),
            ).then((_) => setState(() => _currentIndex = 3));
          }
          // 如果已经是自己的主页，不做任何操作
        }
      },
      context: context,
    );
  }
}

class _StatItem extends StatelessWidget {
  final String title;
  final int count;
  final VoidCallback? onTap;

  const _StatItem({required this.title, required this.count, this.onTap});

  @override
  Widget build(BuildContext context) {
    final displayCount = count == -1 ? '-' : '$count';
    final content = Column(
      children: [
        Text(
          displayCount,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 5),
        Text(title, style: const TextStyle(color: Colors.grey)),
      ],
    );
    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}

class _PlaceholderList extends StatelessWidget {
  final String label;
  const _PlaceholderList({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '这里显示 $label 内容',
        style: const TextStyle(color: Colors.grey, fontSize: 16),
      ),
    );
  }
}

class _ProfileEditResult {
  final String displayName;
  final String? bio;
  final List<String> researchDirections;
  final Uint8List? avatarBytes;
  final String? avatarFileName;
  final Uint8List? backgroundBytes;
  final String? backgroundFileName;

  _ProfileEditResult({
    required this.displayName,
    required this.researchDirections,
    this.bio,
    this.avatarBytes,
    this.avatarFileName,
    this.backgroundBytes,
    this.backgroundFileName,
  });
}

class _DirectionsEditSheet extends StatefulWidget {
  final List<String> directions;
  const _DirectionsEditSheet({required this.directions});

  @override
  State<_DirectionsEditSheet> createState() => _DirectionsEditSheetState();
}

class _DirectionsEditSheetState extends State<_DirectionsEditSheet> {
  final TextEditingController _controller = TextEditingController();
  late List<String> _directions;

  @override
  void initState() {
    super.initState();
    _directions = [...widget.directions];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addDirection() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (_directions.contains(text)) {
      _controller.clear();
      return;
    }
    setState(() {
      _directions.add(text);
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: bottomInset + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '管理研究方向',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _directions
                .map(
                  (e) => Chip(
                    label: Text(e),
                    onDeleted: () => setState(() {
                      _directions.remove(e);
                    }),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: '新增方向',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _addDirection(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _addDirection, child: const Text('添加')),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(_directions);
              },
              child: const Text('保存标签'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FollowListSheet extends StatefulWidget {
  final String userId;
  final bool showFollowers;

  const _FollowListSheet({required this.userId, required this.showFollowers});

  @override
  State<_FollowListSheet> createState() => _FollowListSheetState();
}

class _FollowListSheetState extends State<_FollowListSheet> {
  List<UserSummary> _users = [];
  bool _loading = false;
  bool _hasMore = true;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _loadPage(refresh: true);
  }

  Future<void> _loadPage({bool refresh = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      if (refresh) {
        _page = 0;
        _users = [];
        _hasMore = true;
      }
    });
    try {
      final resp = widget.showFollowers
          ? await ApiService.getFollowers(
              widget.userId,
              page: _page,
              pageSize: 20,
            )
          : await ApiService.getFollowing(
              widget.userId,
              page: _page,
              pageSize: 20,
            );
      if (resp['statusCode'] == 200) {
        final body = resp['body'] as Map<String, dynamic>?;
        final data = (body?['users'] as List<dynamic>?) ?? [];
        final total = body?['total'] as int? ?? data.length;
        final newUsers = data
            .map((item) => UserSummary.fromJson(item as Map<String, dynamic>))
            .toList();
        setState(() {
          _users.addAll(newUsers);
          _hasMore = _users.length < total;
          _page += 1;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('加载失败：$e')));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.showFollowers ? '粉丝列表' : '关注列表';
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _users.isEmpty && !_hasMore && !_loading
                  ? const Center(child: Text('暂无数据'))
                  : ListView.separated(
                      itemCount: _users.length + (_hasMore ? 1 : 0),
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        if (index == _users.length) {
                          if (_loading) {
                            return const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          }
                          return TextButton.icon(
                            onPressed: _loadPage,
                            icon: const Icon(Icons.refresh),
                            label: const Text('加载更多'),
                          );
                        }
                        final user = _users[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: user.avatar.startsWith('http')
                                ? NetworkImage(user.avatar)
                                : AssetImage(user.avatar) as ImageProvider,
                          ),
                          title: Text(user.displayName),
                          subtitle: user.bio != null
                              ? Text(
                                  user.bio!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          onTap: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).pushNamed('/user/${user.id}');
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileEditSheet extends StatefulWidget {
  final UserProfile profile;
  const _ProfileEditSheet({required this.profile});

  @override
  State<_ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends State<_ProfileEditSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  final TextEditingController _directionController = TextEditingController();
  final FocusNode _directionFocus = FocusNode();
  late List<String> _directions;
  Uint8List? _avatarPreview;
  String? _avatarFileName;
  Uint8List? _backgroundPreview;
  String? _backgroundFileName;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.displayName);
    _bioController = TextEditingController(text: widget.profile.bio ?? '');
    _directions = [...widget.profile.researchDirections];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _directionController.dispose();
    _directionFocus.dispose();
    super.dispose();
  }

  ImageProvider<Object> _initialAvatar() {
    final avatar = widget.profile.avatar;
    if (avatar.startsWith('http')) return NetworkImage(avatar);
    if (avatar.startsWith('assets/')) return AssetImage(avatar);
    return AssetImage(avatar);
  }

  ImageProvider<Object> _initialBackground() {
    final bg = widget.profile.backgroundImage;
    if (bg.startsWith('http')) return NetworkImage(bg);
    if (bg.startsWith('assets/')) return AssetImage(bg);
    return AssetImage(bg);
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1024,
    );
    if (picked == null) return;

    final ext = picked.name.split('.').last.toLowerCase();
    const allowed = ['png', 'jpg', 'jpeg', 'gif', 'webp'];
    if (!allowed.contains(ext)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('仅支持 png/jpg/jpeg/gif/webp 格式')),
      );
      return;
    }

    final bytes = await picked.readAsBytes();
    setState(() {
      _avatarPreview = bytes;
      _avatarFileName = picked.name;
    });
  }

  Future<void> _pickBackground() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (picked == null) return;
    final ext = picked.name.split('.').last.toLowerCase();
    const allowed = ['png', 'jpg', 'jpeg', 'gif', 'webp'];
    if (!allowed.contains(ext)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('仅支持 png/jpg/jpeg/gif/webp 格式')),
      );
      return;
    }
    final bytes = await picked.readAsBytes();
    setState(() {
      _backgroundPreview = bytes;
      _backgroundFileName = picked.name;
    });
  }

  void _addDirection() {
    final value = _directionController.text.trim();
    if (value.isEmpty) return;
    if (_directions.contains(value)) {
      _directionController.clear();
      return;
    }
    setState(() {
      _directions.add(value);
      _directionController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: bottomInset + 20,
        ),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text(
                    '编辑个人资料',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 7 / 3,
                      child: _backgroundPreview != null
                          ? Image.memory(_backgroundPreview!, fit: BoxFit.cover)
                          : Image(
                              image: _initialBackground(),
                              fit: BoxFit.cover,
                            ),
                    ),
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: ElevatedButton.icon(
                        onPressed: _pickBackground,
                        icon: const Icon(Icons.image),
                        label: const Text('更换背景'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundImage: _avatarPreview != null
                          ? MemoryImage(_avatarPreview!)
                          : _initialAvatar(),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        onTap: _pickAvatar,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.black87,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '昵称',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _bioController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '一句话简介',
                  hintText: '介绍一下自己吧',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text('研究方向', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _directions
                    .map(
                      (e) => Chip(
                        label: Text(e),
                        onDeleted: () => setState(() => _directions.remove(e)),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _directionController,
                      focusNode: _directionFocus,
                      decoration: const InputDecoration(
                        hintText: '新增方向',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _addDirection(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _addDirection,
                    child: const Text('添加'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final name = _nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('昵称不能为空')));
                      return;
                    }
                    Navigator.of(context).pop(
                      _ProfileEditResult(
                        displayName: name,
                        bio: _bioController.text.trim().isEmpty
                            ? null
                            : _bioController.text.trim(),
                        researchDirections: _directions,
                        avatarBytes: _avatarPreview,
                        avatarFileName: _avatarFileName,
                        backgroundBytes: _backgroundPreview,
                        backgroundFileName: _backgroundFileName,
                      ),
                    );
                  },
                  child: const Text('保存修改'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
