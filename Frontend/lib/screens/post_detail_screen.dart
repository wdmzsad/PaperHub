// lib/screens/post_detail_screen.dart
//merge request测试1104 单个帖子界面
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../services/api_service.dart';

class PostDetailScreen extends StatefulWidget {
  final Post post;
  const PostDetailScreen({Key? key, required this.post}) : super(key: key);

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> with SingleTickerProviderStateMixin {
  late bool isLiked;
  late bool isSaved;
  late int likeCount;
  late int commentCount;
  // 本地缓存的评论（可来自后端），用于演示评论点赞
  late List<Comment> _comments;
  // 防止重复请求
  bool _postLikeInFlight = false;
  final Set<String> _commentLikeInFlight = {}; // commentId 集合
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
    // 初始化评论（若 Post 已有 comments 列表则使用，否则构造示例）
  _comments = widget.post.comments.isNotEmpty
        ? List<Comment>.from(widget.post.comments)
        : List.generate(
            4,
            (i) => Comment(
                  id: '${widget.post.id}_c_$i',
                  authorId: 'user_${i + 1}',
                  authorName: '用户_${i + 1}',
                  content: '示例评论 #${i + 1}：这是用户的观点或问题。',
                  likesCount: i % 3,
                  isLiked: false,
                ));
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    _commentController.dispose();
    super.dispose();
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

  void _submitComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      commentCount += 1;
      widget.post.commentsCount = commentCount;
      _commentController.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('评论已提交（演示）')));
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
          child: Text('评论 ($commentCount)', style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _comments.length,
          separatorBuilder: (_, __) => const Divider(indent: 16),
          itemBuilder: (context, idx) {
            final c = _comments[idx];
            final inFlight = _commentLikeInFlight.contains(c.id);
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: CircleAvatar(radius: 16, backgroundColor: Colors.grey[300], child: const Icon(Icons.person, size: 16)),
              title: Text(c.authorName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: Text(c.content, style: const TextStyle(fontSize: 13)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('${c.likesCount}'),
                const SizedBox(width: 6),
                IconButton(
                  icon: Icon(c.isLiked ? Icons.thumb_up : Icons.thumb_up_off_alt, size: 18, color: c.isLiked ? Colors.blue : Colors.black87),
                  onPressed: inFlight ? null : () => _handleCommentLikePressed(c),
                ),
              ]),
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
      final resp = c.isLiked ? await ApiService.likeComment(widget.post.id, c.id) : await ApiService.unlikeComment(widget.post.id, c.id);
      final status = (resp['statusCode'] ?? 500) as int;
      final body = resp['body'] as Map<String, dynamic>?;
      if (status >= 200 && status < 300) {
        if (body != null) {
          setState(() {
            if (body.containsKey('likesCount')) c.likesCount = body['likesCount'] as int;
            if (body.containsKey('isLiked')) c.isLiked = body['isLiked'] as bool;
          });
        }
      } else {
        setState(() {
          c.isLiked = prevLiked;
          c.likesCount = prevCount;
        });
        final msg = body != null && body['message'] != null ? body['message'] : '操作失败';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg.toString())));
      }
    } catch (e) {
      setState(() {
        c.isLiked = prevLiked;
        c.likesCount = prevCount;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('网络错误，操作未成功')));
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
        padding: EdgeInsets.only(left: 12, right: 12, bottom: MediaQuery.of(context).padding.bottom == 0 ? 12 : MediaQuery.of(context).padding.bottom),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  hintText: '写评论...',
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
              onPressed: _submitComment,
              child: const Text('发送'),
              style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
            )
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
