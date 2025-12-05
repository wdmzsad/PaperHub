// lib/screens/post_detail_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/post_model.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../widgets/pdf_iframe_view.dart';
import '../services/local_storage.dart';
import '../services/browse_history_service.dart';
import '../config/app_env.dart';
import 'profile_screen.dart';
import '../constants/discipline_constants.dart';
import 'zone_screen.dart';
import 'search_results_screen.dart';
import '../services/chat_service.dart';
import '../widgets/report_post_dialog.dart';
import '../models/message_model.dart';
import 'chat_screen.dart';
import '../pages/note_editor_page.dart';

class PostDetailScreen extends StatefulWidget {
  final Post post;
  const PostDetailScreen({Key? key, required this.post}) : super(key: key);

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class PdfPreviewScreen extends StatefulWidget {
  final String url;
  final String title;

  const PdfPreviewScreen({super.key, required this.url, required this.title});

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  bool _isLoading = true;
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: _hasError ? _buildErrorWidget() : _buildViewer(),
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          _buildAppBar(),
        ],
      ),
    );
  }

  Widget _buildViewer() {
    if (kIsWeb) {
      if (_isLoading) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _isLoading = false);
        });
      }
      return buildPlatformPdfView(widget.url);
    }

    return SfPdfViewer.network(
      widget.url,
      canShowPaginationDialog: false,
      canShowScrollHead: false,
      onDocumentLoaded: (_) => setState(() => _isLoading = false),
      onDocumentLoadFailed: (_) => setState(() {
        _isLoading = false;
        _hasError = true;
      }),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.white, size: 64),
          SizedBox(height: 16),
          Text('PDF加载失败', style: TextStyle(color: Colors.white, fontSize: 18)),
          SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('返回'),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostDetailScreenState extends State<PostDetailScreen>
    with SingleTickerProviderStateMixin {
  WebSocketChannel? _wsChannel;
  late bool isLiked;
  late bool isSaved;
  late int likeCount;
  late int commentCount;
  //late Post _post;
  Comment? _currentReplyTo; // 当前正在回复的评论
  String? _currentReplyParentId; // 当前回复的父评论 ID
  final FocusNode _commentFocusNode = FocusNode();
  // 评论列表
  late List<Comment> _comments = [];
  // 评论加载状态
  bool _isLoadingComments = false;
  bool _hasMoreComments = true;
  int _currentPage = 1;
  static const int _pageSize = 20;
  // 防止重复请求
  bool _postLikeInFlight = false;

  // 引用文献缓存，避免重复加载
  final Map<int, Map<String, dynamic>> _referencePostCache = {};
  final Set<String> _commentLikeInFlight = {}; // commentId 集合
  bool _isSubmittingComment = false;
  final TextEditingController _commentController = TextEditingController();
  late AnimationController _heartCtrl;
  late Animation<double> _heartScale;
  bool _showBigHeart = false;
  bool _saveInFlight = false;
  bool _isDeleting = false;
  String? _currentUserId;
  bool? _isFollowingAuthor; // 是否关注了作者
  bool _followInFlight = false; // 关注操作进行中

  // 图片实际尺寸（用于动态计算宽高比）
  double? _actualImageWidth;
  double? _actualImageHeight;
  bool _isLoadingImageSize = false;

  // @功能相关状态
  bool _showMentionList = false;
  List<Author> _mentionCandidates = [];
  String _mentionQuery = '';
  int _mentionStartIndex = -1; // @符号在文本中的位置
  Map<String, Author> _selectedMentions = {}; // 已选择的@用户映射：用户名 -> 用户对象
  bool _isAutoAddingMention = false; // 标记是否正在自动添加@用户名（用于区分自动添加和手动输入）
  bool _isImageFullscreen = false;
  int _currentImageIndex = 0;
  bool _isHoveringImage = false;
  late final PageController _imagePageController;
  // ========= 外部链接跳转方法=========
  Future<void> _openExternalLink(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('链接为空')));
      return;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('无法识别的链接：$trimmed')));
      return;
    }

    if (!await canLaunchUrl(uri)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('当前环境无法打开链接：$trimmed')));
      return;
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  List<String> get _imageMedia =>
      widget.post.media.where((m) => !_isPdf(m)).toList();

  List<String> get _pdfMedia => widget.post.media.where(_isPdf).toList();
  bool get _isOwner =>
      _currentUserId != null && widget.post.author.id == _currentUserId;

  // 检查是否有 arXiv 元数据
  bool _hasArxivMetadata() {
    return widget.post.arxivId != null &&
        (widget.post.arxivAuthors.isNotEmpty ||
            widget.post.arxivPublishedDate != null ||
            widget.post.arxivCategories.isNotEmpty);
  }

  @override
  void initState() {
    super.initState();
    _imagePageController = PageController();
    isLiked = widget.post.isLiked;
    isSaved = widget.post.isSaved;
    likeCount = widget.post.likesCount;
    commentCount = widget.post.commentsCount;

    _heartCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _heartScale = Tween(
      begin: 0.3,
      end: 1.0,
    ).chain(CurveTween(curve: Curves.elasticOut)).animate(_heartCtrl);
    // 在动画结束后自动隐藏大爱心（避免永久显示受 isLiked 控制）
    _heartCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            setState(() {
              _showBigHeart = false;
            });
            _heartCtrl.reset();
          }
        });
      }
    });

    // 监听评论输入框的文本变化，检测@输入
    _commentController.addListener(_onCommentTextChanged);

    // 从后端获取最新的帖子信息
    _loadPostDetail();

    // 加载评论
    _loadComments();

    // 获取当前用户ID
    _loadCurrentUserId();

    // 记录浏览历史（最多 50 条由 BrowseHistoryService 自己控制）
    final userId = LocalStorage.instance.read('userId')?.toString();
    if (userId != null && userId.isNotEmpty) {
      unawaited(
        BrowseHistoryService.addHistory(
          userId: userId,
          postId: widget.post.id,
          title: widget.post.title,
        ),
      );
    }

    // WebSocket 实时点赞监听
    _initWebSocket();

    _currentUserId = LocalStorage.instance.read('userId');

    // 检查是否已关注作者
    _checkFollowStatus();

    // 如果后端返回的尺寸看起来是默认值（800x600），尝试加载图片获取真实尺寸
    if (_imageMedia.isNotEmpty &&
        widget.post.imageNaturalWidth == 800.0 &&
        widget.post.imageNaturalHeight == 600.0) {
      _loadImageSize();
    }
  }

  /// 加载图片获取真实尺寸
  Future<void> _loadImageSize() async {
    if (_isLoadingImageSize || _imageMedia.isEmpty) return;

    setState(() {
      _isLoadingImageSize = true;
    });

    try {
      final imageUrl = _imageMedia.first;
      final imageProvider = NetworkImage(imageUrl);

      // 使用 ImageProvider.resolve 获取图片信息
      final ImageStream stream = imageProvider.resolve(
        const ImageConfiguration(),
      );
      final Completer<void> completer = Completer<void>();

      ImageStreamListener? listener;
      listener = ImageStreamListener(
        (ImageInfo info, bool synchronousCall) {
          if (!mounted) return;

          final image = info.image;
          setState(() {
            _actualImageWidth = image.width.toDouble();
            _actualImageHeight = image.height.toDouble();
            _isLoadingImageSize = false;
          });

          stream.removeListener(listener!);
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        onError: (exception, stackTrace) {
          stream.removeListener(listener!);
          if (!completer.isCompleted) {
            completer.complete();
          }
          if (mounted) {
            setState(() {
              _isLoadingImageSize = false;
            });
          }
        },
      );

      stream.addListener(listener);
      await completer.future;
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingImageSize = false;
        });
      }
    }
  }

  void _toggleImageFullscreen() {
    setState(() {
      _isImageFullscreen = !_isImageFullscreen;
    });
  }

  void _handleImageHover(bool isHovering) {
    if (!kIsWeb) return;
    if (_isHoveringImage != isHovering) {
      setState(() {
        _isHoveringImage = isHovering;
      });
    }
  }

  void _goToNextImage() {
    final images = _imageMedia;
    if (images.length <= 1) return;
    final nextIndex = (_currentImageIndex + 1).clamp(0, images.length - 1);
    _imagePageController.animateToPage(
      nextIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _goToPreviousImage() {
    final images = _imageMedia;
    if (images.length <= 1) return;
    final prevIndex = (_currentImageIndex - 1).clamp(0, images.length - 1);
    _imagePageController.animateToPage(
      prevIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  /// 从后端加载帖子详情
  Future<void> _loadPostDetail() async {
    try {
      final resp = await ApiService.getPost(widget.post.id);
      final status = resp['statusCode'] as int? ?? 500;
      final body = resp['body'] as Map<String, dynamic>?;

      if (status >= 200 && status < 300 && body != null) {
        final updatedPost = Post.fromJson(body);
        if (mounted) {
          setState(() {
            isLiked = updatedPost.isLiked;
            likeCount = updatedPost.likesCount;
            commentCount = updatedPost.commentsCount;
            widget.post.likesCount = updatedPost.likesCount;
            widget.post.isLiked = updatedPost.isLiked;
            widget.post.commentsCount = updatedPost.commentsCount;
          });
        }
      }
    } catch (e) {
      // 如果加载失败，使用传入的post对象
      // 不显示错误，因为已经有初始数据
    }
  }

  /// 检查是否已关注作者
  Future<void> _checkFollowStatus() async {
    if (_currentUserId == null || widget.post.author.id.isEmpty) {
      return;
    }

    // 如果是查看自己的帖子，不需要显示关注按钮
    if (_currentUserId == widget.post.author.id) {
      setState(() {
        _isFollowingAuthor = null; // null表示不显示关注按钮
      });
      return;
    }

    try {
      final resp = await ApiService.getUserProfile(widget.post.author.id);
      if (resp['statusCode'] == 200) {
        final body = resp['body'] as Map<String, dynamic>;
        final profile = UserProfile.fromJson(body);
        if (mounted) {
          setState(() {
            _isFollowingAuthor = profile.isFollowing ?? false;
          });
        }
      }
    } catch (e) {
      // 如果获取失败，默认显示未关注
      if (mounted) {
        setState(() {
          _isFollowingAuthor = false;
        });
      }
    }
  }

  /// 切换关注状态
  Future<void> _toggleFollow() async {
    if (_followInFlight || _isFollowingAuthor == null) return;

    final authorId = widget.post.author.id;
    if (authorId.isEmpty || _currentUserId == authorId) return;

    final prev = _isFollowingAuthor!;
    final next = !prev;

    setState(() {
      _followInFlight = true;
      _isFollowingAuthor = next;
    });

    try {
      final resp = next
          ? await ApiService.followUser(authorId)
          : await ApiService.unfollowUser(authorId);

      if (resp['statusCode'] != 200) {
        throw Exception(
          (resp['body'] as Map<String, dynamic>?)?['message'] ?? '操作失败',
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(next ? '已关注 ${widget.post.author.name}' : '已取消关注'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      // 回滚状态
      if (mounted) {
        setState(() {
          _isFollowingAuthor = prev;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('操作失败：$e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _followInFlight = false;
        });
      }
    }
  }

  Future<void> _loadComments({bool refresh = false}) async {
    if (_isLoadingComments) return;

    setState(() {
      _isLoadingComments = true;
      if (refresh) {
        _comments = [];
        _currentPage = 1;
        _hasMoreComments = true;
      }
    });

    try {
      // 使用后端 API 加载评论（分页）
      // ApiService.getComments 返回 {'statusCode': int, 'body': Map}
      final resp = await ApiService.getComments(
        widget.post.id,
        page: _currentPage,
        pageSize: _pageSize,
      );

      final status = resp['statusCode'] as int? ?? 500;
      final body = resp['body'] as Map<String, dynamic>?;
      if (status >= 200 && status < 300 && body != null) {
        final commentsData =
            (body['comments'] as List<dynamic>?) ?? <dynamic>[];
        final total = body['total'] as int? ?? commentsData.length;

        final newComments = commentsData
            .map((c) => Comment.fromJson(c as Map<String, dynamic>))
            .toList();

        setState(() {
          if (refresh) {
            _comments = newComments;
          } else {
            _comments.addAll(newComments);
          }

          _hasMoreComments = _comments.length < total;
          _currentPage++;
          commentCount = total;
          widget.post.commentsCount = total;
        });
      } else {
        // 可选：显示错误信息，body 可能包含 message 字段
        final msg = body != null && body['message'] != null
            ? body['message'].toString()
            : '加载评论失败';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('加载评论失败')));
    } finally {
      setState(() {
        _isLoadingComments = false;
      });
    }
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    _commentController.removeListener(_onCommentTextChanged);
    _commentController.dispose();
    _commentFocusNode.dispose();
    _imagePageController.dispose();
    _wsChannel?.sink.close();
    super.dispose();
  }

  Future<void> _loadCurrentUserId() async {
    try {
      final resp = await ApiService.getCurrentUserProfile();
      if (resp['statusCode'] == 200) {
        final body = resp['body'] as Map<String, dynamic>;
        setState(() {
          _currentUserId = body['id']?.toString();
        });
      }
    } catch (e) {
      // 忽略错误
    }
  }

  void _onCommentTextChanged() {
    final text = _commentController.text;
    final cursorPosition = _commentController.selection.baseOffset;

    if (cursorPosition < 0 || cursorPosition > text.length) {
      setState(() {
        _showMentionList = false;
        _mentionQuery = '';
        _mentionStartIndex = -1;
      });
      return;
    }

    // 如果正在自动添加@用户名，不处理文本变化（避免误判为单选模式）
    if (_isAutoAddingMention) {
      print('[@功能] 正在自动添加@用户名，跳过文本变化处理');
      return;
    }

    // 解析评论内容中实际存在的@用户名（格式：@A @B @C，有空格）
    // 使用与提交时相同的正则表达式，确保一致性
    final RegExp mentionRegex = RegExp(r'@([^\s@]+)');
    final Set<String> actualMentionedNames = {};
    for (final match in mentionRegex.allMatches(text)) {
      final userName = match.group(1)!.trim();
      if (userName.isNotEmpty && !userName.startsWith('@')) {
        actualMentionedNames.add(userName.toLowerCase());
      }
    }
    print(
      '[@功能] _onCommentTextChanged: 解析到的@用户名: ${actualMentionedNames.toList()}',
    );

    // 移除评论内容中不存在的@用户
    final keysToRemove = <String>[];
    for (final key in _selectedMentions.keys) {
      if (!actualMentionedNames.contains(key)) {
        keysToRemove.add(key);
      }
    }
    if (keysToRemove.isNotEmpty) {
      setState(() {
        for (final key in keysToRemove) {
          _selectedMentions.remove(key);
        }
      });
      print('[@功能] 移除了不存在的@用户: $keysToRemove');
    }

    // 当选择列表为空且没有检测到@时，关闭横栏
    if (_selectedMentions.isEmpty && _mentionStartIndex == -1) {
      setState(() {
        _showMentionList = false;
        _mentionQuery = '';
        _mentionStartIndex = -1;
      });
    }

    // 查找最近的@符号（用于检测是否正在输入@）
    // 在多选模式下，如果@后面跟着已选择的用户名，说明是自动添加的，不处理
    int atIndex = -1;
    for (int i = cursorPosition - 1; i >= 0; i--) {
      if (text[i] == '@') {
        // 检查这个@后面是否跟着已选择的用户名
        bool isMentioned = false;
        if (i + 1 < text.length) {
          for (final user in _selectedMentions.values) {
            if (text.length >= i + 1 + user.name.length &&
                text.substring(i + 1, i + 1 + user.name.length) == user.name) {
              isMentioned = true;
              break;
            }
          }
        }
        if (!isMentioned) {
          atIndex = i;
          break;
        }
      } else if (text[i] == ' ' || text[i] == '\n') {
        break; // 遇到空格或换行，说明不在@上下文中
      }
    }

    if (atIndex != -1) {
      // 检测到@符号
      final query = text.substring(atIndex + 1, cursorPosition).trim();
      print('[@功能] 检测到@符号，位置: $atIndex, 查询: "$query"');

      setState(() {
        _mentionStartIndex = atIndex;
        _mentionQuery = query;
        _showMentionList = true;
      });

      if (query.isEmpty) {
        // 多选模式：@后面没有内容，显示关注用户列表
        print('[@功能] 多选模式：显示关注用户列表');
        if (_mentionCandidates.isEmpty || _mentionQuery != '') {
          // 如果候选列表为空或之前是搜索模式，重新加载关注用户
          _mentionCandidates = []; // 先清空
          _searchMentionUsers(''); // 加载关注用户列表（type='following'）
        }
      } else {
        // 单选模式：@后面有内容，搜索所有用户
        print('[@功能] 单选模式：搜索所有用户，查询: "$query"');
        _mentionCandidates = []; // 先清空
        _searchMentionUsers(query); // 搜索所有用户（type='all'）
      }
    } else {
      // 如果没有检测到@符号
      // 检查光标位置：如果光标在已选择的@用户名后面，且用户正在输入普通文字，应该关闭@功能
      bool isTypingAfterMentions = false;
      if (_selectedMentions.isNotEmpty && cursorPosition > 0) {
        // 检查光标前面是否有@用户名
        final textBeforeCursor = text.substring(0, cursorPosition);
        final RegExp mentionRegex = RegExp(r'@([^\s@]+)');
        final matches = mentionRegex.allMatches(textBeforeCursor);

        if (matches.isNotEmpty) {
          // 找到最后一个@用户名
          final lastMatch = matches.last;
          final lastMentionEnd = lastMatch.end;

          // 如果光标在最后一个@用户名之后，且中间有非@字符，说明用户在输入普通文字
          if (cursorPosition > lastMentionEnd) {
            final textAfterLastMention = textBeforeCursor.substring(
              lastMentionEnd,
            );
            // 如果@用户名后面有非@非空格的字符，说明用户在输入普通文字，应该关闭@功能
            if (textAfterLastMention.isNotEmpty &&
                !textAfterLastMention.trim().isEmpty) {
              isTypingAfterMentions = true;
            }
          }
        }
      }

      if (isTypingAfterMentions) {
        // 用户在@用户名后输入了普通文字，关闭@功能
        print('[@功能] 检测到在@用户名后输入普通文字，关闭@功能');
        setState(() {
          _showMentionList = false;
          _mentionQuery = '';
          _mentionStartIndex = -1;
        });
      } else if (_selectedMentions.isNotEmpty) {
        // 如果没有检测到@符号，但已选择了用户，且光标不在@用户名后输入普通文字
        // 保持显示横栏（多选模式），但只在光标紧跟在@用户名后面时
        // 如果光标位置不在@上下文中，关闭横栏
        final textBeforeCursor = text.substring(0, cursorPosition);
        final RegExp mentionRegex = RegExp(r'@([^\s@]+)');
        final matches = mentionRegex.allMatches(textBeforeCursor);

        bool shouldKeepOpen = false;
        if (matches.isNotEmpty) {
          final lastMatch = matches.last;
          final lastMentionEnd = lastMatch.end;
          // 检查光标位置：如果光标在@用户名后面，且紧跟在@用户名或空格后面，保持打开
          // 格式是@A @B @C，所以光标应该在@用户名后面，或者在空格后面（但空格后面不应该保持打开）
          final textAfterLastMention = cursorPosition > lastMentionEnd
              ? textBeforeCursor.substring(lastMentionEnd, cursorPosition)
              : '';

          // 如果光标紧跟在@用户名后面（没有空格），或者光标在@用户名后的空格位置，保持打开
          // 但如果光标在空格后面（有非空格字符），应该关闭
          if (cursorPosition == lastMentionEnd) {
            // 光标紧跟在@用户名后面，保持打开
            shouldKeepOpen = true;
          } else if (textAfterLastMention.trim().isEmpty &&
              textAfterLastMention.length <= 1) {
            // 光标在@用户名后的空格位置（最多一个空格），保持打开
            shouldKeepOpen = true;
          }
          // 其他情况（光标在空格后面有字符），不保持打开
        }

        if (shouldKeepOpen) {
          setState(() {
            _mentionQuery = '';
            _mentionStartIndex = -1;
            _showMentionList = true; // 保持显示横栏
            // 如果候选列表为空，重新加载关注用户列表
            if (_mentionCandidates.isEmpty) {
              _searchMentionUsers(''); // 加载关注用户列表
            }
          });
        } else {
          // 光标不在@上下文中，关闭横栏
          setState(() {
            _showMentionList = false;
            _mentionQuery = '';
            _mentionStartIndex = -1;
          });
        }
      } else {
        // 如果没有@符号且没有选择用户，关闭横栏
        setState(() {
          _showMentionList = false;
          _mentionQuery = '';
          _mentionStartIndex = -1;
        });
      }
    }
  }

  Future<void> _searchMentionUsers(String query) async {
    try {
      Map<String, dynamic> resp;

      if (query.isEmpty) {
        // 如果查询为空，显示关注的人
        resp = await ApiService.searchUsers(
          query: '',
          type: 'following',
          pageSize: 10,
        );
      } else {
        // 搜索所有匹配的用户
        resp = await ApiService.searchUsers(
          query: query,
          type: 'all',
          pageSize: 10,
        );
      }

      if (resp['statusCode'] == 200 && mounted) {
        final body = resp['body'] as Map<String, dynamic>?;
        if (body != null) {
          final users = (body['users'] as List? ?? [])
              .map((u) {
                try {
                  // 后端返回的是displayName字段，不是name
                  String userName = u['displayName']?.toString() ?? '';
                  if (userName.isEmpty) {
                    // 如果displayName为空，使用email作为fallback
                    userName = u['email']?.toString() ?? '';
                    // 如果email也不为空，取@前面的部分
                    if (userName.isNotEmpty && userName.contains('@')) {
                      userName = userName.split('@')[0];
                    }
                  }
                  print(
                    '[@功能] 解析用户: id=${u['id']}, displayName=$userName, email=${u['email']}',
                  );
                  return Author(
                    id: u['id']?.toString() ?? '',
                    name: userName,
                    avatar: u['avatar']?.toString() ?? '',
                    affiliation: u['affiliation']?.toString(),
                  );
                } catch (e) {
                  print('解析用户数据失败: $e, 数据: $u');
                  return null;
                }
              })
              .where((u) => u != null && u!.name.isNotEmpty)
              .cast<Author>()
              .toList();

          if (mounted) {
            setState(() {
              _mentionCandidates = users;
            });
          }
        }
      } else {
        print('搜索用户失败: statusCode=${resp['statusCode']}, body=${resp['body']}');
      }
    } catch (e, stackTrace) {
      print('搜索用户异常: $e');
      print('堆栈跟踪: $stackTrace');
      // 忽略错误，不显示给用户
    }
  }

  void _selectMentionUser(Author user) {
    print(
      '[@功能] _selectMentionUser 被调用，用户: ${user.name}, _mentionStartIndex: $_mentionStartIndex, _mentionQuery: "$_mentionQuery"',
    );

    final userNameLower = user.name.toLowerCase();
    final isCurrentlySelected = _selectedMentions.containsKey(userNameLower);

    if (isCurrentlySelected) {
      // 如果已经选择，取消选择
      _toggleMentionUser(user);
      return;
    }

    try {
      final text = _commentController.text;
      final cursorPosition = _commentController.selection.baseOffset;

      // 判断是单选模式还是多选模式
      final isMultiSelectMode = _mentionQuery.isEmpty; // @后面没有内容 = 多选模式

      if (_mentionStartIndex != -1 && _mentionStartIndex < text.length) {
        // 正在输入@状态
        final beforeAt = text.substring(0, _mentionStartIndex);
        final afterCursor = cursorPosition < text.length
            ? text.substring(cursorPosition)
            : '';

        String newText;
        int newCursorPosition;

        if (isMultiSelectMode) {
          // 多选模式：替换@为@用户名，或追加@用户名（格式：@A @B @C，每个后面加空格）
          if (_selectedMentions.isEmpty) {
            // 第一个选择：替换@为@用户名 + 空格
            newText = '$beforeAt@${user.name} $afterCursor';
            newCursorPosition =
                beforeAt.length + user.name.length + 2; // +2 for '@' and ' '
          } else {
            // 后续选择：在已有@用户名后追加 @用户名 + 空格（格式：@A @B @C @D）
            // 查找最后一个@用户名（可能后面有空格）
            final lastMentionMatch = RegExp(
              r'@([^\s@]+)\s*',
            ).allMatches(text).lastOrNull;
            if (lastMentionMatch != null) {
              final lastMentionEnd = lastMentionMatch.end;
              final beforeLastMention = text.substring(0, lastMentionEnd);
              final afterLastMention = text.substring(lastMentionEnd);
              newText = '$beforeLastMention@${user.name} $afterLastMention';
              newCursorPosition =
                  lastMentionEnd + user.name.length + 2; // +2 for '@' and ' '
            } else {
              newText = '$beforeAt@${user.name} $afterCursor';
              newCursorPosition =
                  beforeAt.length + user.name.length + 2; // +2 for '@' and ' '
            }
          }
        } else {
          // 单选模式：替换@到光标位置的内容为@用户名，然后关闭横栏
          // 注意：单选模式选择的用户也要累积到_selectedMentions中，支持叠加
          newText = '$beforeAt@${user.name} $afterCursor';
          newCursorPosition =
              beforeAt.length + user.name.length + 2; // +2 for '@' and ' '
        }

        // 设置自动添加标志，避免触发_onCommentTextChanged时误判
        _isAutoAddingMention = true;
        _commentController.text = newText;
        _commentController.selection = TextSelection.collapsed(
          offset: newCursorPosition,
        );

        // 添加到已选择列表（单选和多选都累积）
        setState(() {
          _selectedMentions[userNameLower] = user;
          if (isMultiSelectMode) {
            // 多选模式：保持横栏打开，重置@位置
            _mentionQuery = '';
            _mentionStartIndex = -1;
            _showMentionList = true; // 确保横栏保持打开
          } else {
            // 单选模式：关闭横栏，但保留已选择的用户（支持叠加）
            _showMentionList = false;
            _mentionQuery = '';
            _mentionStartIndex = -1;
          }
        });

        // 延迟重置标志，确保_onCommentTextChanged不会误判
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            setState(() {
              _isAutoAddingMention = false;
            });
          }
        });

        print(
          '[@功能] 成功选择了用户: ${user.name}（${isMultiSelectMode ? "多选" : "单选"}模式），当前已选择: ${_selectedMentions.keys.toList()}',
        );
        print('[@功能] _showMentionList: $_showMentionList');
      } else {
        // 不在输入@状态：在文本末尾追加@用户名 + 空格（多选模式）
        print('[@功能] 不在输入@状态，在末尾追加@用户名（多选模式）');

        final newText = '${text}@${user.name} ';
        final newCursorPosition = newText.length;

        // 设置自动添加标志，避免触发_onCommentTextChanged时误判
        _isAutoAddingMention = true;
        _commentController.text = newText;
        _commentController.selection = TextSelection.collapsed(
          offset: newCursorPosition,
        );

        // 添加到已选择列表
        setState(() {
          _selectedMentions[userNameLower] = user;
          // 不在输入@状态时追加，保持横栏打开（多选模式）
          _showMentionList = true;
          _mentionQuery = '';
          _mentionStartIndex = -1;
        });

        // 延迟重置标志，确保_onCommentTextChanged不会误判
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            setState(() {
              _isAutoAddingMention = false;
            });
          }
        });

        print(
          '[@功能] 成功选择了用户: ${user.name}（追加），当前已选择: ${_selectedMentions.keys.toList()}',
        );
        print('[@功能] _showMentionList: $_showMentionList');
      }
    } catch (e, stackTrace) {
      print('[@功能] 选择用户时出错: $e');
      print('[@功能] 堆栈跟踪: $stackTrace');
    }
  }

  void _toggleMentionUser(Author user) {
    final userNameLower = user.name.toLowerCase();
    final isCurrentlySelected = _selectedMentions.containsKey(userNameLower);

    if (isCurrentlySelected) {
      // 取消选择：从评论框中删除@用户名（格式：@A @B @C，删除@B后变成@A @C）
      final text = _commentController.text;
      final RegExp mentionRegex = RegExp(r'@([^\s@]+)\s*');

      // 查找所有@用户名，找到匹配的并删除（包括后面的空格）
      String newText = text;
      for (final match in mentionRegex.allMatches(text)) {
        final mentionedName = match.group(1)!.trim();

        if (mentionedName.toLowerCase() == userNameLower) {
          // 找到匹配的@用户名，删除它（包括@和后面的空格）
          final startIndex = match.start;
          final endIndex = match.end;

          newText = text.substring(0, startIndex) + text.substring(endIndex);
          break; // 只删除第一个匹配的
        }
      }

      // 设置自动添加标志，避免触发_onCommentTextChanged时误判
      _isAutoAddingMention = true;
      _commentController.text = newText;

      // 延迟重置标志
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() {
            _isAutoAddingMention = false;
          });
        }
      });

      // 从已选择列表移除
      setState(() {
        _selectedMentions.remove(userNameLower);

        // 如果选择列表为空，关闭横栏
        if (_selectedMentions.isEmpty) {
          _showMentionList = false;
          _mentionQuery = '';
          _mentionStartIndex = -1;
        }
      });

      print(
        '[@功能] 取消选择用户: ${user.name}，已从评论框删除，剩余: ${_selectedMentions.keys.toList()}',
      );
    } else {
      // 选择：调用_selectMentionUser
      _selectMentionUser(user);
    }
  }

  /// 构建包含@提及的评论内容（可点击的@链接）
  Widget _buildCommentContentWithMentions(
    String content,
    List<Author> mentions,
  ) {
    final List<TextSpan> spans = [];
    // 使用与提交时相同的正则表达式，匹配@后面跟着非@非空格的字符（格式：@A @B @C，有空格）
    final RegExp mentionRegex = RegExp(r'@([^\s@]+)');
    int lastIndex = 0;

    // 建立@用户名到用户ID的映射
    final Map<String, String> mentionMap = {};
    for (final mention in mentions) {
      mentionMap[mention.name.toLowerCase()] = mention.id;
    }

    print(
      '[@功能] _buildCommentContentWithMentions: content="$content", mentions=${mentions.map((m) => m.name).toList()}',
    );
    print('[@功能] mentionMap: $mentionMap');

    for (final match in mentionRegex.allMatches(content)) {
      // 添加@之前的文本
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: content.substring(lastIndex, match.start),
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
        );
      }

      // 添加@提及（可点击）
      final mentionText = match.group(0)!; // 包含@的完整文本，如 "@用户名"
      final userName = match.group(1)!; // 用户名部分

      print('[@功能] 匹配到@用户名: "$userName"');

      // 从mentions列表中查找对应的用户ID
      final userId = mentionMap[userName.toLowerCase()];

      if (userId != null) {
        // 如果用户ID存在，显示为可点击的蓝色链接
        print('[@功能] 找到用户ID: $userId，创建可点击链接');
        spans.add(
          TextSpan(
            text: mentionText,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.blue,
              fontWeight: FontWeight.w500,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                // 使用用户ID直接跳转
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfilePage(userId: userId),
                  ),
                );
              },
          ),
        );
      } else {
        // 如果用户ID不存在（用户直接输入@用户名，没有从列表选择），显示为普通文本
        print('[@功能] 未找到用户ID，显示为普通文本');
        spans.add(
          TextSpan(
            text: mentionText,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
        );
      }

      lastIndex = match.end;
    }

    // 添加剩余的文本
    if (lastIndex < content.length) {
      spans.add(
        TextSpan(
          text: content.substring(lastIndex),
          style: const TextStyle(fontSize: 13, color: Colors.black87),
        ),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }

  /// 通过用户名导航到用户主页
  Future<void> _navigateToUserProfileByName(String userName) async {
    try {
      print('[@功能] 尝试查找用户: $userName');
      // 先搜索用户（搜索name和email）
      final resp = await ApiService.searchUsers(
        query: userName,
        type: 'all',
        pageSize: 20,
      );
      if (resp['statusCode'] == 200) {
        final body = resp['body'] as Map<String, dynamic>?;
        if (body != null) {
          final users = (body['users'] as List? ?? []);
          print('[@功能] 搜索到 ${users.length} 个用户');

          // 精确匹配：先尝试匹配displayName，再尝试匹配email前缀
          for (final user in users) {
            final displayName = user['displayName']?.toString() ?? '';
            final email = user['email']?.toString() ?? '';
            final emailPrefix = email.contains('@') ? email.split('@')[0] : '';

            // 精确匹配displayName或email前缀
            if (displayName.toLowerCase() == userName.toLowerCase() ||
                emailPrefix.toLowerCase() == userName.toLowerCase()) {
              final userId = user['id']?.toString();
              if (userId != null && mounted) {
                print('[@功能] 找到匹配用户: id=$userId, displayName=$displayName');
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfilePage(userId: userId),
                  ),
                );
                return;
              }
            }
          }

          // 如果没有精确匹配，使用第一个结果
          if (users.isNotEmpty) {
            final user = users[0];
            final userId = user['id']?.toString();
            if (userId != null && mounted) {
              print('[@功能] 使用第一个搜索结果: id=$userId');
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ProfilePage(userId: userId)),
              );
              return;
            }
          }
        }
      }
      // 如果搜索失败，显示提示
      print('[@功能] 未找到用户: $userName');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('未找到用户: $userName')));
      }
    } catch (e, stackTrace) {
      print('[@功能] 导航到用户主页失败: $e');
      print('[@功能] 堆栈跟踪: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('查找用户失败: $e')));
      }
    }
  }

  void _startReply(Comment comment, {String? parentId}) {
    setState(() {
      _currentReplyTo = comment;
      _currentReplyParentId = parentId ?? comment.id;
      _commentController.text = '';
      //_commentController.text = '@${comment.author.name} ';
    });
    _commentFocusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _currentReplyTo = null;
      _currentReplyParentId = null;
      _commentController.text = '';
    });
  }

  /// 初始化 WebSocket 连接，监听后端推送的点赞/评论点赞变更
  void _initWebSocket() {
    // TODO: 替换为你后端实际 ws 地址
    final wsUrl = 'ws:${AppEnv.apiBaseUrl}/ws/posts/${widget.post.id}';
    _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
    _wsChannel!.stream.listen(
      (event) {
        try {
          final data = jsonDecode(event);
          final type = data['type'] as String?;

          // 常见事件：
          // - like_update: 帖子点赞变化（保持原有处理）
          // - comment_like_update: 单条评论的点赞变化
          // - comment_created: 新评论推送，payload 中包含 comment 对象
          // - comment_updated: 评论被更新，payload 中包含 comment 对象
          // - comment_deleted: 评论被删除，payload 中包含 commentId

          if (type == 'like_update') {
            setState(() {
              if (data.containsKey('likesCount'))
                likeCount = data['likesCount'] as int;
              if (data.containsKey('isLiked'))
                isLiked = data['isLiked'] as bool;
            });
          } else if (type == 'comment_like_update' &&
              data['commentId'] != null) {
            // 评论点赞变更
            final commentId = data['commentId'] as String;
            final idx = _comments.indexWhere((c) => c.id == commentId);
            if (idx != -1) {
              setState(() {
                if (data.containsKey('likesCount'))
                  _comments[idx].likesCount = data['likesCount'] as int;
                if (data.containsKey('isLiked'))
                  _comments[idx].isLiked = data['isLiked'] as bool;
              });
            } else {
              // 可能是子回复的点赞变化
              for (var parent in _comments) {
                final ridx = parent.replies.indexWhere(
                  (r) => r.id == commentId,
                );
                if (ridx != -1) {
                  setState(() {
                    if (data.containsKey('likesCount'))
                      parent.replies[ridx].likesCount =
                          data['likesCount'] as int;
                    if (data.containsKey('isLiked'))
                      parent.replies[ridx].isLiked = data['isLiked'] as bool;
                  });
                  break;
                }
              }
            }
          } else if (type == 'comment_created') {
            // 服务器推送新评论
            _handleCommentCreated(data);
          } else if (type == 'comment_updated') {
            _handleCommentUpdated(data);
          } else if (type == 'comment_deleted') {
            _handleCommentDeleted(data);
          }
        } catch (e) {
          // ignore: 格式或解析错误，避免影响主流程
        }
      },
      onError: (err) {
        // 可选：记录错误或做重连策略
      },
      onDone: () {
        // 可选：自动重连（根据实际需要实现）
      },
    );
  }

  void _handleCommentCreated(Map<String, dynamic> data) {
    // 期望 payload 在 data['comment'] 或 data['payload'] 中
    final commentJson =
        (data['comment'] ?? data['payload'] ?? data['data'])
            as Map<String, dynamic>?;
    if (commentJson == null) return;

    try {
      final newComment = Comment.fromJson(commentJson);

      setState(() {
        // 防止重复插入：检查顶层评论和所有子回复
        bool exists = false;

        // 检查顶层评论
        if (_comments.any((c) => c.id == newComment.id)) {
          exists = true;
        }

        // 检查所有子回复
        if (!exists) {
          for (var comment in _comments) {
            if (comment.replies.any((r) => r.id == newComment.id)) {
              exists = true;
              break;
            }
          }
        }

        if (exists) {
          return; // 已存在，忽略
        }

        if (newComment.parentId == null) {
          // 顶层评论，插入到顶部
          _comments.insert(0, newComment);
          commentCount += 1;
          widget.post.commentsCount = commentCount;
        } else {
          // 找到父评论并追加到 replies
          final pIdx = _comments.indexWhere((c) => c.id == newComment.parentId);
          if (pIdx != -1) {
            // 防止重复
            if (!_comments[pIdx].replies.any((r) => r.id == newComment.id)) {
              _comments[pIdx].replies.add(newComment);
            }
          } else {
            // parent评论不在当前页/列表中，作为降级处理，把回复也插为顶层（可根据需求改为忽略）
            _comments.insert(0, newComment);
            commentCount += 1;
            widget.post.commentsCount = commentCount;
          }
        }
      });
    } catch (e) {
      // ignore: 如果解析失败则不阻塞
    }
  }

  void _handleCommentUpdated(Map<String, dynamic> data) {
    final commentJson =
        (data['comment'] ?? data['payload'] ?? data['data'])
            as Map<String, dynamic>?;
    if (commentJson == null) return;

    try {
      final updated = Comment.fromJson(commentJson);

      setState(() {
        // 先尝试在顶层查找
        final tIdx = _comments.indexWhere((c) => c.id == updated.id);
        if (tIdx != -1) {
          // 保留子 replies（如果后端未返回）
          final oldReplies = _comments[tIdx].replies;
          _comments[tIdx] = Comment(
            id: updated.id,
            author: updated.author,
            content: updated.content,
            parentId: updated.parentId,
            replyTo: updated.replyTo,
            likesCount: updated.likesCount,
            isLiked: updated.isLiked,
            replies: oldReplies,
            createdAt: updated.createdAt,
          );
          return;
        }

        // 在子回复中查找
        for (var parent in _comments) {
          final rIdx = parent.replies.indexWhere((r) => r.id == updated.id);
          if (rIdx != -1) {
            final oldReplies = parent.replies[rIdx].replies;
            parent.replies[rIdx] = Comment(
              id: updated.id,
              author: updated.author,
              content: updated.content,
              parentId: updated.parentId,
              replyTo: updated.replyTo,
              likesCount: updated.likesCount,
              isLiked: updated.isLiked,
              replies: oldReplies,
              createdAt: updated.createdAt,
            );
            break;
          }
        }
      });
    } catch (e) {
      // ignore
    }
  }

  void _handleCommentDeleted(Map<String, dynamic> data) {
    // 期望 data 包含 commentId 或 payload
    final commentId =
        (data['commentId'] ??
                data['id'] ??
                (data['payload'] is Map ? data['payload']['id'] : null))
            as String?;
    if (commentId == null) return;

    setState(() {
      // 从顶层删除
      final tIdx = _comments.indexWhere((c) => c.id == commentId);
      if (tIdx != -1) {
        final deletedComment = _comments[tIdx];
        final deletedCount = 1 + deletedComment.replies.length;
        _comments.removeAt(tIdx);
        commentCount = (commentCount >= deletedCount)
            ? commentCount - deletedCount
            : 0;
        widget.post.commentsCount = commentCount;
        return;
      }

      // 从子回复中删除
      for (int i = 0; i < _comments.length; i++) {
        final parent = _comments[i];
        final rIdx = parent.replies.indexWhere((r) => r.id == commentId);
        if (rIdx != -1) {
          // 重新创建parent评论，移除被删除的回复
          final updatedReplies = parent.replies
              .where((r) => r.id != commentId)
              .toList();
          _comments[i] = Comment(
            id: parent.id,
            author: parent.author,
            content: parent.content,
            parentId: parent.parentId,
            replyTo: parent.replyTo,
            likesCount: parent.likesCount,
            isLiked: parent.isLiked,
            replies: updatedReplies,
            createdAt: parent.createdAt,
          );
          commentCount = (commentCount > 0) ? commentCount - 1 : 0;
          widget.post.commentsCount = commentCount;
          return;
        }
      }
    });
  }

  void _toggleLike() {
    // keep backward-compatible call site (double tap)
    _handlePostLikePressed();
  }

  Future<void> _handlePostLikePressed() async {
    if (_postLikeInFlight) return; // 防止重复请求
    _postLikeInFlight = true;

    final previousLiked = isLiked;
    final previousCount = likeCount;

    // 乐观更新
    setState(() {
      isLiked = !isLiked;
      likeCount += isLiked ? 1 : -1;
      widget.post.isLiked = isLiked;
      widget.post.likesCount = likeCount;
    });

    if (isLiked) {
      // 仅控制动画显示，不作为大爱心常驻显示的条件
      setState(() {
        _showBigHeart = true;
      });
      _heartCtrl.forward(from: 0.0);
    }

    try {
      final resp = isLiked
          ? await ApiService.likePost(widget.post.id)
          : await ApiService.unlikePost(widget.post.id);
      final status = (resp['statusCode'] ?? 500) as int;
      final body = resp['body'] as Map<String, dynamic>?;

      print('点赞响应: status=$status, body=$body'); // 调试日志

      if (status >= 200 && status < 300) {
        // 如果后端返回了最新计数，则以后端为准
        if (body != null &&
            body.containsKey('likesCount') &&
            body.containsKey('isLiked')) {
          setState(() {
            likeCount = body['likesCount'] as int;
            isLiked = body['isLiked'] as bool;
            widget.post.likesCount = likeCount;
            widget.post.isLiked = isLiked;
          });
        } else if (body != null && body.containsKey('message')) {
          // 如果只有 message，说明可能是 204 或其他情况，保持乐观更新
          print('警告: 响应缺少 likesCount 或 isLiked，保持乐观更新');
        }
        // （可选）如果后端不自动创建通知，前端可以调用通知接口：
        // await ApiService.createNotification({ ... });
      } else {
        // 请求失败 -> 回滚
        setState(() {
          isLiked = previousLiked;
          likeCount = previousCount;
          widget.post.isLiked = previousLiked;
          widget.post.likesCount = previousCount;
        });
        final msg = body != null && body['message'] != null
            ? body['message'].toString()
            : '点赞失败，请稍后重试';
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
        }
      }
    } catch (e, stackTrace) {
      // 网络或解析错误 -> 回滚
      print('点赞异常: $e');
      print('堆栈跟踪: $stackTrace');
      setState(() {
        isLiked = previousLiked;
        likeCount = previousCount;
        widget.post.isLiked = previousLiked;
        widget.post.likesCount = previousCount;
      });
      if (mounted) {
        final errorMsg = e.toString().contains('超时')
            ? '请求超时，请检查网络连接'
            : '网络错误，点赞未成功，请稍后重试';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMsg)));
      }
    } finally {
      _postLikeInFlight = false;
    }
  }

  Future<void> _toggleSave() async {
    if (_saveInFlight) return;
    _saveInFlight = true;
    final previousSaved = isSaved;
    setState(() {
      isSaved = !isSaved;
      widget.post.isSaved = isSaved;
    });
    try {
      final resp = isSaved
          ? await ApiService.favoritePost(widget.post.id)
          : await ApiService.unfavoritePost(widget.post.id);
      final status = resp['statusCode'] as int? ?? 500;
      final body = resp['body'] as Map<String, dynamic>?;
      if (status >= 200 && status < 300) {
        if (body != null && body.containsKey('isSaved')) {
          final serverValue = body['isSaved'] as bool;
          setState(() {
            isSaved = serverValue;
            widget.post.isSaved = serverValue;
          });
        }
      } else {
        setState(() {
          isSaved = previousSaved;
          widget.post.isSaved = previousSaved;
        });
        final msg = body != null && body['message'] != null
            ? body['message'].toString()
            : '收藏操作失败';
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
        }
      }
    } catch (e) {
      setState(() {
        isSaved = previousSaved;
        widget.post.isSaved = previousSaved;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('网络错误，收藏操作未成功')));
      }
    } finally {
      _saveInFlight = false;
    }
  }

  Future<void> _openUserProfile(String userId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => ProfilePage(userId: userId)),
    );
    // 从用户主页返回时，刷新关注状态（特别是如果用户在该页面取关了作者）
    if (userId == widget.post.author.id && _currentUserId != userId) {
      await _checkFollowStatus();
    }
  }

  Future<void> _onShare() async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先登录')));
      return;
    }

    // 显示分享选择界面
    final selectedUserId = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ShareUserSelectionSheet(
        currentUserId: _currentUserId!,
        post: widget.post,
      ),
    );

    if (selectedUserId == null) return;

    // 分享帖子到选中的用户
    await _sharePostToUser(selectedUserId);
  }

  Future<void> _sharePostToUser(String targetUserId) async {
    try {
      // 显示加载提示
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('正在分享...'),
          duration: Duration(seconds: 1),
        ),
      );

      // 获取或创建 conversation
      final chatService = ChatService();
      final conversation = await chatService.createOrGetPrivateConversation(
        targetUserId,
      );

      if (conversation == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('创建会话失败，请稍后重试')));
        return;
      }

      // 发送分享消息
      // 使用 SHARE 类型，content 只存储 post ID
      await chatService.sendMessage(
        conversationId: conversation.id,
        content: widget.post.id, // content 只存储 post ID
        type: MessageType.share,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('分享成功')));

      // 可选：导航到聊天界面
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ChatScreen(conversation: conversation),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('分享失败: $e')));
    }
  }

  Future<void> _submitComment({String? parentId, Author? replyTo}) async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    if (_isSubmittingComment) return;

    setState(() {
      _isSubmittingComment = true;
    });

    try {
      // 解析评论内容中实际存在的@用户名，正确匹配每个@用户名（格式：@A @B @C，有空格）
      // 使用更精确的正则表达式，匹配@后面跟着非@非空格的字符
      final RegExp mentionRegex = RegExp(r'@([^\s@]+)');
      final Set<String> actualMentionedNames = {};
      for (final match in mentionRegex.allMatches(text)) {
        final userName = match.group(1)!.trim();
        if (userName.isNotEmpty && !userName.startsWith('@')) {
          actualMentionedNames.add(userName.toLowerCase());
        }
      }

      // 从_selectedMentions中提取所有在评论内容中实际存在的@用户的ID
      final List<String> mentionIds = [];
      for (final entry in _selectedMentions.entries) {
        if (actualMentionedNames.contains(entry.key)) {
          mentionIds.add(entry.value.id);
        }
      }

      // 如果_selectedMentions中没有匹配到，尝试从文本中直接解析（处理手动输入的情况）
      // 但这种情况下的@用户名不会被识别为有效的mention，因为不在_selectedMentions中

      print('[@功能] 提交评论，文本: "$text"');
      print('[@功能] 解析到的@用户名: ${actualMentionedNames.toList()}');
      print('[@功能] _selectedMentions中的用户: ${_selectedMentions.keys.toList()}');
      print('[@功能] 最终mentionIds: $mentionIds');

      // 调用真实后端 API 创建评论
      final resp = await ApiService.createComment(
        widget.post.id,
        text,
        parentId: parentId,
        replyToId: replyTo?.id,
        mentionIds: mentionIds.isNotEmpty ? mentionIds : null,
      );

      // 清空已选择的@用户列表
      _selectedMentions.clear();

      final status = resp['statusCode'] as int? ?? 500;
      final body = resp['body'] as Map<String, dynamic>?;

      print('创建评论响应: status=$status, body=$body'); // 调试日志

      if (status >= 200 && status < 300 && body != null) {
        // 评论创建成功，等待 WebSocket 推送来更新列表（避免重复添加）
        // 如果 WebSocket 没有推送，则手动刷新评论列表
        setState(() {
          _commentController.clear();
          _selectedMentions.clear();
          _showMentionList = false;
          _mentionQuery = '';
          _mentionStartIndex = -1;
          _mentionCandidates.clear(); // 清空候选列表
        });

        // 失去焦点，关闭键盘
        _commentFocusNode.unfocus();

        if (_currentReplyTo != null) {
          _cancelReply(); // 清除回复状态
        }

        // 延迟刷新评论列表，给 WebSocket 推送一些时间
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _loadComments(refresh: true);
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('评论发表成功')));
        }
      } else {
        // 处理错误响应
        String errorMsg = '评论失败，请稍后重试';
        if (status == 401 || status == 403) {
          errorMsg = body != null && body['message'] != null
              ? body['message'].toString()
              : '未认证，请先登录';
        } else if (body != null && body['message'] != null) {
          errorMsg = body['message'].toString();
        }
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(errorMsg)));
        }
      }
    } catch (e, stackTrace) {
      print('创建评论异常: $e');
      print('堆栈跟踪: $stackTrace');
      if (mounted) {
        final errorMsg = e.toString().contains('超时')
            ? '请求超时，请检查网络连接'
            : '网络错误，评论未成功，请稍后重试';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMsg)));
      }
    } finally {
      setState(() {
        _isSubmittingComment = false;
      });
    }
  }

  PreferredSizeWidget _buildTopBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black87),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        widget.post.title,
        style: const TextStyle(color: Colors.black87, fontSize: 16),
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_horiz, color: Colors.black54),
          onPressed: _isDeleting ? null : _openMoreActions,
        ),
      ],
    );
  }

  void _openMoreActions() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            // 只有作者可以看到“编辑”和“删除”
            if (_isOwner)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('编辑笔记'),
                onTap: () async {
                  // 先关闭底部弹窗
                  Navigator.pop(context);
                  // 复用已有的编辑逻辑
                  await _openEditPost();
                },
              ),

            if (_isOwner)
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('删除笔记', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeletePost();
                },
              ),
            ListTile(
              leading: const Icon(Icons.flag),
              title: const Text('举报'),
              onTap: () async {
                Navigator.pop(context);
                final result = await showDialog(
                  context: context,
                  builder: (context) =>
                      ReportPostDialog(postId: int.parse(widget.post.id)),
                );
                if (result == true && mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('举报成功，我们会尽快处理')));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('复制链接'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('链接已复制（演示）')));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeletePost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('确认删除笔记？'),
        content: const Text('删除后将无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deletePost();
    }
  }

  Future<void> _deletePost() async {
    setState(() => _isDeleting = true);
    try {
      final resp = await ApiService.deletePost(widget.post.id);
      final status = resp['statusCode'] as int? ?? 500;
      final body = resp['body'] as Map<String, dynamic>?;

      if (status >= 200 && status < 300) {
        if (!mounted) return;
        Navigator.of(context).pop(true);
        return;
      }

      final msg = body != null && body['message'] != null
          ? body['message'].toString()
          : '删除失败，请稍后重试';
      _showSnack(msg);
    } catch (e) {
      _showSnack('删除失败：$e');
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  /// 进入编辑页面
  Future<void> _openEditPost() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NoteEditorPage(initialPost: widget.post),
      ),
    );

    // 编辑页返回 true，表示“保存成功，需要刷新详情”
    if (result == true) {
      await _loadPostDetail();
    }
  }

  Widget _buildMediaGallery() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;

        // 计算图片宽高比：优先使用实际加载的图片尺寸，然后是后端返回的尺寸，最后是 imageAspectRatio
        double ratio = 1.5;
        if (_imageMedia.isNotEmpty) {
          // 优先使用实际加载的图片尺寸（如果已加载）
          if (_actualImageWidth != null &&
              _actualImageHeight != null &&
              _actualImageWidth! > 0 &&
              _actualImageHeight! > 0) {
            ratio = _actualImageWidth! / _actualImageHeight!;
          }
          // 否则使用后端返回的尺寸（如果看起来不是默认值）
          else if (widget.post.imageNaturalWidth > 0 &&
              widget.post.imageNaturalHeight > 0 &&
              !(widget.post.imageNaturalWidth == 800.0 &&
                  widget.post.imageNaturalHeight == 600.0)) {
            ratio =
                widget.post.imageNaturalWidth / widget.post.imageNaturalHeight;
          }
          // 最后使用 imageAspectRatio
          else if (widget.post.imageAspectRatio > 0) {
            ratio = widget.post.imageAspectRatio;
          }
        }

        // 计算如果宽度填满屏幕时的高度
        final calculatedHeight = screenWidth / ratio;

        // 判断是否需要限制高度
        final bool needsHeightLimit = calculatedHeight > 450;
        final double containerHeight = needsHeightLimit
            ? 450.0
            : calculatedHeight;
        final double containerWidth = needsHeightLimit
            ? (450.0 * ratio)
            : screenWidth;

        final images = _imageMedia;
        if (images.isEmpty) {
          return Container(
            height: 220,
            color: Colors.grey[200],
            child: const Center(
              child: Icon(
                Icons.image_not_supported,
                size: 48,
                color: Colors.grey,
              ),
            ),
          );
        }

        return MouseRegion(
          onEnter: (_) => _handleImageHover(true),
          onExit: (_) => _handleImageHover(false),
          child: GestureDetector(
            onDoubleTap: _toggleLike,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (needsHeightLimit)
                  Center(
                    child: SizedBox(
                      width: containerWidth,
                      height: containerHeight,
                      child: PageView.builder(
                        controller: _imagePageController,
                        itemCount: images.length,
                        onPageChanged: (index) {
                          if (_currentImageIndex != index) {
                            setState(() {
                              _currentImageIndex = index;
                            });
                          }
                        },
                        itemBuilder: (_, index) {
                          return GestureDetector(
                            onTap: _toggleImageFullscreen,
                            child: _buildImageDisplay(
                              images[index],
                              containerWidth,
                              containerHeight,
                              BoxFit.cover,
                            ),
                          );
                        },
                      ),
                    ),
                  )
                else
                  SizedBox(
                    width: screenWidth,
                    height: containerHeight,
                    child: PageView.builder(
                      controller: _imagePageController,
                      itemCount: images.length,
                      onPageChanged: (index) {
                        if (_currentImageIndex != index) {
                          setState(() {
                            _currentImageIndex = index;
                          });
                        }
                      },
                      itemBuilder: (_, index) {
                        return GestureDetector(
                          onTap: _toggleImageFullscreen,
                          child: _buildImageDisplay(
                            images[index],
                            screenWidth,
                            containerHeight,
                            BoxFit.cover,
                          ),
                        );
                      },
                    ),
                  ),
                if (kIsWeb && images.length > 1 && _isHoveringImage)
                  Positioned(
                    left: 16,
                    child: _buildImageNavButton(
                      icon: Icons.chevron_left,
                      onTap: _goToPreviousImage,
                      enabled: _currentImageIndex > 0,
                    ),
                  ),
                if (kIsWeb && images.length > 1 && _isHoveringImage)
                  Positioned(
                    right: 16,
                    child: _buildImageNavButton(
                      icon: Icons.chevron_right,
                      onTap: _goToNextImage,
                      enabled: _currentImageIndex < images.length - 1,
                    ),
                  ),
                // 喜欢动画
                Positioned(
                  child: _showBigHeart
                      ? ScaleTransition(
                          scale: _heartScale,
                          child: const Icon(
                            Icons.favorite,
                            color: Colors.redAccent,
                            size: 100,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageDisplay(
    String path,
    double width,
    double height,
    BoxFit fit,
  ) {
    final placeholder = Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: const Center(
        child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
      ),
    );

    if (path.startsWith('http')) {
      return Image.network(
        path,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => placeholder,
      );
    }

    return Image.file(
      File(path),
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => placeholder,
    );
  }

  Widget _buildImageNavButton({
    required IconData icon,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.35,
      child: Material(
        color: Colors.black45,
        shape: const CircleBorder(),
        child: IconButton(
          icon: Icon(icon, color: Colors.white),
          onPressed: enabled ? onTap : null,
        ),
      ),
    );
  }

  Widget _buildAuthorRow() {
    // 如果是查看自己的帖子，不显示关注按钮
    if (_isFollowingAuthor == null) {
      return ListTile(
        onTap: () => _openUserProfile(widget.post.author.id),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: _buildAvatarWidget(widget.post.author.avatar, 20),
        title: Text(
          widget.post.author.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${widget.post.author.affiliation ?? ''} • ${_formatRelative(widget.post.createdAt)}',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    }

    final isFollowing = _isFollowingAuthor ?? false;

    return ListTile(
      onTap: () => _openUserProfile(widget.post.author.id),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: _buildAvatarWidget(widget.post.author.avatar, 20),
      title: Text(
        widget.post.author.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${widget.post.author.affiliation ?? ''} • ${_formatRelative(widget.post.createdAt)}',
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      trailing: ElevatedButton(
        onPressed: _followInFlight ? null : _toggleFollow,
        style: ElevatedButton.styleFrom(
          backgroundColor: isFollowing
              ? Colors.grey[300]
              : const Color(0xFF1976D2),
          foregroundColor: isFollowing ? Colors.grey[700] : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
        ),
        child: _followInFlight
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                isFollowing ? '已关注' : '+ 关注',
                style: const TextStyle(fontSize: 13),
              ),
      ),
    );
  }

  String _formatRelative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    return '${diff.inDays} 天前';
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 分区标签区域（点击可跳转到对应分区页）
          _buildDisciplineTagArea(),
          const SizedBox(height: 12),
          Text(
            //标题
            widget.post.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ContentWithClickableTags(
            content: widget.post.content,
            subTags: widget.post.subTags,
            onTagTap: _onTagTap,
          ),
          const SizedBox(height: 12),
          // arXiv 文献信息（如果有）
          if (_hasArxivMetadata()) _buildArxivMetadataSection(),
          const SizedBox(height: 10),
          // 引用文献（如果有）
          if (widget.post.references.isNotEmpty) _buildReferencesSection(),
          const SizedBox(height: 10),
          if (_pdfMedia.isNotEmpty) _buildPdfSection(),
          if (widget.post.attachments.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.post.attachments.map((att) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('打开 ${att.fileName}（演示）')),
                          );
                        },
                        icon: const Icon(Icons.picture_as_pdf),
                        label: Text(att.fileName),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        ' • ${(att.sizeBytes / 1024).toStringAsFixed(0)} KB',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 8),

          //外部链接列表
          if (widget.post.externalLinks.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '外部链接',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: widget.post.externalLinks.map((link) {
                    return InkWell(
                      onTap: () {
                        _openExternalLink(link);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          link,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),

          if (widget.post.doi != null)
            Text(
              'DOI: ${widget.post.doi}',
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            ),
          if (widget.post.journal != null)
            Text(
              '${widget.post.journal}${widget.post.year != null ? ' · ${widget.post.year}' : ''}',
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            ),
        ],
      ),
    );
  }

  // 构建 arXiv 元数据信息卡片
  Widget _buildArxivMetadataSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.post.arxivAuthors.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '作者：${widget.post.arxivAuthors.join(", ")}',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
            ),
          if (widget.post.arxivPublishedDate != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '发布日期：${widget.post.arxivPublishedDate}',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
            ),
          if (widget.post.arxivCategories.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '分类：${widget.post.arxivCategories.join(", ")}',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
            ),
          if (widget.post.arxivId != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'arXiv ID: ${widget.post.arxivId}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReferencesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '引用文献',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ...widget.post.references.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final postId = entry.value;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: FutureBuilder<Map<String, dynamic>>(
              future: _fetchReferencePost(postId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '[$index] 加载中...',
                          style: const TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                      ],
                    ),
                  );
                } else if (snapshot.hasError || !snapshot.hasData) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      '[$index] 引用内容已不可见',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  );
                } else {
                  final refPost = snapshot.data!;
                  final title = refPost['title'] ?? '未知标题';
                  final authorName = refPost['author']?['name'] ?? '未知作者';
                  final discipline = refPost['mainDiscipline'] ?? '';
                  final createdAt = refPost['createdAt'];
                  String dateStr = '';
                  if (createdAt != null) {
                    try {
                      final date = DateTime.parse(createdAt);
                      dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                    } catch (e) {
                      dateStr = '';
                    }
                  }

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: InkWell(
                      onTap: () => _navigateToReferencePost(postId),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.library_books,
                            size: 16,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '[$index] $authorName. $title. $discipline${dateStr.isNotEmpty ? ', $dateStr' : ''}.',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              },
            ),
          );
        }),
      ],
    );
  }

  Future<Map<String, dynamic>> _fetchReferencePost(int postId) async {
    // 先检查缓存
    if (_referencePostCache.containsKey(postId)) {
      return _referencePostCache[postId]!;
    }

    try {
      final resp = await ApiService.getPost(postId.toString());
      if (resp['statusCode'] == 200) {
        final postData = resp['body'];
        // 缓存数据
        _referencePostCache[postId] = postData;
        return postData;
      } else {
        throw Exception('无法获取引用帖子');
      }
    } catch (e) {
      throw e;
    }
  }

  void _navigateToReferencePost(int postId) async {
    try {
      final resp = await ApiService.getPost(postId.toString());
      if (resp['statusCode'] == 200) {
        final refPostData = resp['body'];
        final refPost = Post.fromJson(refPostData);

        // 导航到引用帖子详情页
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetailScreen(
              post: refPost,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('引用内容已不可见')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法访问引用内容')),
      );
    }
  }

  Widget _buildPdfSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PDF 附件',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ..._pdfMedia.map(_buildPdfTile),
      ],
    );
  }

  Widget _buildPdfTile(String url) {
    final fileName = _extractFileName(url);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(8),
                child: const Icon(
                  Icons.picture_as_pdf,
                  color: Color(0xFFD32F2F),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openPdfPreview(url, fileName),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('预览'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _downloadPdf(url),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('下载'),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: Colors.blueGrey[50],
                    foregroundColor: Colors.blueGrey[900],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 处理标签点击事件
  void _onTagTap(String tag) {
    // 跳转到搜索页面，搜索该标签相关的帖子
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SearchResultsScreen(query: '#$tag'),
      ),
    );
  }

  /// 帖子正文上方的分区标签区域
  Widget _buildDisciplineTagArea() {
    final mainDiscipline = widget.post.mainDiscipline;
    if (mainDiscipline.isEmpty) {
      return const SizedBox.shrink();
    }
    final color = kDisciplineColors[mainDiscipline] ?? Colors.blue;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ZoneScreen(initialDiscipline: mainDiscipline),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_offer, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              mainDiscipline,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              '· 点击查看该分区更多笔记',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }


  void _openPdfPreview(String url, String title) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showSnack('PDF 链接无效');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfPreviewScreen(url: uri.toString(), title: title),
        fullscreenDialog: true,
      ),
    );
  }

  Future<void> _downloadPdf(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showSnack('PDF 链接无效');
      return;
    }
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        _showSnack('无法打开下载链接');
      }
    } catch (_) {
      _showSnack('无法打开下载链接');
    }
  }

  bool _isPdf(String url) {
    if (url.isEmpty) return false;
    try {
      final uri = Uri.tryParse(url);
      final path = uri?.path.toLowerCase() ?? url.toLowerCase();
      // 主要检查：路径是否以 .pdf 结尾
      if (path.endsWith('.pdf')) return true;
      // 次要检查：URL 路径中包含 /pdf/ 或 /pdfs/ 等 PDF 专用路径
      if (path.contains('/pdf/') || path.contains('/pdfs/')) return true;
      // 检查查询参数中是否有 type=pdf 或 format=pdf
      final query = uri?.queryParameters;
      if (query != null) {
        final type =
            query['type']?.toLowerCase() ?? query['format']?.toLowerCase();
        if (type == 'pdf' || type == 'application/pdf') return true;
      }
      return false;
    } catch (_) {
      // 如果解析失败，回退到简单的字符串检查
      return url.toLowerCase().endsWith('.pdf');
    }
  }

  String _extractFileName(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.pathSegments.isNotEmpty) {
        final segment = uri.pathSegments.last;
        if (segment.isNotEmpty) return Uri.decodeComponent(segment);
      }
    } catch (_) {
      // ignore
    }
    final sanitized = url.split('?').first;
    final parts = sanitized.split('/');
    final fallback = parts.isNotEmpty ? parts.last : 'PDF 附件';
    return fallback.isEmpty ? 'PDF 附件' : fallback;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _deleteComment(
    Comment comment, {
    required bool isTopLevel,
    Comment? parentComment,
  }) async {
    // 确认删除
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除评论'),
        content: Text(isTopLevel ? '确定要删除这条评论吗？删除后所有回复也会被删除。' : '确定要删除这条回复吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      final resp = await ApiService.deleteComment(widget.post.id, comment.id);
      if (resp['statusCode'] == 204 || resp['statusCode'] == 200) {
        // 从列表中移除评论
        setState(() {
          if (isTopLevel) {
            // 计算需要减少的评论数（包括所有子回复）
            final deletedCount = 1 + comment.replies.length;
            _comments.removeWhere((c) => c.id == comment.id);
            commentCount = (commentCount >= deletedCount)
                ? commentCount - deletedCount
                : 0;
            widget.post.commentsCount = commentCount;
          } else if (parentComment != null) {
            // 找到父评论的索引
            final parentIndex = _comments.indexWhere(
              (c) => c.id == parentComment.id,
            );
            if (parentIndex != -1) {
              // 重新创建父评论，移除被删除的回复
              final updatedReplies = parentComment.replies
                  .where((r) => r.id != comment.id)
                  .toList();
              _comments[parentIndex] = Comment(
                id: parentComment.id,
                author: parentComment.author,
                content: parentComment.content,
                parentId: parentComment.parentId,
                replyTo: parentComment.replyTo,
                likesCount: parentComment.likesCount,
                isLiked: parentComment.isLiked,
                replies: updatedReplies,
                createdAt: parentComment.createdAt,
              );
              commentCount = (commentCount > 0) ? commentCount - 1 : 0;
              widget.post.commentsCount = commentCount;
            }
          }
        });
        _showSnack('评论已删除');
      } else {
        _showSnack('删除失败，请稍后重试');
      }
    } catch (e) {
      _showSnack('删除失败: $e');
    } finally {
      setState(() {
        _isDeleting = false;
      });
    }
  }

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.15))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              isLiked ? Icons.favorite : Icons.favorite_border,
              color: isLiked ? Colors.red : Colors.black87,
            ),
            onPressed: _toggleLike,
          ),
          Text('$likeCount'),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.mode_comment_outlined),
            onPressed: () => FocusScope.of(context).requestFocus(FocusNode()),
          ),
          const SizedBox(width: 8),
          Text('$commentCount'),
          const Spacer(),
          IconButton(
            icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border),
            onPressed: _toggleSave,
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: _onShare,
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Text(
                '评论 ($commentCount)',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (_isLoadingComments)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: _isLoadingComments
                    ? null
                    : () => _loadComments(refresh: true),
                tooltip: '刷新评论',
              ),
            ],
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _comments.length + (_hasMoreComments ? 1 : 0),
          separatorBuilder: (_, __) => const Divider(indent: 16),
          itemBuilder: (context, idx) {
            if (idx == _comments.length) {
              // 加载更多按钮
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: _isLoadingComments
                      ? const CircularProgressIndicator()
                      : TextButton.icon(
                          onPressed: _loadComments,
                          icon: const Icon(Icons.refresh),
                          label: const Text('加载更多评论'),
                        ),
                ),
              );
            }
            final c = _comments[idx];
            final inFlight = _commentLikeInFlight.contains(c.id);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  onTap: () => _openUserProfile(c.author.id),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: _buildAvatarWidget(c.author.avatar, 16),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.author.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      // 删除按钮（只有作者自己可以看到）
                      if (_currentUserId != null &&
                          c.author.id == _currentUserId)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          color: Colors.red[300],
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _deleteComment(c, isTopLevel: true),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (c.replyTo != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Text(
                            '回复 @${c.replyTo!.name}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                      _buildCommentContentWithMentions(c.content, c.mentions),
                      Row(
                        children: [
                          Text(
                            _formatRelative(c.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          TextButton(
                            onPressed: () => _startReply(c),
                            child: const Text(
                              '回复',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          const Spacer(),
                          Text('${c.likesCount}'),
                          IconButton(
                            icon: Icon(
                              c.isLiked
                                  ? Icons.thumb_up
                                  : Icons.thumb_up_off_alt,
                              size: 18,
                              color: c.isLiked ? Colors.blue : Colors.black87,
                            ),
                            onPressed: inFlight
                                ? null
                                : () => _handleCommentLikePressed(c),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // 显示回复列表
                if (c.hasReplies)
                  Padding(
                    padding: const EdgeInsets.only(left: 56.0),
                    child: Column(
                      children: c.replies.map((reply) {
                        final replyInFlight = _commentLikeInFlight.contains(
                          reply.id,
                        );
                        return ListTile(
                          onTap: () => _openUserProfile(reply.author.id),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          leading: _buildAvatarWidget(reply.author.avatar, 14),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  reply.author.name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              // 删除按钮（只有作者自己可以看到）
                              if (_currentUserId != null &&
                                  reply.author.id == _currentUserId)
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 16,
                                  ),
                                  color: Colors.red[300],
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _deleteComment(
                                    reply,
                                    isTopLevel: false,
                                    parentComment: c,
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (reply.replyTo != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4.0),
                                  child: Text(
                                    '回复 @${reply.replyTo!.name}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                ),
                              _buildCommentContentWithMentions(
                                reply.content,
                                reply.mentions,
                              ),
                              Row(
                                children: [
                                  Text(
                                    _formatRelative(reply.createdAt),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        _startReply(reply, parentId: c.id),
                                    child: const Text(
                                      '回复',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text('${reply.likesCount}'),
                                  IconButton(
                                    icon: Icon(
                                      reply.isLiked
                                          ? Icons.thumb_up
                                          : Icons.thumb_up_off_alt,
                                      size: 16,
                                      color: reply.isLiked
                                          ? Colors.blue
                                          : Colors.black87,
                                    ),
                                    onPressed: replyInFlight
                                        ? null
                                        : () =>
                                              _handleCommentLikePressed(reply),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Future<void> _handleCommentLikePressed(Comment c) async {
    if (_commentLikeInFlight.contains(c.id)) return;
    _commentLikeInFlight.add(c.id);

    final prevLiked = c.isLiked;
    final prevCount = c.likesCount;

    // 乐观更新
    setState(() {
      c.isLiked = !c.isLiked;
      c.likesCount += c.isLiked ? 1 : -1;
    });

    try {
      // 调用后端的评论点赞/取消点赞接口
      final resp = c.isLiked
          ? await ApiService.likeComment(widget.post.id, c.id)
          : await ApiService.unlikeComment(widget.post.id, c.id);

      final status = resp['statusCode'] as int? ?? 500;
      final body = resp['body'] as Map<String, dynamic>?;
      if (status >= 200 && status < 300 && body != null) {
        setState(() {
          if (body.containsKey('likesCount'))
            c.likesCount = body['likesCount'] as int;
          if (body.containsKey('isLiked')) c.isLiked = body['isLiked'] as bool;
        });
      } else {
        // 回滚乐观更新
        setState(() {
          c.isLiked = prevLiked;
          c.likesCount = prevCount;
        });
        final msg = body != null && body['message'] != null
            ? body['message'].toString()
            : '操作失败';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      setState(() {
        c.isLiked = prevLiked;
        c.likesCount = prevCount;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('网络错误，操作未成功')));
    } finally {
      _commentLikeInFlight.remove(c.id);
    }
  }

  Widget _buildBottomCommentInput() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        color: Colors.white,
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: MediaQuery.of(context).padding.bottom == 0
              ? 12
              : MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // @用户选择列表 - 横向滚动，显示在输入框上方（类似小红书风格）
            // 只有当_showMentionList为true时才显示列表（避免提交后还显示）
            if (_showMentionList &&
                (_selectedMentions.isNotEmpty || _mentionCandidates.isNotEmpty))
              Container(
                height: 100,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[200]!, width: 0.5),
                  ),
                ),
                child: _mentionCandidates.isEmpty && _selectedMentions.isEmpty
                    ? const Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.grey,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              '搜索用户中...',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount:
                            _selectedMentions.length +
                            _mentionCandidates
                                .where(
                                  (u) => !_selectedMentions.containsKey(
                                    u.name.toLowerCase(),
                                  ),
                                )
                                .length,
                        itemBuilder: (context, index) {
                          // 先显示已选择的用户（带对勾），再显示未选择的候选用户
                          if (index < _selectedMentions.length) {
                            final user = _selectedMentions.values.elementAt(
                              index,
                            );
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _toggleMentionUser(user),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 65,
                                  margin: const EdgeInsets.only(right: 10),
                                  child: Stack(
                                    children: [
                                      Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Container(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.blue,
                                                width: 2,
                                              ),
                                            ),
                                            child: CircleAvatar(
                                              radius: 24,
                                              backgroundImage:
                                                  user.avatar.isNotEmpty &&
                                                      (user.avatar.startsWith(
                                                            'http://',
                                                          ) ||
                                                          user.avatar
                                                              .startsWith(
                                                                'https://',
                                                              ))
                                                  ? NetworkImage(user.avatar)
                                                  : null,
                                              backgroundColor: Colors.blue[50],
                                              child:
                                                  user.avatar.isEmpty ||
                                                      (!user.avatar.startsWith(
                                                            'http://',
                                                          ) &&
                                                          !user.avatar
                                                              .startsWith(
                                                                'https://',
                                                              ))
                                                  ? Text(
                                                      user.name.isNotEmpty
                                                          ? user.name[0]
                                                                .toUpperCase()
                                                          : '?',
                                                      style: const TextStyle(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.blue,
                                                      ),
                                                    )
                                                  : null,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Container(
                                            constraints: const BoxConstraints(
                                              maxWidth: 65,
                                            ),
                                            child: Text(
                                              user.name,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.blue,
                                                fontWeight: FontWeight.w500,
                                                height: 1.2,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ],
                                      ),
                                      // 对勾标记
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: Container(
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            color: Colors.blue,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          } else {
                            // 显示未选择的候选用户（过滤掉已选择的）
                            final unselectedCandidates = _mentionCandidates
                                .where(
                                  (u) => !_selectedMentions.containsKey(
                                    u.name.toLowerCase(),
                                  ),
                                )
                                .toList();
                            final user =
                                unselectedCandidates[index -
                                    _selectedMentions.length];
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  print('[@功能] 点击了用户: ${user.name}');
                                  // _selectMentionUser 内部已经处理了单选/多选模式的逻辑
                                  _selectMentionUser(user);
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 65,
                                  margin: const EdgeInsets.only(right: 10),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.grey[300]!,
                                            width: 1,
                                          ),
                                        ),
                                        child: CircleAvatar(
                                          radius: 24,
                                          backgroundImage:
                                              user.avatar.isNotEmpty &&
                                                  (user.avatar.startsWith(
                                                        'http://',
                                                      ) ||
                                                      user.avatar.startsWith(
                                                        'https://',
                                                      ))
                                              ? NetworkImage(user.avatar)
                                              : null,
                                          backgroundColor: Colors.grey[200],
                                          child:
                                              user.avatar.isEmpty ||
                                                  (!user.avatar.startsWith(
                                                        'http://',
                                                      ) &&
                                                      !user.avatar.startsWith(
                                                        'https://',
                                                      ))
                                              ? Text(
                                                  user.name.isNotEmpty
                                                      ? user.name[0]
                                                            .toUpperCase()
                                                      : '?',
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        constraints: const BoxConstraints(
                                          maxWidth: 65,
                                        ),
                                        child: Text(
                                          user.name,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black,
                                            fontWeight: FontWeight.w500,
                                            height: 1.2,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }
                        },
                      ),
              ),
            if (_currentReplyTo != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                color: Colors.grey[100],
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '回复 @${_currentReplyTo!.author.name}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: _cancelReply,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    focusNode: _commentFocusNode,
                    decoration: InputDecoration(
                      hintText: _currentReplyTo != null ? '写回复...' : '写评论...',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _submitComment(
                    parentId: _currentReplyParentId,
                    replyTo: _currentReplyTo?.author,
                  ),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(_currentReplyTo != null ? '回复' : '发送'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildTopBar(),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMediaGallery(),
                const SizedBox(height: 8),
                _buildAuthorRow(),
                _buildContent(),
                _buildActionBar(),
                _buildCommentsSection(),
                const SizedBox(height: 16),
              ],
            ),
          ),
          if (_isImageFullscreen) _buildFullscreenOverlay(),
          _buildBottomCommentInput(),
          if (_isDeleting)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.25),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFullscreenOverlay() {
    final images = _imageMedia;
    if (!_isImageFullscreen || images.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.95),
        child: SafeArea(
          child: GestureDetector(
            onTap: _toggleImageFullscreen,
            child: Stack(
              children: [
                PageView.builder(
                  controller: _imagePageController,
                  itemCount: images.length,
                  onPageChanged: (index) {
                    if (_currentImageIndex != index) {
                      setState(() {
                        _currentImageIndex = index;
                      });
                    }
                  },
                  itemBuilder: (_, index) {
                    return Center(
                      child: InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 4.0,
                        child: _buildImageDisplay(
                          images[index],
                          MediaQuery.of(context).size.width,
                          MediaQuery.of(context).size.height,
                          BoxFit.contain,
                        ),
                      ),
                    );
                  },
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_currentImageIndex + 1}/${images.length}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _toggleImageFullscreen,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建头像 Widget，支持本地资源和网络 URL，带错误处理
  Widget _buildAvatarWidget(String avatarPath, double radius) {
    // 判断是否为网络 URL（以 http:// 或 https:// 开头）
    if (avatarPath.startsWith('http://') || avatarPath.startsWith('https://')) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey[300],
        child: ClipOval(
          child: Image.network(
            avatarPath,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Icon(Icons.person, size: radius, color: Colors.grey);
            },
          ),
        ),
      );
    }

    // 处理本地资源路径
    // pubspec.yaml 配置了 assets: - assets/images/，所以使用时应该是 images/xxx
    String assetPath = avatarPath;
    if (assetPath.startsWith('assets/images/')) {
      assetPath = assetPath.substring(14); // 去掉 "assets/images/" 前缀
    } else if (assetPath.startsWith('assets/')) {
      assetPath = assetPath.substring(7); // 去掉 "assets/" 前缀
    }

    // 使用 Image.asset 并添加错误处理
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[300],
      child: ClipOval(
        child: Image.asset(
          assetPath,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Icon(Icons.person, size: radius, color: Colors.grey);
          },
        ),
      ),
    );
  }
}

/// 分享用户选择界面
class _ShareUserSelectionSheet extends StatefulWidget {
  final String currentUserId;
  final Post post;

  const _ShareUserSelectionSheet({
    required this.currentUserId,
    required this.post,
  });

  @override
  State<_ShareUserSelectionSheet> createState() =>
      _ShareUserSelectionSheetState();
}

class _ShareUserSelectionSheetState extends State<_ShareUserSelectionSheet> {
  List<Map<String, dynamic>> _followingUsers = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadFollowingUsers();
  }

  Future<void> _loadFollowingUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 获取当前用户的关注列表
      final result = await ApiService.getFollowing(
        widget.currentUserId,
        page: 0,
        pageSize: 100, // 获取所有关注用户
      );

      if (result['statusCode'] == 200) {
        final body = result['body'];
        // 后端返回的字段是 'users'，不是 'content'
        final users = body['users'] as List<dynamic>? ?? [];
        setState(() {
          _followingUsers = users.map((user) {
            final userMap = user as Map<String, dynamic>;
            // 后端返回的是 ProfileResp，包含 displayName 字段
            return {
              'id': userMap['id']?.toString() ?? '',
              'name':
                  userMap['displayName']?.toString() ??
                  (userMap['email']?.toString() ?? '未知用户'),
              'avatar': userMap['avatar']?.toString(),
            };
          }).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('加载关注列表失败: ${result['body']['message'] ?? '未知错误'}'),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('加载关注列表失败: $e')));
      }
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchQuery.isEmpty) {
      return _followingUsers;
    }
    return _followingUsers.where((user) {
      final name = user['name']?.toString().toLowerCase() ?? '';
      return name.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 顶部拖拽指示器
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 标题
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                const Text(
                  '分享给',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // 搜索框
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: '搜索用户',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          // 用户列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty ? '还没有关注任何人' : '未找到匹配的用户',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 4,
                    ),
                    itemCount: _filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = _filteredUsers[index];
                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundImage:
                                user['avatar'] != null &&
                                    user['avatar'].toString().isNotEmpty
                                ? NetworkImage(user['avatar'].toString())
                                : null,
                            child:
                                user['avatar'] == null ||
                                    user['avatar'].toString().isEmpty
                                ? Text(
                                    (user['name']?.toString().isNotEmpty ??
                                            false)
                                        ? user['name']
                                              .toString()[0]
                                              .toUpperCase()
                                        : '?',
                                    style: const TextStyle(fontSize: 18),
                                  )
                                : null,
                          ),
                          title: Text(
                            user['name']?.toString() ?? '未知用户',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.pop(context, user['id']?.toString());
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// 可点击标签组件
class ClickableTagWidget extends StatelessWidget {
  final String tag;
  final VoidCallback onTap;

  const ClickableTagWidget({
    super.key,
    required this.tag,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
        ),
        child: Text(
          '#$tag',
          style: const TextStyle(
            color: Colors.blue,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// 渲染带可点击标签的正文
class ContentWithClickableTags extends StatelessWidget {
  final String content;
  final List<String> subTags;
  final Function(String) onTagTap;

  const ContentWithClickableTags({
    super.key,
    required this.content,
    required this.subTags,
    required this.onTagTap,
  });

  @override
  Widget build(BuildContext context) {
    // 如果内容为空，返回空容器
    if (content.isEmpty) {
      return const SizedBox.shrink();
    }

    // 使用正则表达式分割文本和标签
    final regex = RegExp(r'(#([^\s#]+))');
    final matches = regex.allMatches(content);

    if (matches.isEmpty) {
      // 没有标签，直接返回文本
      return Text(
        content,
        style: const TextStyle(fontSize: 14, height: 1.6),
      );
    }

    // 构建富文本
    final textSpans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      // 添加匹配前的普通文本
      if (match.start > lastEnd) {
        textSpans.add(TextSpan(
          text: content.substring(lastEnd, match.start),
          style: const TextStyle(fontSize: 14, height: 1.6),
        ));
      }

      // 添加可点击的标签
      final tag = match.group(2)!; // 获取#后面的标签内容
      textSpans.add(TextSpan(
        text: match.group(1), // 完整的#标签文本
        style: const TextStyle(
          fontSize: 14,
          height: 1.6,
          color: Colors.blue,
          fontWeight: FontWeight.w500,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            onTagTap(tag);
          },
      ));

      lastEnd = match.end;
    }

    // 添加剩余的文本
    if (lastEnd < content.length) {
      textSpans.add(TextSpan(
        text: content.substring(lastEnd),
        style: const TextStyle(fontSize: 14, height: 1.6),
      ));
    }

    return RichText(
      text: TextSpan(
        children: textSpans,
        style: const TextStyle(
          fontSize: 14,
          height: 1.6,
          color: Colors.black,
        ),
      ),
    );
  }
}
