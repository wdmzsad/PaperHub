package com.example.paperhub.comment;

import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserRepository;
import com.example.paperhub.notification.NotificationService;
import com.example.paperhub.post.Post;
import com.example.paperhub.post.PostRepository;
import com.example.paperhub.post.PostService;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

@Service
public class CommentService {
    private final CommentRepository commentRepository;
    private final PostRepository postRepository;
    private final UserRepository userRepository;
    private final PostService postService;
    private final NotificationService notificationService;

    public CommentService(
            CommentRepository commentRepository,
            PostRepository postRepository,
            UserRepository userRepository,
            PostService postService,
            NotificationService notificationService) {
        this.commentRepository = commentRepository;
        this.postRepository = postRepository;
        this.userRepository = userRepository;
        this.postService = postService;
        this.notificationService = notificationService;
    }

    /**
     * 获取帖子的评论列表（分页）
     */
    public Page<Comment> getComments(Long postId, int page, int pageSize, String sort) {
        Pageable pageable = PageRequest.of(page - 1, pageSize);
        
        if ("hot".equals(sort)) {
            return commentRepository.findTopLevelCommentsByPostIdOrderByLikesDesc(postId, pageable);
        } else {
            return commentRepository.findByPostIdAndParentIsNullOrderByCreatedAtDesc(postId, pageable);
        }
    }

    /**
     * 创建评论
     */
    @Transactional
    public Comment createComment(Long postId, String content, User author, Long parentId, Long replyToId) {
        Post post = postRepository.findById(postId)
            .orElseThrow(() -> new IllegalArgumentException("帖子不存在"));
        
        Comment comment = new Comment();
        comment.setPost(post);
        comment.setAuthor(author);
        comment.setContent(content);
        comment.setCreatedAt(Instant.now());
        comment.setUpdatedAt(Instant.now());

        // 如果是回复
        if (parentId != null) {
            Comment parent = commentRepository.findById(parentId)
                .orElseThrow(() -> new IllegalArgumentException("父评论不存在"));
            comment.setParent(parent);
        }

        // 设置被回复的用户
        if (replyToId != null) {
            User replyTo = userRepository.findById(replyToId)
                .orElseThrow(() -> new IllegalArgumentException("被回复的用户不存在"));
            comment.setReplyTo(replyTo);
        }

        Comment saved = commentRepository.save(comment);
        
        // 更新帖子的评论数
        postService.incrementCommentsCount(postId);
        
        // 创建通知
        try {
            notificationService.createCommentNotification(author, postId, saved.getId(), replyToId != null ? userRepository.findById(replyToId).orElse(null) : null);
        } catch (Exception e) {
            // 通知创建失败不影响评论操作
            System.err.println("创建评论通知失败: " + e.getMessage());
        }
        
        return saved;
    }

    /**
     * 更新评论
     */
    @Transactional
    public Comment updateComment(Long commentId, String content, User user) {
        Comment comment = commentRepository.findById(commentId)
            .orElseThrow(() -> new IllegalArgumentException("评论不存在"));
        
        // 检查权限：只有评论作者可以更新
        if (!comment.getAuthor().getId().equals(user.getId())) {
            throw new IllegalArgumentException("无权修改此评论");
        }

        comment.setContent(content);
        comment.setUpdatedAt(Instant.now());
        return commentRepository.save(comment);
    }

    /**
     * 删除评论
     */
    @Transactional
    public void deleteComment(Long commentId, User user) {
        Comment comment = commentRepository.findById(commentId)
            .orElseThrow(() -> new IllegalArgumentException("评论不存在"));
        
        // 检查权限：评论作者或帖子作者可以删除
        boolean isCommentAuthor = comment.getAuthor().getId().equals(user.getId());
        boolean isPostAuthor = comment.getPost().getAuthor().getId().equals(user.getId());
        
        if (!isCommentAuthor && !isPostAuthor) {
            throw new IllegalArgumentException("无权删除此评论");
        }

        // 如果有子回复，需要先删除子回复
        List<Comment> replies = commentRepository.findByParentIdOrderByCreatedAtAsc(commentId);
        for (Comment reply : replies) {
            commentRepository.delete(reply);
        }

        commentRepository.delete(comment);
        
        // 更新帖子的评论数
        postService.decrementCommentsCount(comment.getPost().getId());
    }

    /**
     * 获取评论的子回复列表
     */
    public List<Comment> getReplies(Long parentId) {
        return commentRepository.findByParentIdOrderByCreatedAtAsc(parentId);
    }

    /**
     * 获取评论
     */
    public Optional<Comment> findById(Long commentId) {
        return commentRepository.findById(commentId);
    }
}

