package com.example.paperhub.post.dto;

import jakarta.validation.constraints.NotBlank;
import java.util.List;

public class PostDtos {
    public record LikeResp(int likesCount, boolean isLiked) {}
    
    // 创建帖子请求
    public record CreatePostReq(
        @NotBlank String title,
        String content,
        List<String> media,
        List<String> tags,
        String doi,
        String journal,
        Integer year
    ) {}
    
    // 作者信息
    public record AuthorInfo(Long id, String email, String name, String avatar, String affiliation) {}
    
    // 帖子响应
    public record PostResp(
        String id,
        String title,
        String content,
        List<String> media,
        List<String> tags,
        AuthorInfo author,
        int likesCount,
        int commentsCount,
        int viewsCount,
        boolean isLiked,
        boolean isSaved,
        String doi,
        String journal,
        Integer year,
        String createdAt,
        double imageAspectRatio,
        double imageNaturalWidth,
        double imageNaturalHeight
    ) {}
    
    // 帖子列表响应
    public record PostListResp(
        List<PostResp> posts,
        long total,
        int page,
        int pageSize
    ) {}
}

