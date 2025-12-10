package com.example.paperhub.like;

import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserStatus;
import com.example.paperhub.comment.Comment;
import com.example.paperhub.comment.CommentRepository;
import com.example.paperhub.notification.NotificationService;
import com.example.paperhub.post.Post;
import com.example.paperhub.post.PostRepository;
import com.example.paperhub.post.PostService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;

@Service
public class LikeService {
    private final PostLikeRepository postLikeRepository;
    private final CommentLikeRepository commentLikeRepository;
    private final PostRepository postRepository;
    private final CommentRepository commentRepository;
    private final PostService postService;
    private final NotificationService notificationService;

    public LikeService(
            PostLikeRepository postLikeRepository,
            CommentLikeRepository commentLikeRepository,
            PostRepository postRepository,
            CommentRepository commentRepository,
            PostService postService,
            NotificationService notificationService) {
        this.postLikeRepository = postLikeRepository;
        this.commentLikeRepository = commentLikeRepository;
        this.postRepository = postRepository;
        this.commentRepository = commentRepository;
        this.postService = postService;
        this.notificationService = notificationService;
    }

    /**
     * 点赞帖子（只点赞，不切换）1115陈佳怡修改逻辑
     */
    @Transactional
    public boolean likePost(Long postId, User user) {
        ensureUserCanInteract(user);
        Post post = postRepository.findById(postId)
            .orElseThrow(() -> new IllegalArgumentException("帖子不存在"));
        
        // 检查是否已经点赞
        Optional<PostLike> existingLike = postLikeRepository.findByPostAndUser(post, user);
        if (existingLike.isPresent()) {
            // 已经点赞，直接返回成功
            return true;
        }

        // 创建新的点赞记录
        PostLike like = new PostLike();
        like.setPost(post);
        like.setUser(user);
        postLikeRepository.save(like);

        // 更新帖子点赞数（从数据库统计，确保一致性）
        long actualCount = postLikeRepository.countByPostId(postId);
        post.setLikesCount((int) actualCount);
        postRepository.save(post);
        
        // 创建通知
        try {
            notificationService.createPostLikeNotification(user, postId);
        } catch (Exception e) {
            // 通知创建失败不影响点赞操作
            System.err.println("创建点赞通知失败: " + e.getMessage());
        }
        
        return true; // 点赞成功
    }

    /**
     * 取消点赞帖子
     */
    @Transactional
    public boolean unlikePost(Long postId, User user) {
        ensureUserCanInteract(user);
        Post post = postRepository.findById(postId)
            .orElseThrow(() -> new IllegalArgumentException("帖子不存在"));
        
        Optional<PostLike> existingLike = postLikeRepository.findByPostAndUser(post, user);
        if (existingLike.isEmpty()) {
            // 未点赞，直接返回成功（幂等性）
            return true;
        }

        // 删除点赞记录
        postLikeRepository.delete(existingLike.get());
        
        // 更新帖子点赞数（从数据库统计，确保一致性）
        long actualCount = postLikeRepository.countByPostId(postId);
        post.setLikesCount((int) actualCount);
        postRepository.save(post);
        
        return true;
    }

    /**
     * 检查用户是否已点赞帖子
     */
    public boolean isPostLiked(Long postId, Long userId) {
        return postLikeRepository.existsByPostIdAndUserId(postId, userId);
    }

    /**
     * 获取帖子的点赞数（从数据库统计，确保准确性）
     */
    public long getPostLikesCount(Long postId) {
        try {
            long count = postLikeRepository.countByPostId(postId);
            // 同步更新Post实体的likesCount字段，保持一致性
            postRepository.findById(postId).ifPresent(post -> {
                if (post.getLikesCount() != (int) count) {
                    post.setLikesCount((int) count);
                    postRepository.save(post);
                }
            });
            return count;
        } catch (Exception e) {
            System.err.println("获取点赞数失败: " + e.getMessage());
            e.printStackTrace();
            // 如果查询失败，返回0，避免影响主流程
            return 0;
        }
    }

    /**
     * 点赞评论（只点赞，不切换）
     */
    @Transactional
    public boolean likeComment(Long commentId, User user) {
        ensureUserCanInteract(user);
        Comment comment = commentRepository.findById(commentId)
            .orElseThrow(() -> new IllegalArgumentException("评论不存在"));
        
        // 检查是否已经点赞
        Optional<CommentLike> existingLike = commentLikeRepository.findByCommentAndUser(comment, user);
        if (existingLike.isPresent()) {
            // 已经点赞，直接返回成功
            return true;
        }

        // 创建新的点赞记录
        CommentLike like = new CommentLike();
        like.setComment(comment);
        like.setUser(user);
        commentLikeRepository.save(like);
        
        // 更新评论点赞数（从数据库统计，确保一致性）
        long actualCount = commentLikeRepository.countByCommentId(commentId);
        comment.setLikesCount((int) actualCount);
        commentRepository.save(comment);
        
        // 创建通知
        try {
            notificationService.createCommentLikeNotification(user, commentId);
        } catch (Exception e) {
            // 通知创建失败不影响点赞操作
            System.err.println("创建评论点赞通知失败: " + e.getMessage());
        }
        
        return true; // 点赞成功
    }

    /**
     * 取消点赞评论
     */
    @Transactional
    public boolean unlikeComment(Long commentId, User user) {
        ensureUserCanInteract(user);
        Comment comment = commentRepository.findById(commentId)
            .orElseThrow(() -> new IllegalArgumentException("评论不存在"));
        
        Optional<CommentLike> existingLike = commentLikeRepository.findByCommentAndUser(comment, user);
        if (existingLike.isEmpty()) {
            // 未点赞，直接返回成功（幂等性）
            return true;
        }

        // 删除点赞记录
        commentLikeRepository.delete(existingLike.get());
        
        // 更新评论点赞数（从数据库统计，确保一致性）
        long actualCount = commentLikeRepository.countByCommentId(commentId);
        comment.setLikesCount((int) actualCount);
        commentRepository.save(comment);
        
        return true;
    }

    /**
     * 检查用户是否已点赞评论
     */
    public boolean isCommentLiked(Long commentId, Long userId) {
        return commentLikeRepository.existsByCommentIdAndUserId(commentId, userId);
    }

    /**
     * 获取评论的点赞数（从数据库统计，确保准确性）
     */
    public long getCommentLikesCount(Long commentId) {
        try {
            long count = commentLikeRepository.countByCommentId(commentId);
            // 同步更新Comment实体的likesCount字段，保持一致性
            commentRepository.findById(commentId).ifPresent(comment -> {
                if (comment.getLikesCount() != (int) count) {
                    comment.setLikesCount((int) count);
                    commentRepository.save(comment);
                }
            });
            return count;
        } catch (Exception e) {
            System.err.println("获取评论点赞数失败: " + e.getMessage());
            e.printStackTrace();
            // 如果查询失败，返回0，避免影响主流程
            return 0;
        }
    }

    private void ensureUserCanInteract(User user) {
        if (user == null) {
            throw new IllegalArgumentException("未认证用户无法执行此操作");
        }
        if (user.getStatus() == UserStatus.BANNED) {
            throw new IllegalArgumentException("账号已被封禁，无法执行此操作");
        }
        if (user.getStatus() == UserStatus.SILENT) {
            java.time.Instant muteUntil = user.getMuteUntil();
            if (muteUntil == null || java.time.Instant.now().isBefore(muteUntil)) {
                throw new IllegalArgumentException("账号被禁言中，暂时无法点赞");
            }
        }
    }
}

