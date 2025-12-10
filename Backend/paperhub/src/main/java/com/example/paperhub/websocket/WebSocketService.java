package com.example.paperhub.websocket;

import com.example.paperhub.comment.dto.CommentDtos;
import org.springframework.stereotype.Service;

/**
 * WebSocket服务类
 * 用于向客户端推送实时消息
 */
@Service
public class WebSocketService {
    private final SimpleWebSocketHandler webSocketHandler;

    public WebSocketService(SimpleWebSocketHandler webSocketHandler) {
        this.webSocketHandler = webSocketHandler;
    }

    /**
     * 推送帖子点赞更新
     */
    public void sendPostLikeUpdate(Long postId, int likesCount, boolean isLiked) {
        LikeUpdateMessage message = new LikeUpdateMessage("like_update", likesCount, isLiked, null, null);
        webSocketHandler.sendToPost(postId, message);
    }

    /**
     * 推送评论点赞更新
     */
    public void sendCommentLikeUpdate(Long postId, String commentId, int likesCount, boolean isLiked) {
        CommentLikeUpdateMessage message = new CommentLikeUpdateMessage("comment_like_update", commentId, likesCount, isLiked);
        webSocketHandler.sendToPost(postId, message);
    }

    /**
     * 推送新评论
     */
    public void sendCommentCreated(Long postId, CommentDtos.CommentResp comment) {
        CommentCreatedMessage message = new CommentCreatedMessage("comment_created", comment);
        webSocketHandler.sendToPost(postId, message);
    }

    /**
     * 推送评论更新
     */
    public void sendCommentUpdated(Long postId, CommentDtos.CommentResp comment) {
        CommentUpdatedMessage message = new CommentUpdatedMessage("comment_updated", comment);
        webSocketHandler.sendToPost(postId, message);
    }

    /**
     * 推送评论删除
     */
    public void sendCommentDeleted(Long postId, String commentId) {
        CommentDeletedMessage message = new CommentDeletedMessage("comment_deleted", commentId);
        webSocketHandler.sendToPost(postId, message);
    }

    // 消息类定义
    public static class LikeUpdateMessage {
        public String type;
        public int likesCount;
        public boolean isLiked;
        public String commentId;
        public Integer commentLikesCount;

        public LikeUpdateMessage(String type, int likesCount, boolean isLiked, String commentId, Integer commentLikesCount) {
            this.type = type;
            this.likesCount = likesCount;
            this.isLiked = isLiked;
            this.commentId = commentId;
            this.commentLikesCount = commentLikesCount;
        }
    }

    public static class CommentLikeUpdateMessage {
        public String type;
        public String commentId;
        public int likesCount;
        public boolean isLiked;

        public CommentLikeUpdateMessage(String type, String commentId, int likesCount, boolean isLiked) {
            this.type = type;
            this.commentId = commentId;
            this.likesCount = likesCount;
            this.isLiked = isLiked;
        }
    }

    public static class CommentCreatedMessage {
        public String type;
        public CommentDtos.CommentResp comment;

        public CommentCreatedMessage(String type, CommentDtos.CommentResp comment) {
            this.type = type;
            this.comment = comment;
        }
    }

    public static class CommentUpdatedMessage {
        public String type;
        public CommentDtos.CommentResp comment;

        public CommentUpdatedMessage(String type, CommentDtos.CommentResp comment) {
            this.type = type;
            this.comment = comment;
        }
    }

    public static class CommentDeletedMessage {
        public String type;
        public String commentId;

        public CommentDeletedMessage(String type, String commentId) {
            this.type = type;
            this.commentId = commentId;
        }
    }

    /**
     * 推送帖子状态更新（给管理员）
     */
    public void sendPostStatusUpdate(Long postId, String status, String title) {
        PostStatusUpdateMessage message = new PostStatusUpdateMessage("post_status_update", postId, status, title);
        webSocketHandler.sendToAdmins(message);
    }

    public static class PostStatusUpdateMessage {
        public String type;
        public Long postId;
        public String status;
        public String title;

        public PostStatusUpdateMessage(String type, Long postId, String status, String title) {
            this.type = type;
            this.postId = postId;
            this.status = status;
            this.title = title;
        }
    }
}

