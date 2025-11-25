package com.example.paperhub.notification.dto;

import com.example.paperhub.notification.Notification;
import com.example.paperhub.notification.NotificationType;
import java.time.Instant;

public class NotificationDtos {
    // 未读数量响应
    public static class UnreadCountResp {
        public final long likes;
        public final long follows;
        public final long comments;

        public UnreadCountResp(long likes, long follows, long comments) {
            this.likes = likes;
            this.follows = follows;
            this.comments = comments;
        }
    }

    // 通知响应
    public static class NotificationResp {
        public final Long id;
        public final ActorInfo actor;
        public final NotificationType type;
        public final String content;
        public final PostInfo post;
        public final CommentInfo comment;
        public final boolean read;
        public final String createdAt;

        public NotificationResp(
                Long id,
                ActorInfo actor,
                NotificationType type,
                String content,
                PostInfo post,
                CommentInfo comment,
                boolean read,
                String createdAt
        ) {
            this.id = id;
            this.actor = actor;
            this.type = type;
            this.content = content;
            this.post = post;
            this.comment = comment;
            this.read = read;
            this.createdAt = createdAt;
        }

        public static NotificationResp from(Notification notification) {
            String content = generateContent(notification);
            return new NotificationResp(
                    notification.getId(),
                    new ActorInfo(
                            notification.getActor().getId(),
                            notification.getActor().getName() != null ? notification.getActor().getName() : notification.getActor().getEmail(),
                            notification.getActor().getAvatar()
                    ),
                    notification.getType(),
                    content,
                    notification.getPost() != null ? new PostInfo(
                            notification.getPost().getId(),
                            notification.getPost().getTitle()
                    ) : null,
                    notification.getComment() != null ? new CommentInfo(
                            notification.getComment().getId(),
                            notification.getComment().getContent()
                    ) : null,
                    notification.isRead(),
                    notification.getCreatedAt().toString()
            );
        }

        private static String generateContent(Notification notification) {
            String actorName = notification.getActor().getName() != null 
                    ? notification.getActor().getName() 
                    : notification.getActor().getEmail();
            
            switch (notification.getType()) {
                case POST_LIKE:
                    return actorName + "赞了你的笔记《" + 
                           (notification.getPost() != null ? notification.getPost().getTitle() : "") + "》";
                case POST_FAVORITE:
                    return actorName + "收藏了你的笔记《" + 
                           (notification.getPost() != null ? notification.getPost().getTitle() : "") + "》";
                case COMMENT_LIKE:
                    return actorName + "赞了你的评论";
                case COMMENT:
                    return actorName + "评论了你的笔记《" + 
                           (notification.getPost() != null ? notification.getPost().getTitle() : "") + "》";
                case MENTION:
                    return actorName + "在《" + 
                           (notification.getPost() != null ? notification.getPost().getTitle() : "") + 
                           "》中@了你";
                case FOLLOW:
                    return actorName + "关注了你";
                default:
                    return "";
            }
        }
    }

    // 用户信息
    public static class ActorInfo {
        public final Long id;
        public final String name;
        public final String avatar;

        public ActorInfo(Long id, String name, String avatar) {
            this.id = id;
            this.name = name;
            this.avatar = avatar;
        }
    }

    // 帖子信息
    public static class PostInfo {
        public final Long id;
        public final String title;

        public PostInfo(Long id, String title) {
            this.id = id;
            this.title = title;
        }
    }

    // 评论信息
    public static class CommentInfo {
        public final Long id;
        public final String content;

        public CommentInfo(Long id, String content) {
            this.id = id;
            this.content = content;
        }
    }

    // 通知列表响应
    public static class NotificationListResp {
        public final java.util.List<NotificationResp> notifications;
        public final long total;
        public final int page;
        public final int pageSize;

        public NotificationListResp(
                java.util.List<NotificationResp> notifications,
                long total,
                int page,
                int pageSize
        ) {
            this.notifications = notifications;
            this.total = total;
            this.page = page;
            this.pageSize = pageSize;
        }
    }
}

