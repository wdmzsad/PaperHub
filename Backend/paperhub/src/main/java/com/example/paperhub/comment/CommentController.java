package com.example.paperhub.comment;

import com.example.paperhub.auth.User;
import com.example.paperhub.comment.dto.CommentDtos;
import com.example.paperhub.like.LikeService;
import com.example.paperhub.websocket.WebSocketService;
import jakarta.validation.Valid;
import org.springframework.data.domain.Page;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/posts/{postId}/comments")
public class CommentController {
    private final CommentService commentService;
    private final LikeService likeService;
    private final WebSocketService webSocketService;
    private final com.example.paperhub.auth.UserRepository userRepository;

    public CommentController(CommentService commentService, LikeService likeService, WebSocketService webSocketService, com.example.paperhub.auth.UserRepository userRepository) {
        this.commentService = commentService;
        this.likeService = likeService;
        this.webSocketService = webSocketService;
        this.userRepository = userRepository;
    }

    /**
     * 获取评论列表
     * GET /posts/{postId}/comments?page=1&pageSize=20&sort=time
     */
    @GetMapping
    public ResponseEntity<CommentDtos.CommentListResp> getComments(
            @PathVariable Long postId,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int pageSize,
            @RequestParam(defaultValue = "time") String sort,
            @AuthenticationPrincipal User user) {
        
        Page<Comment> commentPage = commentService.getComments(postId, page, pageSize, sort);
        Long userId = user != null ? user.getId() : null;
        
        List<CommentDtos.CommentResp> comments = commentPage.getContent().stream()
            .map(comment -> convertToCommentResp(comment, userId))
            .collect(Collectors.toList());
        
        return ResponseEntity.ok(new CommentDtos.CommentListResp(
            comments,
            commentPage.getTotalElements(),
            page,
            pageSize
        ));
    }

    /**
     * 创建评论
     * POST /posts/{postId}/comments
     */
    @PostMapping
    public ResponseEntity<?> createComment(
            @PathVariable Long postId,
            @Valid @RequestBody CommentDtos.CreateCommentReq req,
            @AuthenticationPrincipal User user) {
        try {
            System.out.println("=== 创建评论请求 ===");
            System.out.println("帖子ID: " + postId);
            System.out.println("用户: " + (user != null ? user.getId() + " (" + user.getEmail() + ")" : "null"));
            System.out.println("评论内容: " + req.content());
            System.out.println("父评论ID: " + req.parentId());
            System.out.println("回复用户ID: " + req.replyToId());
            
            // 检查用户是否已认证
            if (user == null) {
                System.err.println("错误: 用户未认证");
                Map<String, String> error = new HashMap<>();
                error.put("message", "未认证，请先登录");
                return ResponseEntity.status(401).body(error);
            }
            
            List<Long> mentionIds = req.mentionIds() != null ? req.mentionIds() : List.of();
            Comment comment = commentService.createComment(
                postId,
                req.content(),
                user,
                req.parentId(),
                req.replyToId(),
                mentionIds
            );
            
            System.out.println("评论创建成功，ID: " + comment.getId());
            
            // 加载子回复
            List<Comment> replies = commentService.getReplies(comment.getId());
            
            CommentDtos.CommentResp resp = convertToCommentRespWithReplies(comment, user.getId(), replies, mentionIds);
            
            // 推送WebSocket消息
            try {
                webSocketService.sendCommentCreated(postId, resp);
            } catch (Exception wsEx) {
                System.err.println("WebSocket推送失败（不影响主流程）: " + wsEx.getMessage());
            }
            
            System.out.println("返回响应: 评论ID=" + resp.id());
            return ResponseEntity.status(201).body(resp);
        } catch (IllegalArgumentException e) {
            System.err.println("创建评论失败: " + e.getMessage());
            Map<String, Object> error = new HashMap<>();
            error.put("message", e.getMessage());
            return ResponseEntity.status(400).body(error);
        } catch (Exception e) {
            System.err.println("创建评论失败: " + e.getMessage());
            e.printStackTrace();
            
            Map<String, Object> error = new HashMap<>();
            error.put("message", "创建评论失败: " + (e.getMessage() != null ? e.getMessage() : "未知错误"));
            error.put("postId", postId);
            return ResponseEntity.status(500).body(error);
        }
    }

    /**
     * 更新评论
     * PUT /posts/{postId}/comments/{commentId}
     */
    @PutMapping("/{commentId}")
    public ResponseEntity<CommentDtos.CommentResp> updateComment(
            @PathVariable Long postId,
            @PathVariable Long commentId,
            @Valid @RequestBody CommentDtos.UpdateCommentReq req,
            @AuthenticationPrincipal User user) {
        
        Comment comment = commentService.updateComment(commentId, req.content(), user);
        List<Comment> replies = commentService.getReplies(comment.getId());
        
        // 从Comment实体中解析mentionIds
        List<Long> mentionIds = parseMentionIds(comment.getMentionIds());
        CommentDtos.CommentResp resp = convertToCommentRespWithReplies(comment, user.getId(), replies, mentionIds);
        
        // 推送WebSocket消息
        webSocketService.sendCommentUpdated(postId, resp);
        
        return ResponseEntity.ok(resp);
    }

    /**
     * 删除评论
     * DELETE /posts/{postId}/comments/{commentId}
     */
    @DeleteMapping("/{commentId}")
    public ResponseEntity<CommentDtos.CommentResp> deleteComment(
            @PathVariable Long postId,
            @PathVariable Long commentId,
            @AuthenticationPrincipal User user) {
        
        commentService.deleteComment(commentId, user);
        
        // 推送WebSocket消息
        webSocketService.sendCommentDeleted(postId, commentId.toString());
        
        return ResponseEntity.noContent().build();
    }

    /**
     * 点赞评论
     * POST /posts/{postId}/comments/{commentId}/like
     */
    @PostMapping("/{commentId}/like")
    public ResponseEntity<?> likeComment(
            @PathVariable Long postId,
            @PathVariable Long commentId,
            @AuthenticationPrincipal User user) {
        try {
            System.out.println("=== 点赞评论请求 ===");
            System.out.println("帖子ID: " + postId + ", 评论ID: " + commentId);
            System.out.println("用户: " + (user != null ? user.getId() + " (" + user.getEmail() + ")" : "null"));
            
            if (user == null) {
                System.err.println("错误: 用户未认证");
                Map<String, String> error = new HashMap<>();
                error.put("message", "未认证，请先登录");
                return ResponseEntity.status(401).body(error);
            }
            
            // 执行点赞
            boolean result = likeService.likeComment(commentId, user);
            System.out.println("点赞操作结果: " + result);
            
            // 获取最新状态
            long likesCount = likeService.getCommentLikesCount(commentId);
            boolean isLiked = likeService.isCommentLiked(commentId, user.getId());
            
            System.out.println("当前点赞数: " + likesCount);
            System.out.println("用户是否已点赞: " + isLiked);
            
            // 推送WebSocket消息
            try {
                webSocketService.sendCommentLikeUpdate(postId, commentId.toString(), (int) likesCount, isLiked);
            } catch (Exception wsEx) {
                System.err.println("WebSocket推送失败（不影响主流程）: " + wsEx.getMessage());
            }
            
            CommentDtos.LikeResp resp = new CommentDtos.LikeResp((int) likesCount, isLiked);
            System.out.println("返回响应: likesCount=" + resp.likesCount() + ", isLiked=" + resp.isLiked());
            return ResponseEntity.ok(resp);
        } catch (Exception e) {
            System.err.println("点赞评论失败: " + e.getMessage());
            e.printStackTrace();
            
            Map<String, Object> error = new HashMap<>();
            error.put("message", "点赞评论失败: " + (e.getMessage() != null ? e.getMessage() : "未知错误"));
            error.put("commentId", commentId);
            return ResponseEntity.status(500).body(error);
        }
    }

    /**
     * 取消点赞评论
     * DELETE /posts/{postId}/comments/{commentId}/like
     */
    @DeleteMapping("/{commentId}/like")
    public ResponseEntity<?> unlikeComment(
            @PathVariable Long postId,
            @PathVariable Long commentId,
            @AuthenticationPrincipal User user) {
        try {
            System.out.println("=== 取消点赞评论请求 ===");
            System.out.println("帖子ID: " + postId + ", 评论ID: " + commentId);
            System.out.println("用户: " + (user != null ? user.getId() + " (" + user.getEmail() + ")" : "null"));
            
            if (user == null) {
                System.err.println("错误: 用户未认证");
                Map<String, String> error = new HashMap<>();
                error.put("message", "未认证，请先登录");
                return ResponseEntity.status(401).body(error);
            }
            
            // 执行取消点赞
            boolean result = likeService.unlikeComment(commentId, user);
            System.out.println("取消点赞操作结果: " + result);
            
            // 获取最新状态
            long likesCount = likeService.getCommentLikesCount(commentId);
            boolean isLiked = likeService.isCommentLiked(commentId, user.getId());
            
            System.out.println("当前点赞数: " + likesCount);
            System.out.println("用户是否已点赞: " + isLiked);
            
            // 推送WebSocket消息
            try {
                webSocketService.sendCommentLikeUpdate(postId, commentId.toString(), (int) likesCount, isLiked);
            } catch (Exception wsEx) {
                System.err.println("WebSocket推送失败（不影响主流程）: " + wsEx.getMessage());
            }
            
            CommentDtos.LikeResp resp = new CommentDtos.LikeResp((int) likesCount, isLiked);
            System.out.println("返回响应: likesCount=" + resp.likesCount() + ", isLiked=" + resp.isLiked());
            return ResponseEntity.ok(resp);
        } catch (Exception e) {
            System.err.println("取消点赞评论失败: " + e.getMessage());
            e.printStackTrace();
            
            Map<String, Object> error = new HashMap<>();
            error.put("message", "取消点赞评论失败: " + (e.getMessage() != null ? e.getMessage() : "未知错误"));
            error.put("commentId", commentId);
            return ResponseEntity.status(500).body(error);
        }
    }

    /**
     * 将Comment实体转换为CommentResp DTO
     */
    private CommentDtos.CommentResp convertToCommentResp(Comment comment, Long userId) {
        List<Comment> replies = commentService.getReplies(comment.getId());
        // 从Comment实体中解析mentionIds
        List<Long> mentionIds = parseMentionIds(comment.getMentionIds());
        return convertToCommentRespWithReplies(comment, userId, replies, mentionIds);
    }
    
    private List<Long> parseMentionIds(String mentionIdsStr) {
        if (mentionIdsStr == null || mentionIdsStr.trim().isEmpty()) {
            return List.of();
        }
        try {
            return java.util.Arrays.stream(mentionIdsStr.split(","))
                .filter(s -> !s.trim().isEmpty())
                .map(Long::parseLong)
                .collect(Collectors.toList());
        } catch (Exception e) {
            System.err.println("解析mentionIds失败: " + e.getMessage());
            return List.of();
        }
    }

    private CommentDtos.CommentResp convertToCommentRespWithReplies(Comment comment, Long userId, List<Comment> replies, List<Long> mentionIds) {
        User author = comment.getAuthor();
        String authorName = author.getName() != null && !author.getName().isEmpty() 
            ? author.getName() 
            : (author.getEmail().contains("@") 
                ? author.getEmail().substring(0, author.getEmail().indexOf("@")) 
                : author.getEmail());
        CommentDtos.AuthorInfo authorInfo = new CommentDtos.AuthorInfo(
            author.getId(),
            author.getEmail(),
            authorName,
            resolveAvatar(author.getAvatar()),
            author.getAffiliation()
        );

        CommentDtos.AuthorInfo replyToInfo = null;
        if (comment.getReplyTo() != null) {
            User replyTo = comment.getReplyTo();
            String replyToName = replyTo.getName() != null && !replyTo.getName().isEmpty()
                ? replyTo.getName()
                : (replyTo.getEmail().contains("@")
                    ? replyTo.getEmail().substring(0, replyTo.getEmail().indexOf("@"))
                    : replyTo.getEmail());
            replyToInfo = new CommentDtos.AuthorInfo(
                replyTo.getId(),
                replyTo.getEmail(),
                replyToName,
                resolveAvatar(replyTo.getAvatar()),
                replyTo.getAffiliation()
            );
        }

        boolean isLiked = userId != null && likeService.isCommentLiked(comment.getId(), userId);

        List<CommentDtos.CommentResp> replyList = replies.stream()
            .map(reply -> {
                User replyAuthor = reply.getAuthor();
                String replyAuthorName = replyAuthor.getName() != null && !replyAuthor.getName().isEmpty()
                    ? replyAuthor.getName()
                    : (replyAuthor.getEmail().contains("@")
                        ? replyAuthor.getEmail().substring(0, replyAuthor.getEmail().indexOf("@"))
                        : replyAuthor.getEmail());
                CommentDtos.AuthorInfo replyAuthorInfo = new CommentDtos.AuthorInfo(
                    replyAuthor.getId(),
                    replyAuthor.getEmail(),
                    replyAuthorName,
                    resolveAvatar(replyAuthor.getAvatar()),
                    replyAuthor.getAffiliation()
                );
                
                CommentDtos.AuthorInfo replyReplyToInfo = null;
                if (reply.getReplyTo() != null) {
                    User replyReplyTo = reply.getReplyTo();
                    String replyReplyToName = replyReplyTo.getName() != null && !replyReplyTo.getName().isEmpty()
                        ? replyReplyTo.getName()
                        : (replyReplyTo.getEmail().contains("@")
                            ? replyReplyTo.getEmail().substring(0, replyReplyTo.getEmail().indexOf("@"))
                            : replyReplyTo.getEmail());
                    replyReplyToInfo = new CommentDtos.AuthorInfo(
                        replyReplyTo.getId(),
                        replyReplyTo.getEmail(),
                        replyReplyToName,
                        resolveAvatar(replyReplyTo.getAvatar()),
                        replyReplyTo.getAffiliation()
                    );
                }
                
                boolean replyIsLiked = userId != null && likeService.isCommentLiked(reply.getId(), userId);
                
                return new CommentDtos.CommentResp(
                    reply.getId().toString(),
                    replyAuthorInfo,
                    reply.getContent(),
                    reply.getParent() != null ? reply.getParent().getId().toString() : null,
                    replyReplyToInfo,
                    reply.getLikesCount(),
                    replyIsLiked,
                    reply.getCreatedAt().atOffset(ZoneOffset.UTC).toString(),
                    List.of(), // 回复的回复不再嵌套
                    List.of() // 回复暂时不支持@功能
                );
            })
            .collect(Collectors.toList());

        // 构建被@的用户信息列表
        List<CommentDtos.AuthorInfo> mentionInfos = new ArrayList<>();
        if (mentionIds != null && !mentionIds.isEmpty()) {
            for (Long mentionId : mentionIds) {
                userRepository.findById(mentionId).ifPresent(mentionedUser -> {
                    String mentionedUserName = mentionedUser.getName() != null && !mentionedUser.getName().isEmpty()
                        ? mentionedUser.getName()
                        : (mentionedUser.getEmail().contains("@")
                            ? mentionedUser.getEmail().substring(0, mentionedUser.getEmail().indexOf("@"))
                            : mentionedUser.getEmail());
                    mentionInfos.add(new CommentDtos.AuthorInfo(
                        mentionedUser.getId(),
                        mentionedUser.getEmail(),
                        mentionedUserName,
                        resolveAvatar(mentionedUser.getAvatar()),
                        mentionedUser.getAffiliation()
                    ));
                });
            }
        }

        return new CommentDtos.CommentResp(
            comment.getId().toString(),
            authorInfo,
            comment.getContent(),
            comment.getParent() != null ? comment.getParent().getId().toString() : null,
            replyToInfo,
            comment.getLikesCount(),
            isLiked,
            comment.getCreatedAt().atOffset(ZoneOffset.UTC).toString(),
            replyList,
            mentionInfos
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

