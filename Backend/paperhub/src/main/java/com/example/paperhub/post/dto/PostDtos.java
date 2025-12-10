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
        @NotBlank String mainDiscipline, // 主分区（一级标签）
        String doi,
        String journal,
        Integer year,
        List<String> externalLinks, // 新增：外部链接列表
        String arxivId, // arXiv ID
        List<String> arxivAuthors, // arXiv 作者列表
        String arxivPublishedDate, // arXiv 发布日期
        List<String> arxivCategories, // arXiv 分类列表
        List<Long> references, // 引用文献：被引用帖子的ID列表
        String status // 帖子状态：DRAFT（草稿）或 NORMAL（正常发布），默认为 NORMAL
    ) {}
    
    // 作者信息
    public record AuthorInfo(Long id, String email, String name, String avatar, String affiliation) {}
    
    // 帖子响应
    public record PostResp(
        String id,
        String title,
        String content,
        List<String> media,
        String mainDiscipline, // 主分区（一级标签）
        List<String> subTags, // 二级标签列表
        List<String> externalLinks, // 新增：外部链接列表
        AuthorInfo author,
        int likesCount,
        int commentsCount,
        int viewsCount,
        boolean isLiked,
        boolean isSaved,
        String status,
        String hiddenReason,
        Long updatedByAdmin,
        Boolean visibleToAuthor,
        String doi,
        String journal,
        Integer year,
        String arxivId, // arXiv ID
        List<String> arxivAuthors, // arXiv 作者列表
        String arxivPublishedDate, // arXiv 发布日期
        List<String> arxivCategories, // arXiv 分类列表
        List<Long> references, // 引用文献：被引用帖子的ID列表
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

