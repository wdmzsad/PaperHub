package com.example.paperhub.comment.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public class CommentDtos {
    // 创建评论请求
    public record CreateCommentReq(
        @NotBlank String content,
        Long parentId,  // 可选，用于回复
        Long replyToId,  // 可选，被回复的用户ID
        java.util.List<Long> mentionIds  // 可选，被@的用户ID列表
    ) {}

    // 更新评论请求
    public record UpdateCommentReq(
        @NotBlank String content
    ) {}

    // 点赞响应
    public record LikeResp(int likesCount, boolean isLiked) {}

    // 评论响应（包含作者信息）
    public record AuthorInfo(Long id, String email, String name, String avatar, String affiliation) {}
    
    public record CommentResp(
        String id,
        AuthorInfo author,
        String content,
        String parentId,
        AuthorInfo replyTo,
        int likesCount,
        boolean isLiked,
        String createdAt,
        java.util.List<CommentResp> replies,
        java.util.List<AuthorInfo> mentions  // 被@的用户列表
    ) {}
    
    // 评论列表响应
    public record CommentListResp(
        java.util.List<CommentResp> comments,
        long total,
        int page,
        int pageSize
    ) {}
}

