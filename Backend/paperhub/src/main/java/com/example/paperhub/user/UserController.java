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
            return ResponseEntity.status(401).body(Map.of("message", "未认证，请先登录"));
        }
        return ResponseEntity.ok(userService.toProfile(currentUser));
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
    public ResponseEntity<UserDtos.UserListResp> getFollowing(
            @PathVariable Long userId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int pageSize,
            @AuthenticationPrincipal User currentUser) {
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
    public ResponseEntity<UserDtos.UserListResp> getFollowers(
            @PathVariable Long userId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int pageSize,
            @AuthenticationPrincipal User currentUser) {
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
     * 获取用户收藏的帖子。
     */
    @GetMapping("/{userId}/favorites")
    public ResponseEntity<PostDtos.PostListResp> getFavorites(
            @PathVariable Long userId,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int pageSize,
            @AuthenticationPrincipal User currentUser) {
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
}

