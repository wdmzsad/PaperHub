package com.example.paperhub.notification;

/**
 * 通知类型枚举
 */
public enum NotificationType {
    POST_LIKE,      // 点赞帖子
    POST_FAVORITE,  // 收藏帖子
    COMMENT_LIKE,   // 点赞评论
    COMMENT,        // 评论帖子
    MENTION,        // @提到
    FOLLOW          // 关注
}

