package com.example.paperhub.post;

import com.example.paperhub.auth.User;
import com.example.paperhub.favorite.FavoriteService;
import com.example.paperhub.like.LikeService;
import com.example.paperhub.post.dto.PostDtos;
import org.springframework.stereotype.Component;
import java.util.List;
/**
 * 统一的 Post -> PostResp 映射器，避免不同控制器重复构建响应。
 */
@Component
public class PostMapper {
    private final LikeService likeService;
    private final FavoriteService favoriteService;

    public PostMapper(LikeService likeService, FavoriteService favoriteService) {
        this.likeService = likeService;
        this.favoriteService = favoriteService;
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

        return new PostDtos.PostResp(
                post.getId().toString(),
                post.getTitle(),
                post.getContent() != null ? post.getContent() : "",
                post.getMedia() != null ? post.getMedia() : java.util.List.of(),
                post.getTags() != null ? post.getTags() : java.util.List.of(),
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

