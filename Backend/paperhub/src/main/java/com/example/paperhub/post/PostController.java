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
import org.springframework.web.multipart.MultipartFile;
import java.io.IOException;
import com.example.paperhub.config.ObsConfig;
import com.obs.services.ObsClient;
import com.obs.services.model.PutObjectResult;
import org.springframework.beans.factory.annotation.Autowired;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

// 屈越-11.4
import com.obs.services.exception.ObsException;
import java.util.HashMap;


@RestController
@RequestMapping("/posts")
@CrossOrigin(origins = "*")
public class PostController {
    private final PostService postService;
    private final LikeService likeService;
    private final WebSocketService webSocketService;

    @Autowired
    private ObsClient obsClient;

    @Autowired
    private ObsConfig obsConfig;

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
        } catch (Exception e) {
            // 记录错误日志
            System.err.println("创建帖子失败: " + e.getMessage());
            e.printStackTrace();
            
            Map<String, String> error = new HashMap<>();
            error.put("message", "创建帖子失败: " + (e.getMessage() != null ? e.getMessage() : "未知错误"));
            return ResponseEntity.status(500).body(error);
        }
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
            resolveAvatar(author.getAvatar()),
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
    private String resolveAvatar(String avatar) {
        if (avatar == null || avatar.trim().isEmpty()) {
            return "images/DefaultAvatar.png";
        }
        // 如果数据库中存储的是带 assets/ 前缀的路径，去掉前缀
        if (avatar.equals("assets/images/DefaultAvatar.png")) {
            return "images/DefaultAvatar.png";
        }
        return avatar;
    }
}
