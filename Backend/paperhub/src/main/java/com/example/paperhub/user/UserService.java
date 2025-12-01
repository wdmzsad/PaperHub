package com.example.paperhub.user;

import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserRepository;
import com.example.paperhub.favorite.FavoritePostRepository;
import com.example.paperhub.follow.UserFollowRepository;
import com.example.paperhub.like.PostLikeRepository;
import com.example.paperhub.post.PostRepository;
import com.example.paperhub.user.dto.UserDtos;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

/**
 * 用户资料领域服务，负责封装 User 实体的转换与更新逻辑。
 */
@Service
public class UserService {
    private final UserRepository userRepository;
    private final UserFollowRepository followRepository;
    private final FavoritePostRepository favoriteRepository;
    private final PostLikeRepository postLikeRepository;
    private final PostRepository postRepository;

    public UserService(
            UserRepository userRepository,
            UserFollowRepository followRepository,
            FavoritePostRepository favoriteRepository,
            PostLikeRepository postLikeRepository,
            PostRepository postRepository) {
        this.userRepository = userRepository;
        this.followRepository = followRepository;
        this.favoriteRepository = favoriteRepository;
        this.postLikeRepository = postLikeRepository;
        this.postRepository = postRepository;
    }

    /**
     * 将 User 实体转换为前端需要的 ProfileResp。
     */
    public UserDtos.ProfileResp toProfile(User user) {
        return toProfile(user, null);
    }

    public UserDtos.ProfileResp toProfile(User user, User viewer) {
        long followingCount = followRepository.countByFollowerId(user.getId());
        long followersCount = followRepository.countByFollowingId(user.getId());
        long favoritesCount = favoriteRepository.countByUserId(user.getId());
        long favoritesReceived = favoriteRepository.countByPostAuthorId(user.getId());
        long postsCount = postRepository.countByAuthorId(user.getId());
        long likesReceived = postLikeRepository.countByAuthorId(user.getId());

        boolean isFollowing = false;
        boolean isFollowerToViewer = false;
        if (viewer != null && !viewer.getId().equals(user.getId())) {
            isFollowing = followRepository.existsByFollowerIdAndFollowingId(viewer.getId(), user.getId());
            isFollowerToViewer = followRepository.existsByFollowerIdAndFollowingId(user.getId(), viewer.getId());
        }

        return new UserDtos.ProfileResp(
                user.getId(),
                user.getEmail(),
                safeName(user),
                resolveAvatar(user.getAvatar()),
                resolveBackground(user.getProfileBackground()),
                user.getBio(),
                splitDirections(user.getResearchDirections()),
                (int) followingCount,
                (int) followersCount,
                (int) postsCount,
                (int) favoritesCount,
                (int) favoritesReceived,
                (int) likesReceived,
                isFollowing,
                isFollowerToViewer,
                user.isHideFollowing(),
                user.isHideFollowers(),
                user.isPublicFavorites()
        );
    }

    /**
     * 更新当前登录用户的基础资料。
     */
    public User updateProfile(User user, UserDtos.UpdateProfileReq req) {
        user.setName(req.name());
        if (req.bio() != null) {
            user.setBio(req.bio());
        }
        if (req.researchDirections() != null) {
            user.setResearchDirections(joinDirections(req.researchDirections()));
        }
        if (req.backgroundImage() != null) {
            user.setProfileBackground(req.backgroundImage());
        }
        return userRepository.save(user);
    }

    private String safeName(User user) {
        if (StringUtils.hasText(user.getName())) {
            return user.getName();
        }
        String email = user.getEmail();
        if (email != null && email.contains("@")) {
            return email.substring(0, email.indexOf("@"));
        }
        return email;
    }

    private List<String> splitDirections(String raw) {
        if (!StringUtils.hasText(raw)) {
            return Collections.emptyList();
        }
        return Arrays.stream(raw.split(","))
                .map(String::trim)
                .filter(s -> !s.isEmpty())
                .collect(Collectors.toList());
    }

    private String joinDirections(List<String> directions) {
        if (directions == null || directions.isEmpty()) {
            return null;
        }
        return directions.stream()
                .map(String::trim)
                .filter(s -> !s.isEmpty())
                .collect(Collectors.joining(","));
    }

    private String resolveAvatar(String avatar) {
        if (!StringUtils.hasText(avatar)) {
            return "images/DefaultAvatar.png";
        }
        // 后端持久化的是完整 URL，这里直接返回
        return avatar;
    }

    private String resolveBackground(String background) {
        if (!StringUtils.hasText(background)) {
            return "images/profile_bg.jpg";
        }
        return background;
    }
}

