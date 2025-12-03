package com.example.paperhub.report;

import com.example.paperhub.auth.User;
import com.example.paperhub.post.Post;
import com.example.paperhub.report.dto.ReportPostDtos;
import jakarta.validation.Valid;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

/**
 * 举报帖子控制器 - 用户端接口
 */
@RestController
@RequestMapping("/api")
@CrossOrigin(origins = "*")
public class ReportPostController {

    private final ReportPostService reportPostService;

    public ReportPostController(ReportPostService reportPostService) {
        this.reportPostService = reportPostService;
    }

    /**
     * 用户举报帖子
     * POST /api/report/post
     */
    @PostMapping("/report/post")
    public ResponseEntity<?> reportPost(
            @Valid @RequestBody ReportPostDtos.ReportPostRequest request,
            @AuthenticationPrincipal User currentUser) {
        try {
            ReportPost report = reportPostService.reportPost(
                    request.postId(),
                    request.description(),
                    currentUser
            );

            ReportPostDtos.ReportPostResponse response = new ReportPostDtos.ReportPostResponse(
                    report.getId(),
                    report.getReporter().getId(),
                    report.getReporter().getName(),
                    report.getPost().getId(),
                    report.getPost().getTitle(),
                    report.getDescription(),
                    report.getStatus().name(),
                    report.getReportTime(),
                    "举报成功，我们会尽快处理"
            );

            return ResponseEntity.ok(response);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(
                    new ReportPostDtos.OperationResponse(false, e.getMessage(), null)
            );
        }
    }

    /**
     * 获取帖子详情（根据状态返回不同内容）
     * GET /api/post/{id}
     */
    @GetMapping("/post/{id}")
    public ResponseEntity<?> getPostDetail(
            @PathVariable Long id,
            @AuthenticationPrincipal User currentUser) {
        try {
            ReportPostService.PostDetailResponse detail = reportPostService.getPostDetail(id, currentUser);

            if (!detail.isVisible()) {
                return ResponseEntity.status(403).body(
                        new ReportPostDtos.OperationResponse(false, detail.getMessage(), null)
                );
            }

            Post post = detail.getPost();
            ReportPostDtos.PostDetailResponse response = new ReportPostDtos.PostDetailResponse(
                    post.getId(),
                    post.getTitle(),
                    post.getContent(),
                    post.getMedia(),
                    post.getTags(),
                    post.getAuthor().getId(),
                    post.getAuthor().getName(),
                    post.getStatus().name(),
                    post.getHiddenReason(),
                    detail.isVisible(),
                    detail.isCanEdit(),
                    detail.getMessage(),
                    post.getCreatedAt(),
                    post.getUpdatedAt()
            );

            return ResponseEntity.ok(response);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(
                    new ReportPostDtos.OperationResponse(false, e.getMessage(), null)
            );
        }
    }

    /**
     * 作者保存草稿（修改被下架的帖子）
     * POST /api/post/{id}/draft
     */
    @PostMapping("/post/{id}/draft")
    public ResponseEntity<?> saveDraft(
            @PathVariable Long id,
            @Valid @RequestBody ReportPostDtos.SaveDraftRequest request,
            @AuthenticationPrincipal User currentUser) {
        try {
            Post post = reportPostService.saveDraft(
                    id,
                    request.title(),
                    request.content(),
                    request.media(),
                    request.tags(),
                    currentUser
            );

            return ResponseEntity.ok(
                    new ReportPostDtos.OperationResponse(
                            true,
                            "草稿保存成功",
                            Map.of(
                                    "postId", post.getId(),
                                    "status", post.getStatus().name()
                            )
                    )
            );
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(
                    new ReportPostDtos.OperationResponse(false, e.getMessage(), null)
            );
        }
    }

    /**
     * 作者提交审核
     * POST /api/post/{id}/submit
     */
    @PostMapping("/post/{id}/submit")
    public ResponseEntity<?> submitForAudit(
            @PathVariable Long id,
            @AuthenticationPrincipal User currentUser) {
        try {
            Post post = reportPostService.submitForAudit(id, currentUser);

            return ResponseEntity.ok(
                    new ReportPostDtos.OperationResponse(
                            true,
                            "已提交审核，请等待管理员审核",
                            Map.of(
                                    "postId", post.getId(),
                                    "status", post.getStatus().name()
                            )
                    )
            );
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(
                    new ReportPostDtos.OperationResponse(false, e.getMessage(), null)
            );
        }
    }

    /**
     * 查询作者的被下架帖子列表
     * GET /api/post/removed
     */
    @GetMapping("/post/removed")
    public ResponseEntity<?> getAuthorRemovedPosts(
            @AuthenticationPrincipal User currentUser,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int pageSize) {
        try {
            if (currentUser == null) {
                return ResponseEntity.status(401).body(
                        new ReportPostDtos.OperationResponse(false, "用户未登录", null)
                );
            }

            Pageable pageable = PageRequest.of(page, pageSize);
            Page<Post> postPage = reportPostService.getAuthorRemovedPosts(
                    currentUser.getId(),
                    pageable
            );

            var list = postPage.getContent().stream()
                    .map(p -> new ReportPostDtos.PostListItemResponse(
                            p.getId(),
                            p.getTitle(),
                            p.getAuthor().getId(),
                            p.getAuthor().getName(),
                            p.getAuthor().getEmail(),
                            p.getStatus().name(),
                            p.getHiddenReason(),
                            p.getCreatedAt(),
                            p.getUpdatedAt()
                    ))
                    .toList();

            ReportPostDtos.PostListResponse response = new ReportPostDtos.PostListResponse(
                    list,
                    postPage.getTotalElements(),
                    page,
                    pageSize
            );

            return ResponseEntity.ok(response);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(
                    new ReportPostDtos.OperationResponse(false, e.getMessage(), null)
            );
        }
    }
}
