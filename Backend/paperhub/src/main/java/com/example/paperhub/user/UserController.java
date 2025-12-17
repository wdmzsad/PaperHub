package com.example.paperhub.user;

import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserRepository;
import com.example.paperhub.config.ObsConfig;
import com.example.paperhub.favorite.FavoriteService;
import com.example.paperhub.follow.FollowService;
import com.example.paperhub.follow.UserFollow;
import com.example.paperhub.post.Post;
import com.example.paperhub.post.PostMapper;
import com.example.paperhub.post.PostService;
import com.example.paperhub.post.dto.PostDtos;
import com.example.paperhub.user.dto.UserDtos;
import com.obs.services.ObsClient;
import com.obs.services.exception.ObsException;
import jakarta.validation.Valid;
import java.io.IOException;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

/**
 * 用户个人资料相关 API。
 * 提供获取当前登录用户资料、查看其它用户主页、更新资料及头像上传的能力。
 */
@RestController
@RequestMapping("/users")
@CrossOrigin(origins = "*")
public class UserController {

    private final UserService userService;
    private final UserRepository userRepository;
    private final ObsClient obsClient;
    private final ObsConfig obsConfig;
    private final FollowService followService;
    private final FavoriteService favoriteService;
    private final PostService postService;
    private final PostMapper postMapper;

    public UserController(UserService userService,
                          UserRepository userRepository,
                          ObsClient obsClient,
                          ObsConfig obsConfig,
                          FollowService followService,
                          FavoriteService favoriteService,
                          PostService postService,
                          PostMapper postMapper) {
        this.userService = userService;
        this.userRepository = userRepository;
        this.obsClient = obsClient;
        this.obsConfig = obsConfig;
        this.followService = followService;
        this.favoriteService = favoriteService;
        this.postService = postService;
        this.postMapper = postMapper;
    }

    /**
     * 获取当前登录用户的个人资料。
     */
    @GetMapping("/me")
    public ResponseEntity<?> getCurrentUser(@AuthenticationPrincipal User currentUser) {
        if (currentUser == null) {
            return ResponseEntity.ok(null);  // 页面刷新时容忍匿名状态，返回空结果
        }
        return ResponseEntity.ok(userService.toProfile(currentUser));
    }

    /**
     * 获取当前登录用户的隐私设置。
     */
    @GetMapping("/me/privacy")
    public ResponseEntity<?> getMyPrivacySettings(@AuthenticationPrincipal User currentUser) {
        if (currentUser == null) {
            // 页面刷新时容忍匿名状态，返回默认隐私设置
            return ResponseEntity.ok(new UserDtos.PrivacySettingsResp(false, false, true));
        }
        User fresh = userRepository.findById(currentUser.getId())
                .orElseThrow(() -> new IllegalStateException("当前用户不存在"));
        return ResponseEntity.ok(new UserDtos.PrivacySettingsResp(
                fresh.isHideFollowing(),
                fresh.isHideFollowers(),
                fresh.isPublicFavorites()
        ));
    }

    /**
     * 获取指定用户的公开资料。
     */
    @GetMapping("/{userId}")
    public ResponseEntity<?> getUserProfile(
            @PathVariable Long userId,
            @AuthenticationPrincipal User currentUser) {
        return userRepository.findById(userId)
                .<ResponseEntity<?>>map(user -> ResponseEntity.ok(userService.toProfile(user, currentUser)))
                .orElseGet(() -> ResponseEntity.status(404).body(Map.of("message", "用户不存在")));
    }

    /**
     * 更新当前登录用户的基础资料。
     */
    @PutMapping("/me")
    public ResponseEntity<?> updateProfile(@AuthenticationPrincipal User currentUser,
                                           @Valid @RequestBody UserDtos.UpdateProfileReq req) {
        if (currentUser == null) {
            return ResponseEntity.status(401).body(Map.of("message", "未认证，请先登录"));
        }
        User updated = userService.updateProfile(currentUser, req);
        return ResponseEntity.ok(userService.toProfile(updated));
    }

    /**
     * 更新当前登录用户的隐私设置。
     */
    @PutMapping("/me/privacy")
    public ResponseEntity<?> updatePrivacy(@AuthenticationPrincipal User currentUser,
                                           @RequestBody UserDtos.UpdatePrivacySettingsReq req) {
        if (currentUser == null) {
            return ResponseEntity.status(401).body(Map.of("message", "未认证，请先登录"));
        }
        User user = userRepository.findById(currentUser.getId())
                .orElseThrow(() -> new IllegalStateException("当前用户不存在"));

        if (req.hideFollowing() != null) {
            user.setHideFollowing(Boolean.TRUE.equals(req.hideFollowing()));
        }
        if (req.hideFollowers() != null) {
            user.setHideFollowers(Boolean.TRUE.equals(req.hideFollowers()));
        }
        if (req.publicFavorites() != null) {
            user.setPublicFavorites(Boolean.TRUE.equals(req.publicFavorites()));
        }

        userRepository.save(user);

        return ResponseEntity.ok(new UserDtos.PrivacySettingsResp(
                user.isHideFollowing(),
                user.isHideFollowers(),
                user.isPublicFavorites()
        ));
    }

    /**
     * 上传头像文件并返回可访问的 URL，同时更新用户资料中的 avatar 字段。
     */
    @PostMapping("/me/avatar")
    public ResponseEntity<?> uploadAvatar(@AuthenticationPrincipal User currentUser,
                                          @RequestParam("file") MultipartFile file) {
        if (currentUser == null) {
            return ResponseEntity.status(401).body(Map.of("message", "未认证，请先登录"));
        }
        if (file == null || file.isEmpty()) {
            return ResponseEntity.badRequest().body(Map.of("message", "文件不能为空"));
        }

        String originalName = file.getOriginalFilename();
        String extension = StringUtils.hasText(originalName) && originalName.contains(".")
                ? originalName.substring(originalName.lastIndexOf('.'))
                : "";
        String objectKey = "avatars/" + UUID.randomUUID() + extension;
        String url = "https://" + obsConfig.getBucketName() + ".obs.cn-north-4.myhuaweicloud.com/" + objectKey;

        try {
            obsClient.putObject(obsConfig.getBucketName(), objectKey, file.getInputStream());
            currentUser.setAvatar(url);
            userRepository.save(currentUser);
            return ResponseEntity.ok(new UserDtos.AvatarUploadResp(url, "头像上传成功"));
        } catch (ObsException e) {
            return ResponseEntity.status(500).body(Map.of(
                    "message", "头像上传失败: " + e.getErrorMessage(),
                    "code", e.getErrorCode()
            ));
        } catch (IOException e) {
            return ResponseEntity.status(500).body(Map.of(
                    "message", "头像上传失败: " + e.getMessage()
            ));
        }
    }

    /**
     * 上传个人主页背景图。
     */
    @PostMapping("/me/background")
    public ResponseEntity<?> uploadBackground(@AuthenticationPrincipal User currentUser,
                                              @RequestParam("file") MultipartFile file) {
        if (currentUser == null) {
            return ResponseEntity.status(401).body(Map.of("message", "未认证，请先登录"));
        }
        if (file == null || file.isEmpty()) {
            return ResponseEntity.badRequest().body(Map.of("message", "文件不能为空"));
        }
        String originalName = file.getOriginalFilename();
        String extension = StringUtils.hasText(originalName) && originalName.contains(".")
                ? originalName.substring(originalName.lastIndexOf('.'))
                : "";
        String objectKey = "profile-bg/" + UUID.randomUUID() + extension;
        String url = "https://" + obsConfig.getBucketName() + ".obs.cn-north-4.myhuaweicloud.com/" + objectKey;
        try {
            obsClient.putObject(obsConfig.getBucketName(), objectKey, file.getInputStream());
            currentUser.setProfileBackground(url);
            userRepository.save(currentUser);
            return ResponseEntity.ok(new UserDtos.BackgroundUploadResp(url, "背景图上传成功"));
        } catch (ObsException e) {
            return ResponseEntity.status(500).body(Map.of(
                    "message", "背景图上传失败: " + e.getErrorMessage(),
                    "code", e.getErrorCode()
            ));
        } catch (IOException e) {
            return ResponseEntity.status(500).body(Map.of(
                    "message", "背景图上传失败: " + e.getMessage()
            ));
        }
    }

    /**
     * 关注指定用户。
     */
    @PostMapping("/{userId}/follow")
    public ResponseEntity<?> followUser(@AuthenticationPrincipal User currentUser,
                                        @PathVariable Long userId) {
        if (currentUser == null) {
            return ResponseEntity.status(401).body(Map.of("message", "未认证，请先登录"));
        }
        followService.follow(currentUser, userId);
        return ResponseEntity.ok(Map.of("isFollowing", true));
    }

    /**
     * 取消关注指定用户。
     */
    @DeleteMapping("/{userId}/follow")
    public ResponseEntity<?> unfollowUser(@AuthenticationPrincipal User currentUser,
                                          @PathVariable Long userId) {
        if (currentUser == null) {
            return ResponseEntity.status(401).body(Map.of("message", "未认证，请先登录"));
        }
        followService.unfollow(currentUser, userId);
        return ResponseEntity.ok(Map.of("isFollowing", false));
    }

    /**
     * 获取关注列表。
     */
    @GetMapping("/{userId}/following")
    public ResponseEntity<?> getFollowing(
            @PathVariable Long userId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int pageSize,
            @AuthenticationPrincipal User currentUser) {
        var targetUserOpt = userRepository.findById(userId);
        if (targetUserOpt.isEmpty()) {
            return ResponseEntity.status(404).body(Map.of("message", "用户不存在"));
        }
        User targetUser = targetUserOpt.get();
        // 隐私控制：非本人且对方隐藏关注列表时禁止访问
        if ((currentUser == null || !currentUser.getId().equals(userId))
                && targetUser.isHideFollowing()) {
            return ResponseEntity.status(403).body(Map.of("message", "对方已隐藏关注列表"));
        }

        Page<UserFollow> followingPage = followService.getFollowing(userId, PageRequest.of(page, pageSize));
        var users = followingPage.getContent().stream()
                .map(UserFollow::getFollowing)
                .map(u -> userService.toProfile(u, currentUser))
                .toList();
        return ResponseEntity.ok(new UserDtos.UserListResp(
                users,
                followingPage.getTotalElements(),
                page,
                pageSize
        ));
    }

    /**
     * 获取粉丝列表。
     */
    @GetMapping("/{userId}/followers")
    public ResponseEntity<?> getFollowers(
            @PathVariable Long userId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int pageSize,
            @AuthenticationPrincipal User currentUser) {
        var targetUserOpt = userRepository.findById(userId);
        if (targetUserOpt.isEmpty()) {
            return ResponseEntity.status(404).body(Map.of("message", "用户不存在"));
        }
        User targetUser = targetUserOpt.get();
        // 隐私控制：非本人且对方隐藏粉丝列表时禁止访问
        if ((currentUser == null || !currentUser.getId().equals(userId))
                && targetUser.isHideFollowers()) {
            return ResponseEntity.status(403).body(Map.of("message", "对方已隐藏粉丝列表"));
        }

        Page<UserFollow> followerPage = followService.getFollowers(userId, PageRequest.of(page, pageSize));
        var users = followerPage.getContent().stream()
                .map(UserFollow::getFollower)
                .map(u -> userService.toProfile(u, currentUser))
                .toList();
        return ResponseEntity.ok(new UserDtos.UserListResp(
                users,
                followerPage.getTotalElements(),
                page,
                pageSize
        ));
    }

    /**
     * 获取互相关注列表。
     */
    @GetMapping("/{userId}/mutual")
    public ResponseEntity<UserDtos.UserListResp> getMutual(
            @PathVariable Long userId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int pageSize,
            @AuthenticationPrincipal User currentUser) {
        Page<UserFollow> mutualPage = followService.getMutualFollows(userId, PageRequest.of(page, pageSize));
        var users = mutualPage.getContent().stream()
                .map(UserFollow::getFollowing)
                .map(u -> userService.toProfile(u, currentUser))
                .toList();
        return ResponseEntity.ok(new UserDtos.UserListResp(
                users,
                mutualPage.getTotalElements(),
                page,
                pageSize
        ));
    }

    /**
     * 获取用户收藏的帖子。
     */
    @GetMapping("/{userId}/favorites")
    public ResponseEntity<?> getFavorites(
            @PathVariable Long userId,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int pageSize,
            @AuthenticationPrincipal User currentUser) {
        var targetUserOpt = userRepository.findById(userId);
        if (targetUserOpt.isEmpty()) {
            return ResponseEntity.status(404).body(Map.of("message", "用户不存在"));
        }
        User targetUser = targetUserOpt.get();
        // 隐私控制：非本人且对方未公开收藏时禁止访问
        if ((currentUser == null || !currentUser.getId().equals(userId))
                && !targetUser.isPublicFavorites()) {
            return ResponseEntity.status(403).body(Map.of("message", "对方已隐藏收藏"));
        }

        var pageable = PageRequest.of(page - 1, pageSize);
        var favoritePage = favoriteService.getFavoritePosts(userId, pageable);
        Long viewerId = currentUser != null ? currentUser.getId() : null;
        List<PostDtos.PostResp> posts = favoritePage.getContent().stream()
                .map(post -> postMapper.toPostResp(post, viewerId))
                .toList();
        return ResponseEntity.ok(new PostDtos.PostListResp(
                posts,
                favoritePage.getTotalElements(),
                page,
                pageSize
        ));
    }

    /**
     * 获取用户发布的帖子。
     */
    @GetMapping("/{userId}/posts")
    public ResponseEntity<PostDtos.PostListResp> getUserPosts(
            @PathVariable Long userId,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int pageSize,
            @AuthenticationPrincipal User currentUser) {
        Page<Post> postPage = postService.getPostsByAuthor(userId, page, pageSize);
        Long viewerId = currentUser != null ? currentUser.getId() : null;
        List<PostDtos.PostResp> posts = postPage.getContent().stream()
                .map(post -> postMapper.toPostResp(post, viewerId))
                .toList();
        return ResponseEntity.ok(new PostDtos.PostListResp(
                posts,
                postPage.getTotalElements(),
                page,
                pageSize
        ));
    }

    /**
     * 搜索用户（用于@功能）
     * GET /users/search?q=name&type=following|all
     * type=following: 只搜索关注的人
     * type=all: 搜索所有用户
     */
    @GetMapping("/search")
    public ResponseEntity<UserDtos.UserListResp> searchUsers(
            @RequestParam String q,
            @RequestParam(defaultValue = "all") String type,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int pageSize,
            @AuthenticationPrincipal User currentUser) {
        if (currentUser == null) {
            // 页面刷新时容忍匿名状态，返回空列表
            return ResponseEntity.ok(new UserDtos.UserListResp(
                    List.of(), 0, page, pageSize));
        }

        List<User> users;
        if ("following".equals(type)) {
            // 只搜索关注的人
            Page<UserFollow> followingPage = followService.getFollowing(
                    currentUser.getId(), PageRequest.of(page, pageSize));
            users = followingPage.getContent().stream()
                    .map(UserFollow::getFollowing)
                    .filter(u -> {
                        String name = u.getName();
                        if (name == null || name.isEmpty()) {
                            name = u.getEmail();
                        }
                        return name != null && name.toLowerCase().contains(q.toLowerCase());
                    })
                    // 按名称匹配度和作者热度排序
                    .sorted((user1, user2) -> {
                        double score1 = calculateUserSortScore(user1, q, currentUser);
                        double score2 = calculateUserSortScore(user2, q, currentUser);
                        return Double.compare(score2, score1);
                    })
                    .toList();
            return ResponseEntity.ok(new UserDtos.UserListResp(
                    users.stream().map(u -> userService.toProfile(u, currentUser)).toList(),
                    users.size(),
                    page,
                    pageSize
            ));
        } else {
            // 搜索所有用户
            List<User> allUsers = userRepository.findByNameContainingIgnoreCase(q);

            // 对搜索结果按名称匹配度和作者热度排序
            List<User> sortedUsers = allUsers.stream()
                    .sorted((user1, user2) -> {
                        // 计算用户1的排序分数
                        double score1 = calculateUserSortScore(user1, q, currentUser);
                        double score2 = calculateUserSortScore(user2, q, currentUser);
                        // 降序排序（分数高的在前）
                        return Double.compare(score2, score1);
                    })
                    .collect(Collectors.toList());

            // 分页处理
            int start = page * pageSize;
            int end = Math.min(start + pageSize, sortedUsers.size());
            users = start < sortedUsers.size() ? sortedUsers.subList(start, end) : List.of();
            return ResponseEntity.ok(new UserDtos.UserListResp(
                    users.stream().map(u -> userService.toProfile(u, currentUser)).toList(),
                    sortedUsers.size(),
                    page,
                    pageSize
            ));
        }
    }

    /**
     * 计算用户排序分数
     * 分数 = 名称匹配度评分 * 0.7 + 热度评分 * 0.3
     *
     * @param user 用户
     * @param query 搜索关键词
     * @param currentUser 当前登录用户（用于获取统计信息）
     * @return 排序分数（越高越靠前）
     */
    private double calculateUserSortScore(User user, String query, User currentUser) {
        // 1. 计算名称匹配度评分
        double nameMatchScore = calculateNameMatchScore(user, query);

        // 2. 计算作者热度评分
        double heatScore = calculateUserHeatScore(user);

        // 3. 综合评分（名称匹配度权重0.7，热度权重0.3）
        return nameMatchScore * 0.7 + heatScore * 0.3;
    }

    /**
     * 计算名称匹配度评分
     */
    private double calculateNameMatchScore(User user, String query) {
        String userName = user.getName() != null ? user.getName().toLowerCase() : "";
        String queryLower = query.toLowerCase();

        if (userName.equals(queryLower)) {
            return 100.0; // 完全匹配
        } else if (userName.startsWith(queryLower)) {
            return 80.0; // 前缀匹配
        } else if (userName.contains(queryLower)) {
            return 60.0; // 包含匹配
        } else {
            return 0.0; // 不匹配（理论上不会发生，因为findByNameContainingIgnoreCase已过滤）
        }
    }

    /**
     * 计算作者热度评分
     * 热度公式：粉丝数 * 1.0 + 收到的点赞数 * 2.0 + 帖子数 * 0.5 + 收到的收藏数 * 1.5
     * 然后归一化到0-100分（使用对数缩放避免极端值影响）
     */
    private double calculateUserHeatScore(User user) {
        // 获取用户统计信息
        UserDtos.ProfileResp profile = userService.toProfile(user);

        long followersCount = profile.followersCount();
        long likesReceived = profile.likesCount();
        long postsCount = profile.postsCount();
        long favoritesReceived = profile.favoritesReceivedCount();

        // 计算原始热度值
        double rawHeat = followersCount * 1.0 +
                        likesReceived * 2.0 +
                        postsCount * 0.5 +
                        favoritesReceived * 1.5;

        // 使用对数缩放归一化到0-100分
        // 公式：100 * log10(1 + rawHeat) / log10(1 + maxHeat)
        // 假设最大热度为10000（可根据实际情况调整）
        final double MAX_HEAT = 10000.0;
        double normalizedScore = 100.0 * Math.log10(1 + rawHeat) / Math.log10(1 + MAX_HEAT);

        return Math.min(normalizedScore, 100.0);
    }
}

