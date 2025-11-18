package com.example.paperhub.notification;

import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserRepository;
import com.example.paperhub.comment.Comment;
import com.example.paperhub.comment.CommentRepository;
import com.example.paperhub.post.Post;
import com.example.paperhub.post.PostRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
public class NotificationService {
    private final NotificationRepository notificationRepository;
    private final UserRepository userRepository;
    private final PostRepository postRepository;
    private final CommentRepository commentRepository;

    public NotificationService(
            NotificationRepository notificationRepository,
            UserRepository userRepository,
            PostRepository postRepository,
            CommentRepository commentRepository) {
        this.notificationRepository = notificationRepository;
        this.userRepository = userRepository;
        this.postRepository = postRepository;
        this.commentRepository = commentRepository;
    }

    /**
     * 创建通知
     */
    @Transactional
    public void createNotification(User actor, User recipient, NotificationType type, Post post, Comment comment) {
        // 不给自己发通知
        if (actor.getId().equals(recipient.getId())) {
            return;
        }

        Notification notification = new Notification();
        notification.setActor(actor);
        notification.setRecipient(recipient);
        notification.setType(type);
        notification.setPost(post);
        notification.setComment(comment);
        notification.setRead(false);

        notificationRepository.save(notification);
    }

    /**
     * 创建点赞帖子通知
     */
    @Transactional
    public void createPostLikeNotification(User actor, Long postId) {
        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new IllegalArgumentException("帖子不存在"));
        
        createNotification(actor, post.getAuthor(), NotificationType.POST_LIKE, post, null);
    }

    /**
     * 创建收藏帖子通知
     */
    @Transactional
    public void createPostFavoriteNotification(User actor, Long postId) {
        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new IllegalArgumentException("帖子不存在"));
        
        createNotification(actor, post.getAuthor(), NotificationType.POST_FAVORITE, post, null);
    }

    /**
     * 创建点赞评论通知
     */
    @Transactional
    public void createCommentLikeNotification(User actor, Long commentId) {
        Comment comment = commentRepository.findById(commentId)
                .orElseThrow(() -> new IllegalArgumentException("评论不存在"));
        
        createNotification(actor, comment.getAuthor(), NotificationType.COMMENT_LIKE, comment.getPost(), comment);
    }

    /**
     * 创建评论通知
     */
    @Transactional
    public void createCommentNotification(User actor, Long postId, Long commentId, User replyTo) {
        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new IllegalArgumentException("帖子不存在"));
        Comment comment = commentId != null ? commentRepository.findById(commentId)
                .orElse(null) : null;

        // 通知帖子作者
        if (!actor.getId().equals(post.getAuthor().getId())) {
            createNotification(actor, post.getAuthor(), NotificationType.COMMENT, post, comment);
        }

        // 如果回复了某个用户，也通知该用户
        if (replyTo != null && !actor.getId().equals(replyTo.getId()) && 
            !replyTo.getId().equals(post.getAuthor().getId())) {
            createNotification(actor, replyTo, NotificationType.MENTION, post, comment);
        }
    }

    /**
     * 创建关注通知
     */
    @Transactional
    public void createFollowNotification(User actor, Long targetUserId) {
        User target = userRepository.findById(targetUserId)
                .orElseThrow(() -> new IllegalArgumentException("用户不存在"));
        
        createNotification(actor, target, NotificationType.FOLLOW, null, null);
    }

    /**
     * 获取未读通知数量（按类型分组）
     */
    public Map<String, Long> getUnreadCounts(User recipient) {
        Map<String, Long> counts = new HashMap<>();
        
        // 赞和收藏（POST_LIKE + POST_FAVORITE + COMMENT_LIKE）
        long likesCount = notificationRepository.countByRecipientAndTypeAndReadFalse(recipient, NotificationType.POST_LIKE)
                + notificationRepository.countByRecipientAndTypeAndReadFalse(recipient, NotificationType.POST_FAVORITE)
                + notificationRepository.countByRecipientAndTypeAndReadFalse(recipient, NotificationType.COMMENT_LIKE);
        counts.put("likes", likesCount);

        // 关注
        long followsCount = notificationRepository.countByRecipientAndTypeAndReadFalse(recipient, NotificationType.FOLLOW);
        counts.put("follows", followsCount);

        // 评论和@（COMMENT + MENTION）
        long commentsCount = notificationRepository.countByRecipientAndTypeAndReadFalse(recipient, NotificationType.COMMENT)
                + notificationRepository.countByRecipientAndTypeAndReadFalse(recipient, NotificationType.MENTION);
        counts.put("comments", commentsCount);

        return counts;
    }

    /**
     * 获取赞和收藏通知
     */
    public Page<Notification> getLikesAndFavorites(User recipient, Pageable pageable) {
        return notificationRepository.findByRecipientAndTypeInOrderByCreatedAtDesc(
                recipient, 
                List.of(NotificationType.POST_LIKE, NotificationType.POST_FAVORITE, NotificationType.COMMENT_LIKE),
                pageable
        );
    }

    /**
     * 获取关注通知
     */
    public Page<Notification> getFollows(User recipient, Pageable pageable) {
        return notificationRepository.findByRecipientAndTypeOrderByCreatedAtDesc(recipient, NotificationType.FOLLOW, pageable);
    }

    /**
     * 获取评论和@通知
     */
    public Page<Notification> getCommentsAndMentions(User recipient, Pageable pageable) {
        return notificationRepository.findByRecipientAndTypeInOrderByCreatedAtDesc(
                recipient,
                List.of(NotificationType.COMMENT, NotificationType.MENTION),
                pageable
        );
    }

    /**
     * 标记通知为已读
     */
    @Transactional
    public void markAsRead(Long notificationId, User recipient) {
        Notification notification = notificationRepository.findById(notificationId)
                .orElseThrow(() -> new IllegalArgumentException("通知不存在"));
        
        if (!notification.getRecipient().getId().equals(recipient.getId())) {
            throw new IllegalArgumentException("无权操作此通知");
        }

        notification.setRead(true);
        notificationRepository.save(notification);
    }

    /**
     * 标记所有通知为已读
     */
    @Transactional
    public void markAllAsRead(User recipient, NotificationType type) {
        List<Notification> notifications;
        if (type != null) {
            // 标记特定类型的所有通知为已读
            notifications = notificationRepository.findByRecipientAndTypeAndReadFalse(recipient, type);
        } else {
            // 标记所有通知为已读
            notifications = notificationRepository.findByRecipientAndReadFalse(recipient);
        }
        notifications.forEach(n -> n.setRead(true));
        notificationRepository.saveAll(notifications);
    }

    /**
     * 批量标记指定类型列表的所有未读通知为已读
     */
    @Transactional
    public void markAllAsReadByTypes(User recipient, List<NotificationType> types) {
        List<Notification> notifications = new ArrayList<>();
        for (NotificationType type : types) {
            notifications.addAll(notificationRepository.findByRecipientAndTypeAndReadFalse(recipient, type));
        }
        notifications.forEach(n -> n.setRead(true));
        notificationRepository.saveAll(notifications);
    }
}

