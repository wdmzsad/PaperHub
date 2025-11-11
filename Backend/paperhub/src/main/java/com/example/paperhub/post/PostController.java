package com.example.paperhub.post;

import com.example.paperhub.auth.User;
import com.example.paperhub.like.LikeService;
import com.example.paperhub.post.dto.PostDtos;
import com.example.paperhub.websocket.WebSocketService;
import jakarta.validation.Valid;
import org.springframework.data.domain.Page;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/posts")
public class PostController {
    private final PostService postService;
    private final LikeService likeService;
    private final WebSocketService webSocketService;

    public PostController(PostService postService, LikeService likeService, WebSocketService webSocketService) {
        this.postService = postService;
        this.likeService = likeService;
        this.webSocketService = webSocketService;
    }

    /**
     * 健康检查端点（用于测试后端是否运行）
     * GET /posts/health
     */
    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> health() {
        return ResponseEntity.ok(Map.of(
            "status", "ok",
            "message", "后端服务运行正常",
            "timestamp", java.time.Instant.now().toString()
        ));
    }

    /**
     * 获取帖子列表
     * GET /posts?page=1&pageSize=20
     */
    @GetMapping
    public ResponseEntity<PostDtos.PostListResp> getPosts(
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int pageSize,
            @AuthenticationPrincipal User user) {
        
        try {
            Page<Post> postPage = postService.getPosts(page, pageSize);
            Long userId = (user != null) ? user.getId() : null;
            
            List<PostDtos.PostResp> posts = postPage.getContent().stream()
                .map(post -> convertToPostResp(post, userId))
                .toList();
            
            return ResponseEntity.ok(new PostDtos.PostListResp(
                posts,
                postPage.getTotalElements(),
                page,
                pageSize
            ));
        } catch (Exception e) {
            // 记录错误日志
            System.err.println("获取帖子列表失败: " + e.getMessage());
            e.printStackTrace();
            throw e;
        }
    }

    /**
     * 获取帖子详情
     * GET /posts/{postId}
     */
    @GetMapping("/{postId}")
    public ResponseEntity<PostDtos.PostResp> getPost(
            @PathVariable Long postId,
            @AuthenticationPrincipal User user) {
        
        Post post = postService.findById(postId)
            .orElseThrow(() -> new IllegalArgumentException("帖子不存在"));
        
        // 增加浏览量
        postService.incrementViewsCount(postId);
        
        Long userId = (user != null) ? user.getId() : null;
        PostDtos.PostResp resp = convertToPostResp(post, userId);
        
        return ResponseEntity.ok(resp);
    }

    /**
     * 创建帖子
     * POST /posts
     */
    @PostMapping
    public ResponseEntity<PostDtos.PostResp> createPost(
            @Valid @RequestBody PostDtos.CreatePostReq req,
            @AuthenticationPrincipal User user) {
        
        Post post = postService.createPost(
            req.title(),
            req.content(),
            user,
            req.media() != null ? req.media() : new ArrayList<>(),
            req.tags() != null ? req.tags() : new ArrayList<>(),
            req.doi(),
            req.journal(),
            req.year()
        );
        
        PostDtos.PostResp resp = convertToPostResp(post, user.getId());
        return ResponseEntity.status(201).body(resp);
    }

    /**
     * 点赞帖子
     * POST /posts/{postId}/like
     */
    @PostMapping("/{postId}/like")
    public ResponseEntity<PostDtos.LikeResp> likePost(
            @PathVariable Long postId,
            @AuthenticationPrincipal User user) {
        likeService.likePost(postId, user);
        
        long likesCount = likeService.getPostLikesCount(postId);
        boolean isLiked = likeService.isPostLiked(postId, user.getId());
        
        // 推送WebSocket消息
        webSocketService.sendPostLikeUpdate(postId, (int) likesCount, isLiked);
        
        return ResponseEntity.ok(new PostDtos.LikeResp((int) likesCount, isLiked));
    }

    /**
     * 取消点赞帖子
     * DELETE /posts/{postId}/like
     */
    @DeleteMapping("/{postId}/like")
    public ResponseEntity<PostDtos.LikeResp> unlikePost(
            @PathVariable Long postId,
            @AuthenticationPrincipal User user) {
        likeService.unlikePost(postId, user);
        
        long likesCount = likeService.getPostLikesCount(postId);
        boolean isLiked = likeService.isPostLiked(postId, user.getId());
        
        // 推送WebSocket消息
        webSocketService.sendPostLikeUpdate(postId, (int) likesCount, isLiked);
        
        return ResponseEntity.ok(new PostDtos.LikeResp((int) likesCount, isLiked));
    }

    /**
     * 将Post实体转换为PostResp DTO
     */
    private PostDtos.PostResp convertToPostResp(Post post, Long userId) {
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
            author.getAvatar() != null ? author.getAvatar() : "",
            author.getAffiliation()
        );

        boolean isLiked = userId != null && likeService.isPostLiked(post.getId(), userId);
        
        // 计算图片宽高比（如果有图片）
        double aspectRatio = 1.5; // 默认值
        double naturalWidth = 800.0;
        double naturalHeight = 600.0;
        if (post.getMedia() != null && !post.getMedia().isEmpty()) {
            // 这里可以根据实际情况计算，暂时使用默认值
            // 实际项目中可以从图片URL获取真实尺寸
        }

        return new PostDtos.PostResp(
            post.getId().toString(),
            post.getTitle(),
            post.getContent() != null ? post.getContent() : "",
            post.getMedia() != null ? post.getMedia() : new ArrayList<>(),
            post.getTags() != null ? post.getTags() : new ArrayList<>(),
            authorInfo,
            post.getLikesCount(),
            post.getCommentsCount(),
            post.getViewsCount(),
            isLiked,
            false, // isSaved 需要单独实现收藏功能
            post.getDoi(),
            post.getJournal(),
            post.getYear(),
            post.getCreatedAt().atOffset(ZoneOffset.UTC).toString(),
            aspectRatio,
            naturalWidth,
            naturalHeight
        );
    }
}
