// lib/widgets/post_card.dart
/// 帖子卡片（瀑布流子项）
///
/// 职责：
/// - 在瀑布流/Masonry 网格中展示单条帖子，包含封面图、标题、作者与首个标签。
/// - 点击整卡回调 `onTap`，由上层控制导航至详情。
///
/// 设计与布局：
/// - 使用 `LayoutBuilder` 获取实际卡片宽度，根据图片宽高比计算展示高度。
/// - 卡片宽度保持一致，高度完全由图片宽高比决定，实现瀑布流效果。
/// - 图片容器采用 `FittedBox + BoxFit.cover`，并用 `ClipRect` 防止溢出。
/// - 封面上方圆角仅裁剪顶部（与 Card 的圆角保持一致）。
///
/// 图片与状态：
/// - 当 `post.media.isEmpty`：显示占位图标（image_not_supported）。
/// - 图片加载失败（`errorBuilder`）：展示“图片加载失败”的占位内容。
/// - 图片加载渐显（`frameBuilder`）：首帧前透明，帧到达后 300ms 淡入。
///
/// 性能与可用性：
/// - 为保证网格流畅，建议预先提供较为准确的 `imageAspectRatio`。
/// - 本组件不负责缓存与网络加载策略，后续可替换为 `CachedNetworkImage` 等方案。
/// - `onTap` 使用 `InkWell` 提供水波纹与圆角点击反馈。
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/post_model.dart';

/// 点赞按钮组件（独立的状态管理，避免影响整个卡片重建）
class _LikeButton extends StatefulWidget {
  final Post post;
  final Future<bool> Function(Post post)? onLikeTap;

  const _LikeButton({
    Key? key,
    required this.post,
    this.onLikeTap,
  }) : super(key: key);

  @override
  State<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<_LikeButton> {
  late bool _isLiked;
  late int _likesCount;
  bool _isProcessing = false;
  DateTime? _lastTapTime;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLiked;
    _likesCount = widget.post.likesCount;
  }

  @override
  void didUpdateWidget(_LikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果帖子对象更新（例如从详情页返回），同步状态
    if (oldWidget.post.id != widget.post.id ||
        oldWidget.post.isLiked != widget.post.isLiked ||
        oldWidget.post.likesCount != widget.post.likesCount) {
      _isLiked = widget.post.isLiked;
      _likesCount = widget.post.likesCount;
    }
  }

  Future<void> _handleLike() async {
    // 防抖：500ms 内的重复点击忽略
    final now = DateTime.now();
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!) < const Duration(milliseconds: 500)) {
      return;
    }
    _lastTapTime = now;

    if (_isProcessing || widget.onLikeTap == null) return;

    // 乐观更新
    setState(() {
      _isProcessing = true;
      _isLiked = !_isLiked;
      _likesCount += _isLiked ? 1 : -1;
    });

    try {
      final success = await widget.onLikeTap!(widget.post);
      if (!success && mounted) {
        // 如果失败，回滚状态
        setState(() {
          _isLiked = !_isLiked;
          _likesCount += _isLiked ? 1 : -1;
        });
      }
    } catch (e) {
      // 发生错误，回滚状态
      if (mounted) {
        setState(() {
          _isLiked = !_isLiked;
          _likesCount += _isLiked ? 1 : -1;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleLike,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isLiked ? Icons.favorite : Icons.favorite_border,
            size: 16,
            color: _isLiked ? Colors.red : Colors.grey[500],
          ),
          const SizedBox(width: 4),
          Text(
            _formatLikeCount(_likesCount),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatLikeCount(int count) {
    return PostCard._formatLikeCountStatic(count);
  }
}

/// 单个 Post 的展示卡片
class PostCard extends StatefulWidget {
  /// 业务数据：包含标题、作者、媒体列表、标签等
  final Post post;

  /// 点击整卡时的回调（通常用于导航）
  final VoidCallback onTap;

  /// 点击作者时的回调
  final VoidCallback? onAuthorTap;

  /// 点击点赞时的回调（返回是否点赞成功，用于乐观更新）
  final Future<bool> Function(Post post)? onLikeTap;

  /// 是否在卡片右上角显示"未读"红点（用于关注流未查看提醒）
  final bool showUnreadDot;

  const PostCard({
    Key? key,
    required this.post,
    required this.onTap,
    this.onAuthorTap,
    this.onLikeTap,
    this.showUnreadDot = false,
  }) : super(key: key);

  @override
  State<PostCard> createState() => _PostCardState();

  /// 格式化点赞数：超过999进行缩写显示（如1.2k）
  static String _formatLikeCountStatic(int count) {
    if (count < 1000) {
      return count.toString();
    } else if (count < 10000) {
      // 1k - 9.9k
      final kValue = count / 1000.0;
      if (kValue % 1 == 0) {
        return '${kValue.toInt()}k';
      } else {
        return '${kValue.toStringAsFixed(1)}k';
      }
    } else if (count < 1000000) {
      // 10k - 999k
      final kValue = count / 1000.0;
      if (kValue % 1 == 0) {
        return '${kValue.toInt()}k';
      } else {
        return '${kValue.toStringAsFixed(1)}k';
      }
    } else {
      // 1M+
      final mValue = count / 1000000.0;
      if (mValue % 1 == 0) {
        return '${mValue.toInt()}M';
      } else {
        return '${mValue.toStringAsFixed(1)}M';
      }
    }
  }
}

class _PostCardState extends State<PostCard> {
  double? _actualImageWidth;
  double? _actualImageHeight;
  bool _isLoadingImageSize = false;

  @override
  void initState() {
    super.initState();
    // 如果后端返回的尺寸看起来是默认值（800x600），尝试加载图片获取真实尺寸
    if (widget.post.media.isNotEmpty &&
        widget.post.imageNaturalWidth == 800.0 &&
        widget.post.imageNaturalHeight == 600.0) {
      _loadImageSize();
    }
  }

  /// 加载图片获取真实尺寸
  Future<void> _loadImageSize() async {
    if (_isLoadingImageSize || widget.post.media.isEmpty) return;
    
    setState(() {
      _isLoadingImageSize = true;
    });

    try {
      final imageUrl = widget.post.media.first;
      final imageProvider = NetworkImage(imageUrl);
      
      // 使用 ImageProvider.resolve 获取图片信息
      final ImageStream stream = imageProvider.resolve(const ImageConfiguration());
      final Completer<void> completer = Completer<void>();
      
      ImageStreamListener? listener;
      listener = ImageStreamListener((ImageInfo info, bool synchronousCall) {
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
      }, onError: (exception, stackTrace) {
        stream.removeListener(listener!);
        if (!completer.isCompleted) {
          completer.complete();
        }
        if (mounted) {
          setState(() {
            _isLoadingImageSize = false;
          });
        }
      });
      
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

  @override
  Widget build(BuildContext context) {
    // 使用 LayoutBuilder 以获得父约束，从而计算图片展示的目标高度
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth;
        // 计算图片宽高比：优先使用实际加载的图片尺寸，然后是后端返回的尺寸，最后是 imageAspectRatio
        double aspect = 1.0;
        if (widget.post.media.isNotEmpty) {
          // 优先使用实际加载的图片尺寸（如果已加载）
          if (_actualImageWidth != null && _actualImageHeight != null && 
              _actualImageWidth! > 0 && _actualImageHeight! > 0) {
            aspect = _actualImageWidth! / _actualImageHeight!;
          } 
          // 否则使用后端返回的尺寸（如果看起来不是默认值）
          else if (widget.post.imageNaturalWidth > 0 && 
                   widget.post.imageNaturalHeight > 0 &&
                   !(widget.post.imageNaturalWidth == 800.0 && 
                     widget.post.imageNaturalHeight == 600.0)) {
            aspect = widget.post.imageNaturalWidth / widget.post.imageNaturalHeight;
          } 
          // 最后使用 imageAspectRatio
          else if (widget.post.imageAspectRatio > 0) {
            aspect = widget.post.imageAspectRatio;
          }
        }
        // 高度完全由图片宽高比决定，实现瀑布流效果
        // 限制最大高度为350，超过则截断
        final calculatedHeight = cardWidth / aspect;
        final containerHeight = calculatedHeight > 350 ? 350.0 : calculatedHeight;
        
        return Stack(
          children: [
            Card(
              margin: const EdgeInsets.all(3),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 图片区域（若有多图，显示第一张缩略）
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                      child: Container(
                        width: cardWidth,
                        height: containerHeight,
                        color: Colors.grey[100],
                        child: _buildImageContent(
                          cardWidth,
                          containerHeight,
                          containerHeight,
                        ),
                      ),
                    ),

                    // 标题区域
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        widget.post.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // 用户信息 + tags 区域
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Row(
                        children: [
                          // 头像（仅头像可点击）
                          GestureDetector(
                            onTap: widget.onAuthorTap,
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.grey[300],
                              child: ClipOval(
                                child: Image.network(
                                  widget.post.author.avatar,
                                  width: 24,
                                  height: 24,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    // 头像加载失败时的兜底图标
                                    return const Icon(
                                      Icons.person,
                                      size: 16,
                                      color: Colors.grey,
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.post.author.name,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.post.mainDiscipline.isNotEmpty
                                      ? widget.post.mainDiscipline
                                      : '',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // 点赞图标 + 点赞数
                          _LikeButton(
                            post: widget.post,
                            onLikeTap: widget.onLikeTap,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.showUnreadDot)
              Positioned(
                right: 14,
                top: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// 构建封面图内容：
  /// - 无媒体：展示占位图标
  /// - 有媒体：使用 `Image.network` 加载第一张图片，保持原始宽高比
  /// - 错误/加载动画：`errorBuilder` 与 `frameBuilder` 处理兜底与淡入
  Widget _buildImageContent(
    double containerWidth,
    double containerHeight,
    double naturalHeight,
  ) {
    if (widget.post.media.isEmpty) {
      return Container(
        color: Colors.grey[200],
        child: const Center(
          child: Icon(Icons.image_not_supported, color: Colors.grey, size: 36),
        ),
      );
    }

    final imageUrl = widget.post.media.first;

    // 直接使用 Image.network，让图片填充整个容器，保持宽高比
    return Image.network(
      imageUrl,
      width: containerWidth,
      height: containerHeight,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: containerWidth,
          height: containerHeight,
          color: Colors.grey[200],
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image, color: Colors.grey, size: 32),
                SizedBox(height: 8),
                Text(
                  '图片加载失败',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) {
          return child;
        }
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: child,
        );
      },
    );
  }
}
