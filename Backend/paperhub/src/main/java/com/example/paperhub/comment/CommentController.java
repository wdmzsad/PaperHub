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
import java.util.List;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/posts/{postId}/comments")
public class CommentController {
    private final CommentService commentService;
    private final LikeService likeService;
    private final WebSocketService webSocketService;

    public CommentController(CommentService commentService, LikeService likeService, WebSocketService webSocketService) {
        this.commentService = commentService;
        this.likeService = likeService;
        this.webSocketService = webSocketService;
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
    public ResponseEntity<CommentDtos.CommentResp> createComment(
            @PathVariable Long postId,
            @Valid @RequestBody CommentDtos.CreateCommentReq req,
            @AuthenticationPrincipal User user) {
        
        Comment comment = commentService.createComment(
            postId,
            req.content(),
            user,
            req.parentId(),
            req.replyToId()
        );
        
        // 加载子回复
        List<Comment> replies = commentService.getReplies(comment.getId());
        
        CommentDtos.CommentResp resp = convertToCommentRespWithReplies(comment, user.getId(), replies);
        
        // 推送WebSocket消息
        webSocketService.sendCommentCreated(postId, resp);
        
        return ResponseEntity.status(201).body(resp);
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
        
        CommentDtos.CommentResp resp = convertToCommentRespWithReplies(comment, user.getId(), replies);
        
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
    public ResponseEntity<CommentDtos.LikeResp> likeComment(
            @PathVariable Long postId,
            @PathVariable Long commentId,
            @AuthenticationPrincipal User user) {
        
        likeService.likeComment(commentId, user);
        
        long likesCount = likeService.getCommentLikesCount(commentId);
        boolean isLiked = likeService.isCommentLiked(commentId, user.getId());
        
        // 推送WebSocket消息
        webSocketService.sendCommentLikeUpdate(postId, commentId.toString(), (int) likesCount, isLiked);
        
        return ResponseEntity.ok(new CommentDtos.LikeResp((int) likesCount, isLiked));
    }

    /**
     * 取消点赞评论
     * DELETE /posts/{postId}/comments/{commentId}/like
     */
    @DeleteMapping("/{commentId}/like")
    public ResponseEntity<CommentDtos.LikeResp> unlikeComment(
            @PathVariable Long postId,
            @PathVariable Long commentId,
            @AuthenticationPrincipal User user) {
        
        likeService.unlikeComment(commentId, user);
        
        long likesCount = likeService.getCommentLikesCount(commentId);
        boolean isLiked = likeService.isCommentLiked(commentId, user.getId());
        
        // 推送WebSocket消息
        webSocketService.sendCommentLikeUpdate(postId, commentId.toString(), (int) likesCount, isLiked);
        
        return ResponseEntity.ok(new CommentDtos.LikeResp((int) likesCount, isLiked));
    }

    /**
     * 将Comment实体转换为CommentResp DTO
     */
    private CommentDtos.CommentResp convertToCommentResp(Comment comment, Long userId) {
        List<Comment> replies = commentService.getReplies(comment.getId());
        return convertToCommentRespWithReplies(comment, userId, replies);
    }

    private CommentDtos.CommentResp convertToCommentRespWithReplies(Comment comment, Long userId, List<Comment> replies) {
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
            author.getAvatar() != null ? author.getAvatar() : "",
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
                replyTo.getAvatar() != null ? replyTo.getAvatar() : "",
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
                    replyAuthor.getAvatar() != null ? replyAuthor.getAvatar() : "",
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
                        replyReplyTo.getAvatar() != null ? replyReplyTo.getAvatar() : "",
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
                    List.of() // 回复的回复不再嵌套
                );
            })
            .collect(Collectors.toList());

        return new CommentDtos.CommentResp(
            comment.getId().toString(),
            authorInfo,
            comment.getContent(),
            comment.getParent() != null ? comment.getParent().getId().toString() : null,
            replyToInfo,
            comment.getLikesCount(),
            isLiked,
            comment.getCreatedAt().atOffset(ZoneOffset.UTC).toString(),
            replyList
        );
    }
}

