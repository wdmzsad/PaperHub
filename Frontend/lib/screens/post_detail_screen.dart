// lib/screens/post_detail_screen.dart
// merge request 测试 1104: 单个帖子界面
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/post_model.dart';
import '../services/api_service.dart';

class PostDetailScreen extends StatefulWidget {
  final Post post;
  const PostDetailScreen({Key? key, required this.post}) : super(key: key);

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

/*
================================================================================
 后端对接说明（已整理为注释，放在 `post_detail_screen.dart` 文件末尾）
 目的：记录前端与后端 REST / WebSocket 的契约示例、字段说明与调试建议，便于与后端联调。
================================================================================

1) 认证
 - 前端会通过 LocalStorage.instance.read('auth_token') 读取 token，并在
   ApiService._buildHeaders() 中以 `Authorization: Bearer <token>` 方式发送给后端。
 - 请后端对该 Header 进行校验，未授权返回 401/403 并在 body.message 提供可读提示。

2) REST 接口（建议）
 - 获取评论（分页）
   GET /posts/{postId}/comments?page=1&pageSize=20&sort=time
   Response 200:
   {
     "comments": [ {comment}, ... ],  // 顶层评论（每项可包含 replies 列表）
     "total": 123,
     "page": 1,
     "pageSize": 20
   }

 - 发布评论（顶层或回复）
   POST /posts/{postId}/comments
   Body: { "content": "...", "parentId": "c_123"?, "replyToId": "u_456"? }
   Response 201/200:
   { "comment": { ...new comment object... } }

 - 更新评论
   PUT /posts/{postId}/comments/{commentId}
   Body: { "content": "new content" }
   Response: { "comment": { ... } }

 - 删除评论
   DELETE /posts/{postId}/comments/{commentId}
   Response: 204 或 { "message": "deleted" }

 - 点赞 / 取消点赞评论
   POST /posts/{postId}/comments/{commentId}/like
   DELETE /posts/{postId}/comments/{commentId}/like
   Response: { "likesCount": 10, "isLiked": true }

3) comment 对象（建议字段）
 {
   "id": "c_123",
   "author": {"id":"u1","name":"Alice","avatar":"...","affiliation":"..."},
   "content": "...",
   "parentId": null,        // 顶层评论为 null
   "replyTo": { ... }?,     // 被回复的用户（可选）
   "likesCount": 5,
   "isLiked": false,        // 当前用户是否已点赞（若后端能计算）
   "replies": [ ... ],      // 可选：子回复列表
   "createdAt": "2025-11-06T08:00:00Z"
 }

4) WebSocket 事件（建议格式）
 - 连接： ws://<host>/ws/posts/{postId} 或统一 topic 方案
 - 事件 JSON：必须包含 `type` 字段
   1) 帖子点赞更新
      {"type":"like_update","likesCount":123,"isLiked":true}
   2) 评论点赞更新
      {"type":"comment_like_update","commentId":"c_123","likesCount":5,"isLiked":true}
   3) 新评论
      {"type":"comment_created","comment":{...comment object...}}
   4) 评论更新
      {"type":"comment_updated","comment":{...}}
   5) 评论删除
      {"type":"comment_deleted","commentId":"c_123"}

 - 本文件中已实现对上述事件的处理：
   _initWebSocket() 里解析 type 并调用 _handleCommentCreated / _handleCommentUpdated / _handleCommentDeleted
   注意：前端实现已兼容 comment 在 'comment'、'payload' 或 'data' 字段中的情况，但建议统一使用 'comment'

5) 前端行为与容错策略
 - 乐观更新：点赞、发送评论时前端会做乐观更新以提升响应感，若后端返回错误会回滚并通过 SnackBar 提示用户。
 - 防重：提交评论使用 _isSubmittingComment 防止重复提交；点赞使用 _commentLikeInFlight 防止并发请求。
 - 时间解析：后端请使用 ISO8601（UTC）字符串，前端使用 DateTime.parse 解析。
 - 子回复分页：若回复很多，建议后端提供 /comments/{commentId}/replies 分页接口；否则可在 GET /posts/{postId}/comments 返回 replies 字段（限数量）。

6) 推荐的对接与调试步骤（给后端同学）
 - 确认接口路径与字段（上述示例），后端在 Postman 中演示以下流程：
   1) GET 评论分页
   2) POST 新评论（顶层 & 回复）并返回 comment
   3) POST/DELETE 点赞并返回 likesCount/isLiked
   4) 在另一个客户端通过 WS 推送 comment_created/comment_like_update，观察前端是否实时更新
 - 前端准备：启动应用（flutter run），打开帖子详情页并观察控制台/SnackBar 的错误提示；若 token 验证失败，请在 LocalStorage 中填入有效 token。

7) 切换 Mock -> 真正后端（简要步骤）
 - 将 ApiService.baseUrl 指向真实后端地址
 - 确认后端返回结构（尤其 comment 字段/时间格式/likesCount/isLiked）并调整 Comment.fromJson（位于 lib/models/post_model.dart）
 - 删除或移动 mock_api_service.dart（若不再需要）

8) 常见问题与建议
 - 若后端不返回 isLiked，可考虑前端在获取当前用户点赞记录后合并；或后端提供单独的用户点赞接口。
 - 高频事件（如点赞）可能需要后端做节流/合并，减少 WS 消息量。
 - 对于权限错误（401/403），前端应引导用户重新登录或清理缓存的 token。

================================================================================
 备注：如需我把这份注释提取为独立文档 `BACKEND_INTEGRATION.md` 或根据后端给出的真实样例调整解析代码，我可以继续修改。
================================================================================
*/

class _PostDetailScreenState extends State<PostDetailScreen> with SingleTickerProviderStateMixin {
  WebSocketChannel? _wsChannel;
  late bool isLiked;
  late bool isSaved;
  late int likeCount;
  late int commentCount;
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
  final Set<String> _commentLikeInFlight = {}; // commentId 集合
  bool _isSubmittingComment = false;
  final TextEditingController _commentController = TextEditingController();
  late AnimationController _heartCtrl;
  late Animation<double> _heartScale;
  bool _showBigHeart = false;

  @override
  void initState() {
    super.initState();
    isLiked = widget.post.isLiked;
    isSaved = widget.post.isSaved;
    likeCount = widget.post.likesCount;
    commentCount = widget.post.commentsCount;

    _heartCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _heartScale = Tween(begin: 0.3, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)).animate(_heartCtrl);
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
    // 加载评论
    _loadComments();

    // WebSocket 实时点赞监听
    _initWebSocket();
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
        final commentsData = (body['comments'] as List<dynamic>?) ?? <dynamic>[];
        final total = body['total'] as int? ?? commentsData.length;

        final newComments = commentsData.map((c) => Comment.fromJson(c as Map<String, dynamic>)).toList();

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
        final msg = body != null && body['message'] != null ? body['message'].toString() : '加载评论失败';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('加载评论失败')),
      );
    } finally {
      setState(() {
        _isLoadingComments = false;
      });
    }
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    _commentController.dispose();
    _commentFocusNode.dispose();
    _wsChannel?.sink.close();
    super.dispose();
  }

  void _startReply(Comment comment, {String? parentId}) {
    setState(() {
      _currentReplyTo = comment;
      _currentReplyParentId = parentId ?? comment.id;
      _commentController.text = '@${comment.author.name} ';
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
    final wsUrl = 'ws://localhost:8080/ws/posts/${widget.post.id}';
    _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
    _wsChannel!.stream.listen((event) {
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
            if (data.containsKey('likesCount')) likeCount = data['likesCount'] as int;
            if (data.containsKey('isLiked')) isLiked = data['isLiked'] as bool;
          });
        } else if (type == 'comment_like_update' && data['commentId'] != null) {
          // 评论点赞变更
          final commentId = data['commentId'] as String;
          final idx = _comments.indexWhere((c) => c.id == commentId);
          if (idx != -1) {
            setState(() {
              if (data.containsKey('likesCount')) _comments[idx].likesCount = data['likesCount'] as int;
              if (data.containsKey('isLiked')) _comments[idx].isLiked = data['isLiked'] as bool;
            });
          } else {
            // 可能是子回复的点赞变化
            for (var parent in _comments) {
              final ridx = parent.replies.indexWhere((r) => r.id == commentId);
              if (ridx != -1) {
                setState(() {
                  if (data.containsKey('likesCount')) parent.replies[ridx].likesCount = data['likesCount'] as int;
                  if (data.containsKey('isLiked')) parent.replies[ridx].isLiked = data['isLiked'] as bool;
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
    }, onError: (err) {
      // 可选：记录错误或做重连策略
    }, onDone: () {
      // 可选：自动重连（根据实际需要实现）
    });
  }

  void _handleCommentCreated(Map<String, dynamic> data) {
    // 期望 payload 在 data['comment'] 或 data['payload'] 中
    final commentJson = (data['comment'] ?? data['payload'] ?? data['data']) as Map<String, dynamic>?;
    if (commentJson == null) return;

    try {
      final newComment = Comment.fromJson(commentJson);

      setState(() {
        // 防止重复插入：如果已有同 id，忽略
        final existsTop = _comments.any((c) => c.id == newComment.id);
        if (existsTop) return;

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
            // 父评论不在当前页/列表中，作为降级处理，把回复也插为顶层（可根据需求改为忽略）
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
    final commentJson = (data['comment'] ?? data['payload'] ?? data['data']) as Map<String, dynamic>?;
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
    final commentId = (data['commentId'] ?? data['id'] ?? (data['payload'] is Map ? data['payload']['id'] : null)) as String?;
    if (commentId == null) return;

    setState(() {
      // 从顶层删除
      final tIdx = _comments.indexWhere((c) => c.id == commentId);
      if (tIdx != -1) {
        _comments.removeAt(tIdx);
        commentCount = (commentCount > 0) ? commentCount - 1 : 0;
        widget.post.commentsCount = commentCount;
        return;
      }

      // 从子回复中删除
      for (var parent in _comments) {
        final rIdx = parent.replies.indexWhere((r) => r.id == commentId);
        if (rIdx != -1) {
          parent.replies.removeAt(rIdx);
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
      final resp = isLiked ? await ApiService.likePost(widget.post.id) : await ApiService.unlikePost(widget.post.id);
      final status = (resp['statusCode'] ?? 500) as int;
      final body = resp['body'] as Map<String, dynamic>?;
      if (status >= 200 && status < 300) {
        // 如果后端返回了最新计数，则以后端为准
        if (body != null) {
          setState(() {
            if (body.containsKey('likesCount')) likeCount = body['likesCount'] as int;
            if (body.containsKey('isLiked')) isLiked = body['isLiked'] as bool;
            widget.post.likesCount = likeCount;
            widget.post.isLiked = isLiked;
          });
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
        final msg = body != null && body['message'] != null ? body['message'] : '点赞失败';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg.toString())));
      }
    } catch (e) {
      // 网络或解析错误 -> 回滚
      setState(() {
        isLiked = previousLiked;
        likeCount = previousCount;
        widget.post.isLiked = previousLiked;
        widget.post.likesCount = previousCount;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('网络错误，点赞未成功')));
    } finally {
      _postLikeInFlight = false;
    }
  }

  void _toggleSave() {
    setState(() {
      isSaved = !isSaved;
      widget.post.isSaved = isSaved;
    });
    // TODO: 调用后端 save/unsave
  }

  void _onShare() {
    // TODO: 调用分享 API 或复制链接
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('分享（演示）')));
  }

  Future<void> _submitComment({String? parentId, Author? replyTo}) async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    if (_isSubmittingComment) return;

    setState(() {
      _isSubmittingComment = true;
    });

    try {
      // 调用真实后端 API 创建评论
      final resp = await ApiService.createComment(
        widget.post.id,
        text,
        parentId: parentId,
        replyToId: replyTo?.id,
      );

      final status = resp['statusCode'] as int? ?? 500;
      final body = resp['body'] as Map<String, dynamic>?;
      if (status >= 200 && status < 300 && body != null) {
        // 期望后端返回 {'comment': {...}}
        final commentJson = (body['comment'] as Map<String, dynamic>?) ?? body;
        final newComment = Comment.fromJson(commentJson);
        setState(() {
          if (parentId == null) {
            // 顶层评论
            _comments.insert(0, newComment);
            commentCount += 1;
            widget.post.commentsCount = commentCount;
          } else {
            // 回复评论：尝试找到父评论并追加
            final parentIndex = _comments.indexWhere((c) => c.id == parentId);
            if (parentIndex != -1) {
              _comments[parentIndex].replies.add(newComment);
            }
          }
          _commentController.clear();
          if (_currentReplyTo != null) {
            _cancelReply(); // 清除回复状态
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('评论发表成功')));
      } else {
        final msg = body != null && body['message'] != null ? body['message'].toString() : '评论失败';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('网络错误，评论未成功')),
      );
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
          onPressed: () {
            showModalBottomSheet(
              context: context,
              builder: (_) => SafeArea(
                child: Wrap(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.flag),
                      title: const Text('举报'),
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已举报（演示）')));
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.copy),
                      title: const Text('复制链接'),
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('链接已复制（演示）')));
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMediaGallery() {
    return GestureDetector(
      onDoubleTap: _toggleLike,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            height: 320,
            child: PageView(
              children: widget.post.media.isNotEmpty
                  ? widget.post.media.map((m) {
                      return Image.asset(m, fit: BoxFit.cover, width: double.infinity, height: 320, errorBuilder: (_, __, ___) {
                        return Container(color: Colors.grey[200], height: 320, child: const Center(child: Icon(Icons.broken_image, size: 48, color: Colors.grey)));
                      });
                    }).toList()
                  : [Container(color: Colors.grey[200], height: 320, child: const Center(child: Icon(Icons.image_not_supported, size: 48, color: Colors.grey)))],
            ),
          ),
          Positioned(
            child: _showBigHeart
                ? ScaleTransition(
                    scale: _heartScale,
                    child: const Icon(Icons.favorite, color: Colors.redAccent, size: 100),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthorRow() {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: Colors.grey[300],
        child: ClipOval(
          child: Image.asset(widget.post.author.avatar, width: 40, height: 40, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person)),
        ),
      ),
      title: Text(widget.post.author.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        '${widget.post.author.affiliation ?? ''} • ${_formatRelative(widget.post.createdAt)}',
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      trailing: ElevatedButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('关注（演示）')));
        },
        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
        child: const Text('+ 关注', style: TextStyle(fontSize: 13)),
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.post.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(widget.post.content, style: const TextStyle(fontSize: 14, height: 1.6)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: widget.post.tags.map((t) => Chip(label: Text(t, style: const TextStyle(fontSize: 12)))).toList()),
        const SizedBox(height: 10),
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
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('打开 ${att.fileName}（演示）')));
                      },
                      icon: const Icon(Icons.picture_as_pdf),
                      label: Text(att.fileName),
                    ),
                    const SizedBox(width: 12),
                    Text(' • ${(att.sizeBytes / 1024).toStringAsFixed(0)} KB', style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 8),
        if (widget.post.doi != null)
          Text('DOI: ${widget.post.doi}', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
        if (widget.post.journal != null)
          Text('${widget.post.journal}${widget.post.year != null ? ' · ${widget.post.year}' : ''}', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
      ]),
    );
  }

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.15)))),
      child: Row(
        children: [
          IconButton(icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? Colors.red : Colors.black87), onPressed: _toggleLike),
          Text('$likeCount'),
          const SizedBox(width: 12),
          IconButton(icon: const Icon(Icons.mode_comment_outlined), onPressed: () => FocusScope.of(context).requestFocus(FocusNode())),
          const SizedBox(width: 8),
          Text('$commentCount'),
          const Spacer(),
          IconButton(icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border), onPressed: _toggleSave),
          IconButton(icon: const Icon(Icons.share_outlined), onPressed: _onShare),
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
              Text('评论 ($commentCount)', style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              if (_isLoadingComments)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: _isLoadingComments ? null : () => _loadComments(refresh: true),
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: AssetImage(c.author.avatar),
                  ),
                  title: Text(c.author.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (c.replyTo != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Text(
                            '回复 @${c.replyTo!.name}',
                            style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                          ),
                        ),
                      Text(c.content, style: const TextStyle(fontSize: 13)),
                      Row(
                        children: [
                          Text(
                            _formatRelative(c.createdAt),
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          TextButton(
                            onPressed: () => _startReply(c),
                            child: const Text('回复', style: TextStyle(fontSize: 12)),
                          ),
                          const Spacer(),
                          Text('${c.likesCount}'),
                          IconButton(
                            icon: Icon(
                              c.isLiked ? Icons.thumb_up : Icons.thumb_up_off_alt,
                              size: 18,
                              color: c.isLiked ? Colors.blue : Colors.black87,
                            ),
                            onPressed: inFlight ? null : () => _handleCommentLikePressed(c),
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
                        final replyInFlight = _commentLikeInFlight.contains(reply.id);
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.grey[300],
                            backgroundImage: AssetImage(reply.author.avatar),
                          ),
                          title: Text(reply.author.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (reply.replyTo != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4.0),
                                  child: Text(
                                    '回复 @${reply.replyTo!.name}',
                                    style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                                  ),
                                ),
                              Text(reply.content, style: const TextStyle(fontSize: 13)),
                              Row(
                                children: [
                                  Text(
                                    _formatRelative(reply.createdAt),
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                  TextButton(
                                    onPressed: () => _startReply(reply, parentId: c.id),
                                    child: const Text('回复', style: TextStyle(fontSize: 12)),
                                  ),
                                  const Spacer(),
                                  Text('${reply.likesCount}'),
                                  IconButton(
                                    icon: Icon(
                                      reply.isLiked ? Icons.thumb_up : Icons.thumb_up_off_alt,
                                      size: 16,
                                      color: reply.isLiked ? Colors.blue : Colors.black87,
                                    ),
                                    onPressed: replyInFlight ? null : () => _handleCommentLikePressed(reply),
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
          if (body.containsKey('likesCount')) c.likesCount = body['likesCount'] as int;
          if (body.containsKey('isLiked')) c.isLiked = body['isLiked'] as bool;
        });
      } else {
        // 回滚乐观更新
        setState(() {
          c.isLiked = prevLiked;
          c.likesCount = prevCount;
        });
        final msg = body != null && body['message'] != null ? body['message'].toString() : '操作失败';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      setState(() {
        c.isLiked = prevLiked;
        c.likesCount = prevCount;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('网络错误，操作未成功')),
      );
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
          bottom: MediaQuery.of(context).padding.bottom == 0 ? 12 : MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_currentReplyTo != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
          _buildBottomCommentInput(),
        ],
      ),
    );
  }
}
