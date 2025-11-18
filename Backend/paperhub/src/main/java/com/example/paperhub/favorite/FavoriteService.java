package com.example.paperhub.favorite;

import com.example.paperhub.auth.User;
import com.example.paperhub.notification.NotificationService;
import com.example.paperhub.post.Post;
import com.example.paperhub.post.PostRepository;
import com.example.paperhub.post.dto.PostDtos;
import java.util.List;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 收藏帖子相关业务。
 */
@Service
public class FavoriteService {

    private final FavoritePostRepository favoriteRepository;
    private final PostRepository postRepository;
    private final NotificationService notificationService;

    public FavoriteService(
            FavoritePostRepository favoriteRepository, 
            PostRepository postRepository,
            NotificationService notificationService) {
        this.favoriteRepository = favoriteRepository;
        this.postRepository = postRepository;
        this.notificationService = notificationService;
    }

    @Transactional
    public void favoritePost(Long postId, User user) {
        if (favoriteRepository.existsByUserIdAndPostId(user.getId(), postId)) {
            return;
        }
        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new IllegalArgumentException("帖子不存在"));
        FavoritePost favoritePost = new FavoritePost();
        favoritePost.setUser(user);
        favoritePost.setPost(post);
        favoriteRepository.save(favoritePost);
        
        // 创建通知
        try {
            notificationService.createPostFavoriteNotification(user, postId);
        } catch (Exception e) {
            // 通知创建失败不影响收藏操作
            System.err.println("创建收藏通知失败: " + e.getMessage());
        }
    }

    @Transactional
    public void unfavoritePost(Long postId, User user) {
        favoriteRepository.deleteByUserIdAndPostId(user.getId(), postId);
    }

    public boolean isFavorite(Long postId, Long userId) {
        if (userId == null) return false;
        return favoriteRepository.existsByUserIdAndPostId(userId, postId);
    }

    public long countFavorites(Long userId) {
        return favoriteRepository.countByUserId(userId);
    }

    public Page<Post> getFavoritePosts(Long userId, Pageable pageable) {
        Page<FavoritePost> favorites = favoriteRepository.findByUserIdOrderByCreatedAtDesc(userId, pageable);
        List<Post> posts = favorites.stream()
                .map(FavoritePost::getPost)
                .toList();
        return new PageImpl<>(posts, pageable, favorites.getTotalElements());
    }
}

