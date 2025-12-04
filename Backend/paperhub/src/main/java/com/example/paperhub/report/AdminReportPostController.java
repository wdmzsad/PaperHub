package com.example.paperhub.report;

import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserRole;
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
 * 举报帖子控制器 - 管理员端接口
 */
@RestController
@RequestMapping("/api/admin")
@CrossOrigin(origins = "*")
public class AdminReportPostController {

    private final ReportPostService reportPostService;

    public AdminReportPostController(ReportPostService reportPostService) {
        this.reportPostService = reportPostService;
    }

    /**
     * 检查是否为管理员
     */
    private boolean isAdmin(User user) {
        return user != null && (user.getRole() == UserRole.ADMIN || user.getRole() == UserRole.SUPER_ADMIN);
    }

    /**
     * 查看所有举报列表
     * GET /api/admin/report/posts
     */
    @GetMapping("/report/posts")
    public ResponseEntity<?> getAllReports(
            @AuthenticationPrincipal User currentUser,
            @RequestParam(required = false) String status,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int pageSize) {

        if (!isAdmin(currentUser)) {
            return ResponseEntity.status(403).body(
                    new ReportPostDtos.OperationResponse(false, "仅管理员可访问", null)
            );
        }

        try {
            Pageable pageable = PageRequest.of(page, pageSize);
            Page<ReportPost> reportPage;

            if (status != null && !status.isEmpty()) {
                ReportStatus reportStatus = ReportStatus.valueOf(status.toUpperCase());
                reportPage = reportPostService.getReportsByStatus(reportStatus, pageable);
            } else {
                reportPage = reportPostService.getAllReports(pageable);
            }

            var list = reportPage.getContent().stream()
                    .map(r -> new ReportPostDtos.ReportListItemResponse(
                            r.getId(),
                            r.getReporter().getId(),
                            r.getReporter().getName(),
                            r.getReporter().getEmail(),
                            r.getPost().getId(),
                            r.getPost().getTitle(),
                            r.getPost().getAuthor().getId(),
                            r.getPost().getAuthor().getName(),
                            r.getDescription(),
                            r.getStatus().name(),
                            r.getReportTime(),
                            r.getAdmin() != null ? r.getAdmin().getId() : null,
                            r.getAdmin() != null ? r.getAdmin().getName() : null,
                            r.getHandleTime(),
                            r.getHandleResult(),
                            r.getPostStatusAfter() != null ? r.getPostStatusAfter().name() : null
                    ))
                    .toList();

            ReportPostDtos.ReportListResponse response = new ReportPostDtos.ReportListResponse(
                    list,
                    reportPage.getTotalElements(),
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

    /**
     * 管理员处理举报：下架帖子
     * POST /api/admin/report/{id}/remove
     */
    @PostMapping("/report/{id}/remove")
    public ResponseEntity<?> removePost(
            @PathVariable Long id,
            @Valid @RequestBody ReportPostDtos.RemovePostRequest request,
            @AuthenticationPrincipal User currentUser) {

        if (!isAdmin(currentUser)) {
            return ResponseEntity.status(403).body(
                    new ReportPostDtos.OperationResponse(false, "仅管理员可操作", null)
            );
        }

        try {
            ReportPost report = reportPostService.removePost(id, request.reason(), currentUser);

            return ResponseEntity.ok(
                    new ReportPostDtos.OperationResponse(
                            true,
                            "帖子已下架",
                            Map.of(
                                    "reportId", report.getId(),
                                    "postId", report.getPost().getId(),
                                    "status", report.getStatus().name(),
                                    "handleResult", report.getHandleResult()
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
     * 管理员忽略举报
     * POST /api/admin/report/{id}/ignore
     */
    @PostMapping("/report/{id}/ignore")
    public ResponseEntity<?> ignoreReport(
            @PathVariable Long id,
            @Valid @RequestBody ReportPostDtos.IgnoreReportRequest request,
            @AuthenticationPrincipal User currentUser) {

        if (!isAdmin(currentUser)) {
            return ResponseEntity.status(403).body(
                    new ReportPostDtos.OperationResponse(false, "仅管理员可操作", null)
            );
        }

        try {
            ReportPost report = reportPostService.ignoreReport(
                    id,
                    request.reason() != null ? request.reason() : "未发现违规",
                    currentUser
            );

            return ResponseEntity.ok(
                    new ReportPostDtos.OperationResponse(
                            true,
                            "已忽略该举报",
                            Map.of(
                                    "reportId", report.getId(),
                                    "status", report.getStatus().name(),
                                    "handleResult", report.getHandleResult()
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
     * 管理员审核通过
     * POST /api/admin/post/{id}/approve
     */
    @PostMapping("/post/{id}/approve")
    public ResponseEntity<?> approvePost(
            @PathVariable Long id,
            @AuthenticationPrincipal User currentUser) {

        if (!isAdmin(currentUser)) {
            return ResponseEntity.status(403).body(
                    new ReportPostDtos.OperationResponse(false, "仅管理员可操作", null)
            );
        }

        try {
            Post post = reportPostService.approvePost(id, currentUser);

            return ResponseEntity.ok(
                    new ReportPostDtos.OperationResponse(
                            true,
                            "审核通过，帖子已恢复正常",
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
     * 管理员拒绝审核
     * POST /api/admin/post/{id}/reject
     */
    @PostMapping("/post/{id}/reject")
    public ResponseEntity<?> rejectPost(
            @PathVariable Long id,
            @Valid @RequestBody ReportPostDtos.RejectPostRequest request,
            @AuthenticationPrincipal User currentUser) {

        if (!isAdmin(currentUser)) {
            return ResponseEntity.status(403).body(
                    new ReportPostDtos.OperationResponse(false, "仅管理员可操作", null)
            );
        }

        try {
            Post post = reportPostService.rejectPost(id, request.reason(), currentUser);

            return ResponseEntity.ok(
                    new ReportPostDtos.OperationResponse(
                            true,
                            "审核未通过，帖子已重新下架",
                            Map.of(
                                    "postId", post.getId(),
                                    "status", post.getStatus().name(),
                                    "hiddenReason", post.getHiddenReason()
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
     * 查询待审核的帖子列表
     * GET /api/admin/post/audit
     */
    @GetMapping("/post/audit")
    public ResponseEntity<?> getAuditPosts(
            @AuthenticationPrincipal User currentUser,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int pageSize) {

        if (!isAdmin(currentUser)) {
            return ResponseEntity.status(403).body(
                    new ReportPostDtos.OperationResponse(false, "仅管理员可访问", null)
            );
        }

        try {
            Pageable pageable = PageRequest.of(page, pageSize);
            Page<Post> postPage = reportPostService.getAuditPosts(pageable);

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

    /**
     * 统计待处理举报数量
     * GET /api/admin/report/count
     */
    @GetMapping("/report/count")
    public ResponseEntity<?> countPendingReports(@AuthenticationPrincipal User currentUser) {
        if (!isAdmin(currentUser)) {
            return ResponseEntity.status(403).body(
                    new ReportPostDtos.OperationResponse(false, "仅管理员可访问", null)
            );
        }

        try {
            long count = reportPostService.countPendingReports();
            return ResponseEntity.ok(Map.of("count", count));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(
                    new ReportPostDtos.OperationResponse(false, e.getMessage(), null)
            );
        }
    }
}
