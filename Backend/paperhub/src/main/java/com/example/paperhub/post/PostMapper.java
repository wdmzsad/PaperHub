package com.example.paperhub.post;

import com.example.paperhub.auth.User;
import com.example.paperhub.favorite.FavoriteService;
import com.example.paperhub.like.LikeService;
import com.example.paperhub.post.dto.PostDtos;
import org.springframework.stereotype.Component;
import java.util.List;
import java.util.Arrays;
/**
 * 统一的 Post -> PostResp 映射器，避免不同控制器重复构建响应。
 */
@Component
public class PostMapper {
    // 主分区列表（与前端保持一致）
    private static final List<String> MAIN_DISCIPLINES = Arrays.asList(
        "理学",
        "工学",
        "信息科学（CS）",
        "生命科学",
        "医学与健康",
        "经管",
        "社会科学",
        "人文与艺术",
        "教育学",
        "跨学科",
        "科研方法与工具",
        "学术生活",
        "公告区"
    );

    private final LikeService likeService;
    private final FavoriteService favoriteService;

    public PostMapper(LikeService likeService, FavoriteService favoriteService) {
        this.likeService = likeService;
        this.favoriteService = favoriteService;
    }

    /**
     * 从tags列表中提取主分区（用于兼容旧数据）
     */
    private String extractMainDisciplineFromTags(List<String> tags) {
        if (tags == null || tags.isEmpty()) {
            return "";
        }
        for (String tag : tags) {
            if (MAIN_DISCIPLINES.contains(tag)) {
                return tag;
            }
        }
        return "";
    }

    public PostDtos.PostResp toPostResp(Post post, Long viewerId) {
        User author = post.getAuthor();
        String authorName = author.getName() != null && !author.getName().isEmpty()
                ? author.getName()
                : (author.getEmail().contains("@")
                ? author.getEmail().substring(0, author.getEmail().indexOf("@"))
                : author.getEmail());

        PostDtos.AuthorInfo authorInfo = new PostDtos.AuthorInfo(
                author.getId(),
                author.getEmail(),
                authorName,
                resolveAvatar(author.getAvatar()),
                author.getAffiliation()
        );

        boolean isLiked = viewerId != null && likeService.isPostLiked(post.getId(), viewerId);
        boolean isSaved = viewerId != null && favoriteService.isFavorite(post.getId(), viewerId);

        double aspectRatio = 1.5;
        double naturalWidth = 800.0;
        double naturalHeight = 600.0;

        // 处理主分区：优先使用mainDiscipline字段，如果为空则从tags中提取（兼容旧数据）
        String mainDiscipline = post.getMainDiscipline();
        if (mainDiscipline == null || mainDiscipline.isEmpty()) {
            mainDiscipline = extractMainDisciplineFromTags(post.getTags());
        }

        // 处理二级标签：过滤掉主分区标签
        List<String> subTags = new java.util.ArrayList<>();
        if (post.getTags() != null) {
            for (String tag : post.getTags()) {
                if (!MAIN_DISCIPLINES.contains(tag)) {
                    subTags.add(tag);
                }
            }
        }

        return new PostDtos.PostResp(
                post.getId().toString(),
                post.getTitle(),
                post.getContent() != null ? post.getContent() : "",
                post.getMedia() != null ? post.getMedia() : java.util.List.of(),
                mainDiscipline, // 主分区
                subTags, // 二级标签（已过滤主分区）
                post.getExternalLinks() != null ? post.getExternalLinks() : List.of(),
                authorInfo,
                post.getLikesCount(),
                post.getCommentsCount(),
                post.getViewsCount(),
                isLiked,
                isSaved,
                post.getDoi(),
                post.getJournal(),
                post.getYear(),
                post.getArxivId(),
                post.getArxivAuthors() != null ? post.getArxivAuthors() : List.of(),
                post.getArxivPublishedDate(),
                post.getArxivCategories() != null ? post.getArxivCategories() : List.of(),
                post.getReferences() != null ? post.getReferences() : List.of(), // 引用文献
                post.getCreatedAt() != null ? post.getCreatedAt().toString() : null,
                aspectRatio,
                naturalWidth,
                naturalHeight
        );
    }

    private String resolveAvatar(String avatar) {
        if (avatar == null || avatar.trim().isEmpty()) {
            return "images/DefaultAvatar.png";
        }
        if (avatar.equals("assets/images/DefaultAvatar.png")) {
            return "images/DefaultAvatar.png";
        }
        return avatar;
    }
}

