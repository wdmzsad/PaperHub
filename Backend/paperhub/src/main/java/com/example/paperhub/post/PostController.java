package com.example.paperhub.post;
import com.example.paperhub.auth.User;
import com.example.paperhub.favorite.FavoriteService;
import com.example.paperhub.like.LikeService;
import com.example.paperhub.post.dto.PostDtos;
import com.example.paperhub.websocket.WebSocketService;
import jakarta.validation.Valid;
import org.springframework.data.domain.Page;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import java.io.IOException;
import com.example.paperhub.config.ObsConfig;
import com.obs.services.ObsClient;
import com.obs.services.model.PutObjectResult;
import org.springframework.beans.factory.annotation.Autowired;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

// 屈越-11.4
import com.obs.services.exception.ObsException;


@RestController
@RequestMapping("/posts")
@CrossOrigin(origins = "*")
public class PostController {
    private final PostService postService;
    private final LikeService likeService;
    private final WebSocketService webSocketService;
    private final FavoriteService favoriteService;
    private final PostMapper postMapper;

    @Autowired
    private ObsClient obsClient;

    @Autowired
    private ObsConfig obsConfig;

    public PostController(PostService postService,
                          LikeService likeService,
                          WebSocketService webSocketService,
                          FavoriteService favoriteService,
                          PostMapper postMapper) {
        this.postService = postService;
        this.likeService = likeService;
        this.webSocketService = webSocketService;
        this.favoriteService = favoriteService;
        this.postMapper = postMapper;
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
                .map(post -> postMapper.toPostResp(post, userId))
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
        PostDtos.PostResp resp = postMapper.toPostResp(post, userId);
        
        return ResponseEntity.ok(resp);
    }

    /**
     * 创建帖子
     * POST /posts
     */
    @PostMapping
    public ResponseEntity<?> createPost(
            @Valid @RequestBody PostDtos.CreatePostReq req,
            @AuthenticationPrincipal User user) {
        
        try {
            // 检查用户是否已认证
            if (user == null) {
                Map<String, String> error = new HashMap<>();
                error.put("message", "未认证，请先登录");
                return ResponseEntity.status(401).body(error);
            }
            // 校验所有外链格式，仅允许http/https，禁止javascript:, data:
            if (req.externalLinks() != null) {
                for (String url : req.externalLinks()) {
                    if (!isValidUrl(url)) {
                        return ResponseEntity.badRequest().body(Map.of("message", "外部链接格式非法: " + url));
                    }
                }
            }
            Post post = postService.createPost(
                req.title(),
                req.content(),
                user,
                req.media() != null ? req.media() : new ArrayList<>(),
                req.tags() != null ? req.tags() : new ArrayList<>(),
                req.doi(),
                req.journal(),
                req.year(),
                req.externalLinks() != null ? req.externalLinks() : new ArrayList<>()
            );
            
            PostDtos.PostResp resp = postMapper.toPostResp(post, user.getId());
            return ResponseEntity.status(201).body(resp);
        } catch (Exception e) {
            // 记录错误日志
            System.err.println("创建帖子失败: " + e.getMessage());
            e.printStackTrace();
            
            Map<String, String> error = new HashMap<>();
            error.put("message", "创建帖子失败: " + (e.getMessage() != null ? e.getMessage() : "未知错误"));
            return ResponseEntity.status(500).body(error);
        }
    }
    //判断链接是否合法，允许 http(s)，禁止危险协议
    private boolean isValidUrl(String url) {
        if (url == null) return false;
        String pattern = "^(https?://)[^\\s]+$";
        if (!url.matches(pattern)) return false;
        String lower = url.toLowerCase();
        return !(lower.startsWith("javascript:") || lower.startsWith("data:"));
    }

    // 上传图片接口
    @PostMapping("/upload")
    public ResponseEntity<Map<String, String>> uploadFile(@RequestParam("file") MultipartFile file) {
        System.out.println("=== 上传接口开始执行 ===");
        String fileName = System.currentTimeMillis() + "_" + file.getOriginalFilename();
        String url = "https://" + obsConfig.getBucketName() + ".obs.cn-north-4.myhuaweicloud.com/" + fileName;

        Map<String, String> res = new HashMap<>();

        try {
            PutObjectResult result = obsClient.putObject(obsConfig.getBucketName(), fileName, file.getInputStream());

            // 上传成功
            res.put("message", "文件上传成功");
            res.put("url", url);
            res.put("fileName", fileName);
            return ResponseEntity.ok(res);

        } catch (ObsException e) {
            System.out.println("Error code: " + e.getErrorCode());
            System.out.println("Error message: " + e.getErrorMessage());
            System.out.println("Request ID: " + e.getErrorRequestId());
            System.out.println("Host ID: " + e.getErrorHostId());

            res.put("message", "上传失败：" + e.getErrorMessage());
            res.put("errorCode", e.getErrorCode());
            return ResponseEntity.status(500).body(res);

        } catch (Exception e) {
            e.printStackTrace();
            res.put("message", "未知错误：" + e.getMessage());
            return ResponseEntity.status(500).body(res);
        }
    }


    /**
     * 点赞帖子
     * POST /posts/{postId}/like
     */
    @PostMapping("/{postId}/like")
    public ResponseEntity<?> likePost(
            @PathVariable Long postId,
            @AuthenticationPrincipal User user) {
        try {
            System.out.println("=== 点赞帖子请求 ===");
            System.out.println("帖子ID: " + postId);
            System.out.println("用户: " + (user != null ? user.getId() + " (" + user.getEmail() + ")" : "null"));
            
            if (user == null) {
                System.err.println("错误: 用户未认证");
                Map<String, String> error = new HashMap<>();
                error.put("message", "未认证，请先登录");
                return ResponseEntity.status(401).body(error);
            }
            
            // 执行点赞
            boolean result = likeService.likePost(postId, user);
            System.out.println("点赞操作结果: " + result);
            
            // 获取最新状态
            long likesCount = likeService.getPostLikesCount(postId);
            boolean isLiked = likeService.isPostLiked(postId, user.getId());
            
            System.out.println("当前点赞数: " + likesCount);
            System.out.println("用户是否已点赞: " + isLiked);
            
            // 推送WebSocket消息
            try {
                webSocketService.sendPostLikeUpdate(postId, (int) likesCount, isLiked);
            } catch (Exception wsEx) {
                System.err.println("WebSocket推送失败（不影响主流程）: " + wsEx.getMessage());
            }
            
            PostDtos.LikeResp resp = new PostDtos.LikeResp((int) likesCount, isLiked);
            System.out.println("返回响应: likesCount=" + resp.likesCount() + ", isLiked=" + resp.isLiked());
            return ResponseEntity.ok(resp);
        } catch (Exception e) {
            System.err.println("点赞帖子失败: " + e.getMessage());
            e.printStackTrace();
            
            Map<String, Object> error = new HashMap<>();
            error.put("message", "点赞失败: " + (e.getMessage() != null ? e.getMessage() : "未知错误"));
            error.put("postId", postId);
            return ResponseEntity.status(500).body(error);
        }
    }

    /**
     * 取消点赞帖子
     * DELETE /posts/{postId}/like
     */
    @DeleteMapping("/{postId}/like")
    public ResponseEntity<?> unlikePost(
            @PathVariable Long postId,
            @AuthenticationPrincipal User user) {
        try {
            System.out.println("=== 取消点赞帖子请求 ===");
            System.out.println("帖子ID: " + postId);
            System.out.println("用户: " + (user != null ? user.getId() + " (" + user.getEmail() + ")" : "null"));
            
            if (user == null) {
                System.err.println("错误: 用户未认证");
                Map<String, String> error = new HashMap<>();
                error.put("message", "未认证，请先登录");
                return ResponseEntity.status(401).body(error);
            }
            
            // 执行取消点赞
            boolean result = likeService.unlikePost(postId, user);
            System.out.println("取消点赞操作结果: " + result);
            
            // 获取最新状态
            long likesCount = likeService.getPostLikesCount(postId);
            boolean isLiked = likeService.isPostLiked(postId, user.getId());
            
            System.out.println("当前点赞数: " + likesCount);
            System.out.println("用户是否已点赞: " + isLiked);
            
            // 推送WebSocket消息
            try {
                webSocketService.sendPostLikeUpdate(postId, (int) likesCount, isLiked);
            } catch (Exception wsEx) {
                System.err.println("WebSocket推送失败（不影响主流程）: " + wsEx.getMessage());
            }
            
            PostDtos.LikeResp resp = new PostDtos.LikeResp((int) likesCount, isLiked);
            System.out.println("返回响应: likesCount=" + resp.likesCount() + ", isLiked=" + resp.isLiked());
            return ResponseEntity.ok(resp);
        } catch (Exception e) {
            System.err.println("取消点赞失败: " + e.getMessage());
            e.printStackTrace();
            
            Map<String, Object> error = new HashMap<>();
            error.put("message", "取消点赞失败: " + (e.getMessage() != null ? e.getMessage() : "未知错误"));
            error.put("postId", postId);
            return ResponseEntity.status(500).body(error);
        }
    }

    /**
     * 收藏帖子
     */
    @PostMapping("/{postId}/favorite")
    public ResponseEntity<?> favoritePost(
            @PathVariable Long postId,
            @AuthenticationPrincipal User user) {
        if (user == null) {
            return ResponseEntity.status(401).body(Map.of("message", "未认证，请先登录"));
        }
        try {
            favoriteService.favoritePost(postId, user);
            return ResponseEntity.ok(Map.of("isSaved", true));
        } catch (IllegalArgumentException ex) {
            return ResponseEntity.status(404).body(Map.of("message", ex.getMessage()));
        }
    }

    /**
     * 取消收藏帖子
     */
    @DeleteMapping("/{postId}/favorite")
    public ResponseEntity<?> unfavoritePost(
            @PathVariable Long postId,
            @AuthenticationPrincipal User user) {
        if (user == null) {
            return ResponseEntity.status(401).body(Map.of("message", "未认证，请先登录"));
        }
        favoriteService.unfavoritePost(postId, user);
        return ResponseEntity.ok(Map.of("isSaved", false));
    }

}
