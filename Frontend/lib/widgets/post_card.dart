// lib/widgets/post_card.dart
/// 帖子卡片（瀑布流子项）
///
/// 职责：
/// - 在瀑布流/Masonry 网格中展示单条帖子，包含封面图、标题、作者与首个标签。
/// - 点击整卡回调 `onTap`，由上层控制导航至详情。
///
/// 设计与布局：
/// - 使用 `LayoutBuilder` 获取实际卡片宽度，根据图片宽高比计算展示高度。
/// - 图片高度上限 `maxImageHeight` 用于避免过长图片撑高网格导致体验不佳。
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
import 'package:flutter/material.dart';
import '../models/post_model.dart';

/// 单个 Post 的展示卡片
class PostCard extends StatelessWidget {
  /// 业务数据：包含标题、作者、媒体列表、标签等
  final Post post;
  /// 点击整卡时的回调（通常用于导航）
  final VoidCallback onTap;
  /// 图片展示高度上限（避免极端长图影响瀑布流体验）
  final double maxImageHeight;

  const PostCard({
    Key? key,
    required this.post,
    required this.onTap,
    this.maxImageHeight = 250,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 使用 LayoutBuilder 以获得父约束，从而计算图片展示的目标高度
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth;
        // 如果 media 非空则使用第一张图的 aspect ratio，否则默认 1.0
        final double aspect = post.media.isNotEmpty ? post.imageAspectRatio : 1.0;
        final calculatedHeight = cardWidth / aspect;
        final containerHeight = calculatedHeight > maxImageHeight ? maxImageHeight : calculatedHeight;

        return Card(
          margin: const EdgeInsets.all(8),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Column(
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
                      calculatedHeight,
                    ),
                  ),
                ),

                // 标题区域
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    post.title,
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
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.grey[300],
                        child: ClipOval(
                          child: Image.network(
                            post.author.avatar,
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
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.author.name,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              post.tags.isNotEmpty ? '#${post.tags.first}' : '',
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
                      Icon(Icons.more_horiz, size: 18, color: Colors.grey[500]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 构建封面图内容：
  /// - 无媒体：展示占位图标
  /// - 有媒体：使用 `Image.network` 加载第一张图片，`FittedBox` 等比裁切填充
  /// - 错误/加载动画：`errorBuilder` 与 `frameBuilder` 处理兜底与淡入
  Widget _buildImageContent(
    double containerWidth,
    double containerHeight,
    double naturalHeight,
  ) {
    if (post.media.isEmpty) {
      return Container(
        color: Colors.grey[200],
        child: const Center(
          child: Icon(Icons.image_not_supported, color: Colors.grey, size: 36),
        ),
      );
    }

    final imageUrl = post.media.first;

    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        alignment: Alignment.center,
        child: SizedBox(
          width: containerWidth,
          height: naturalHeight,
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
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
          ),
        ),
      ),
    );
  }
}
