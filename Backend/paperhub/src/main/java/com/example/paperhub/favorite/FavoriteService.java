package com.example.paperhub.favorite;

import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserStatus;
import com.example.paperhub.notification.NotificationService;
import com.example.paperhub.post.Post;
import com.example.paperhub.post.PostRepository;
import com.example.paperhub.post.dto.PostDtos;
import com.example.paperhub.websocket.WebSocketService;
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
    private final WebSocketService webSocketService;

    public FavoriteService(
            FavoritePostRepository favoriteRepository,
            PostRepository postRepository,
            NotificationService notificationService,
            WebSocketService webSocketService) {
        this.favoriteRepository = favoriteRepository;
        this.postRepository = postRepository;
        this.notificationService = notificationService;
        this.webSocketService = webSocketService;
    }

    @Transactional
    public void favoritePost(Long postId, User user) {
        ensureUserCanInteract(user);
        if (favoriteRepository.existsByUserIdAndPostId(user.getId(), postId)) {
            return;
        }
        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new IllegalArgumentException("帖子不存在"));
        FavoritePost favoritePost = new FavoritePost();
        favoritePost.setUser(user);
        favoritePost.setPost(post);
        favoriteRepository.save(favoritePost);

        // 更新收藏计数
        post.setFavoriteCount(post.getFavoriteCount() + 1);
        postRepository.save(post);

        // 发送 WebSocket 推送
        webSocketService.sendPostFavoriteUpdate(post.getId(), post.getFavoriteCount(), true);

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
        ensureUserCanInteract(user);
        if (favoriteRepository.existsByUserIdAndPostId(user.getId(), postId)) {
            favoriteRepository.deleteByUserIdAndPostId(user.getId(), postId);
            // 更新收藏计数
            Post post = postRepository.findById(postId)
                    .orElseThrow(() -> new IllegalArgumentException("帖子不存在"));
            post.setFavoriteCount(Math.max(0, post.getFavoriteCount() - 1));
            postRepository.save(post);

            // 发送 WebSocket 推送
            webSocketService.sendPostFavoriteUpdate(post.getId(), post.getFavoriteCount(), false);
        }
    }

    public boolean isFavorite(Long postId, Long userId) {
        if (userId == null) return false;
        return favoriteRepository.existsByUserIdAndPostId(userId, postId);
    }

    public long countFavorites(Long userId) {
        return favoriteRepository.countByUserId(userId);
    }

    public long countFavoritesByPostId(Long postId) {
        return favoriteRepository.countByPostId(postId);
    }

    public Page<Post> getFavoritePosts(Long userId, Pageable pageable) {
        Page<FavoritePost> favorites = favoriteRepository.findByUserIdOrderByCreatedAtDesc(userId, pageable);
        List<Post> posts = favorites.stream()
                .map(FavoritePost::getPost)
                .toList();
        return new PageImpl<>(posts, pageable, favorites.getTotalElements());
    }

    private void ensureUserCanInteract(User user) {
        if (user == null) {
            throw new IllegalArgumentException("未认证用户无法执行此操作");
        }
        if (user.getStatus() == UserStatus.BANNED) {
            throw new IllegalArgumentException("账号已被封禁，无法执行此操作");
        }
        if (user.getStatus() == UserStatus.SILENT) {
            java.time.Instant muteUntil = user.getMuteUntil();
            if (muteUntil == null || java.time.Instant.now().isBefore(muteUntil)) {
                throw new IllegalArgumentException("账号被禁言中，暂时无法收藏");
            }
        }
    }
}

