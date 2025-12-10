package com.example.paperhub.admin;

import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserRepository;
import com.example.paperhub.auth.UserRole;
import com.example.paperhub.post.Post;
import com.example.paperhub.post.PostRepository;
import jakarta.validation.Valid;
import java.util.List;
import java.util.Map;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

/**
 * 管理员后台相关接口。
 *
 * 说明：
 * - 所有接口都要求已登录（有 JWT），并在必要时校验角色（ADMIN / SUPER_ADMIN）。
 * - 返回结构统一为 JSON，失败时返回 { "message": "错误描述" }。
 */
@RestController
@RequestMapping("/admin")
@CrossOrigin(origins = "*")
public class AdminController {

    private final AdminService adminService;
    private final UserRepository userRepository;
    private final PostRepository postRepository;

    public AdminController(AdminService adminService,
                           UserRepository userRepository,
                           PostRepository postRepository) {
        this.adminService = adminService;
        this.userRepository = userRepository;
        this.postRepository = postRepository;
    }

    private boolean isAdmin(User u) {
        return u != null && (u.getRole() == UserRole.ADMIN || u.getRole() == UserRole.SUPER_ADMIN);
    }

    private boolean isSuperAdmin(User u) {
        return u != null && u.getRole() == UserRole.SUPER_ADMIN;
    }

    // ================== 用户管理（封禁 / 解封） ==================

    @GetMapping("/users")
    public ResponseEntity<?> searchUsers(
            @AuthenticationPrincipal User currentUser,
            @RequestParam(required = false) String q,
            @RequestParam(required = false) String status,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int pageSize) {
        if (!isAdmin(currentUser)) {
            return ResponseEntity.status(403).body(Map.of("message", "仅管理员可访问"));
        }
        Pageable pageable = PageRequest.of(page, pageSize);
        Page<User> userPage;

        // 如果指定了状态过滤
        if (status != null && !status.isBlank()) {
            if ("NON_NORMAL".equals(status.toUpperCase())) {
                // 加载所有非 NORMAL 状态的用户
                userPage = userRepository.findByStatusNot(com.example.paperhub.auth.UserStatus.NORMAL, pageable);
            } else {
                // 按指定状态过滤
                try {
                    com.example.paperhub.auth.UserStatus userStatus =
                        com.example.paperhub.auth.UserStatus.valueOf(status.toUpperCase());
                    userPage = userRepository.findByStatus(userStatus, pageable);
                } catch (IllegalArgumentException e) {
                    return ResponseEntity.badRequest().body(Map.of("message", "无效的状态值"));
                }
            }
        } else if (q != null && !q.isBlank()) {
            // 按关键词搜索
            List<User> byName = userRepository.findByNameContainingIgnoreCase(q);
            userPage = new org.springframework.data.domain.PageImpl<>(byName, pageable, byName.size());
        } else {
            // 查询所有用户
            userPage = userRepository.findAll(pageable);
        }

        var list = userPage.getContent().stream().map(u -> Map.<String, Object>of(
                "id", u.getId(),
                "email", u.getEmail(),
                "name", u.getName(),
                "role", u.getRole() != null ? u.getRole().name() : UserRole.USER.name(),
                "status", u.getStatus() != null ? u.getStatus().name() : "NORMAL"
        )).toList();
        return ResponseEntity.ok(Map.of(
                "users", list,
                "total", userPage.getTotalElements(),
                "page", page,
                "pageSize", pageSize
        ));
    }

    // ========== 用户封禁 / 禁言 ==========

    @PostMapping("/users/{userId}/ban")
    public ResponseEntity<?> banUser(@AuthenticationPrincipal User currentUser,
                                     @PathVariable Long userId) {
        try {
            adminService.banUser(userId, currentUser);
            return ResponseEntity.ok(Map.of("message", "用户已封禁"));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    @PostMapping("/users/{userId}/unban")
    public ResponseEntity<?> unbanUser(@AuthenticationPrincipal User currentUser,
                                       @PathVariable Long userId) {
        try {
            adminService.unbanUser(userId, currentUser);
            return ResponseEntity.ok(Map.of("message", "已解除封禁"));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    @PostMapping("/users/{userId}/mute")
    public ResponseEntity<?> muteUser(@AuthenticationPrincipal User currentUser,
                                      @PathVariable Long userId,
                                      @RequestParam int duration,
                                      @RequestParam String unit) {
        try {
            if (duration <= 0) {
                return ResponseEntity.badRequest().body(Map.of("message", "禁言时长必须大于0"));
            }
            java.time.Instant now = java.time.Instant.now();
            java.time.Instant until;
            switch (unit.toUpperCase()) {
                case "HOURS":
                    until = now.plus(java.time.Duration.ofHours(duration));
                    break;
                case "DAYS":
                    until = now.plus(java.time.Duration.ofDays(duration));
                    break;
                case "MONTHS":
                    until = now.plus(java.time.Duration.ofDays((long) duration * 30));
                    break;
                case "YEARS":
                    until = now.plus(java.time.Duration.ofDays((long) duration * 365));
                    break;
                default:
                    return ResponseEntity.badRequest().body(Map.of("message", "不支持的时间单位"));
            }
            adminService.muteUser(userId, until, currentUser);
            return ResponseEntity.ok(Map.of("message", "用户已禁言至 " + until));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    @PostMapping("/users/{userId}/unmute")
    public ResponseEntity<?> unmuteUser(@AuthenticationPrincipal User currentUser,
                                        @PathVariable Long userId) {
        try {
            adminService.unmuteUser(userId, currentUser);
            return ResponseEntity.ok(Map.of("message", "已解除禁言"));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    // ========== 用户审核 ==========

    @PostMapping("/users/{userId}/approve")
    public ResponseEntity<?> approveUser(@AuthenticationPrincipal User currentUser,
                                         @PathVariable Long userId) {
        try {
            adminService.approveUser(userId, currentUser);
            return ResponseEntity.ok(Map.of("message", "审核通过，用户已恢复正常"));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    @PostMapping("/users/{userId}/reject")
    public ResponseEntity<?> rejectUser(@AuthenticationPrincipal User currentUser,
                                        @PathVariable Long userId,
                                        @RequestBody Map<String, String> body) {
        try {
            String action = body.getOrDefault("action", "BAN");
            String reason = body.getOrDefault("reason", "");
            adminService.rejectUser(userId, action, reason, currentUser);
            return ResponseEntity.ok(Map.of("message", "审核拒绝，已执行处理"));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    // ================== 举报管理 ==================

    @GetMapping("/reports")
    public ResponseEntity<AdminDtos.ReportListResp> listReports(
            @AuthenticationPrincipal User currentUser,
            @RequestParam(required = false) String q,
            @RequestParam(required = false) ReportStatus status,
            @RequestParam(required = false) ReportTargetType targetType,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int pageSize) {
        if (!isAdmin(currentUser)) {
            return ResponseEntity.status(403).build();
        }
        Page<AdminReport> reportPage = adminService.listReports(q, status, targetType,
                PageRequest.of(page, pageSize));
        var list = reportPage.getContent().stream()
                .map(this::toReportResp)
                .toList();
        return ResponseEntity.ok(new AdminDtos.ReportListResp(
                list,
                reportPage.getTotalElements(),
                page,
                pageSize
        ));
    }

    @PostMapping("/reports/{id}/handle")
    public ResponseEntity<?> handleReport(@AuthenticationPrincipal User currentUser,
                                          @PathVariable Long id,
                                          @Valid @RequestBody AdminDtos.HandleReportReq req) {
        try {
            AdminReport r = adminService.handleReport(id, req.action(), req.resolutionNote(), currentUser);
            return ResponseEntity.ok(toReportResp(r));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    // ========== 帖子管理（下架 / 恢复） ==========
    // 这里示例一个简单的“逻辑删除”字段，可按需要在 Post 中新增 status 字段并完善实现。

    @PostMapping("/posts/{postId}/hide")
    public ResponseEntity<?> hidePost(@AuthenticationPrincipal User currentUser,
                                      @PathVariable Long postId) {
        if (!isAdmin(currentUser)) {
            return ResponseEntity.status(403).body(Map.of("message", "仅管理员可操作"));
        }
        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new IllegalArgumentException("帖子不存在"));
        // 目前后端没有 status 字段，这里可以用 likesCount<0 之类的方式临时标记，实际项目建议加 status。
        // 为避免破坏现有逻辑，这里先返回占位响应，由你后续补充真实下架实现。
        return ResponseEntity.ok(Map.of("message", "下架帖子接口占位，需在 Post 中增加状态字段后完善实现"));
    }

    /**
     * 管理员帖子搜索
     * GET /admin/posts?q=关键字&author=作者关键词&page=0&pageSize=20
     */
    @GetMapping("/posts")
    public ResponseEntity<?> searchPosts(
            @AuthenticationPrincipal User currentUser,
            @RequestParam(required = false) String q,
            @RequestParam(required = false) String author,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int pageSize) {
        if (!isAdmin(currentUser)) {
            return ResponseEntity.status(403).body(Map.of("message", "仅管理员可访问"));
        }
        Pageable pageable = PageRequest.of(page, pageSize, Sort.by(Sort.Direction.DESC, "createdAt"));
        Page<Post> postPage;
        if (q != null && !q.isBlank()) {
            postPage = postRepository
                    .findByTitleContainingIgnoreCaseOrContentContainingIgnoreCase(q, q, pageable);
        } else if (author != null && !author.isBlank()) {
            postPage = postRepository
                    .findByAuthor_NameContainingIgnoreCaseOrAuthor_EmailContainingIgnoreCase(author, author, pageable);
        } else {
            postPage = postRepository.findAll(pageable);
        }
        var list = postPage.getContent().stream().map(p -> Map.of(
                "id", p.getId(),
                "title", p.getTitle(),
                "authorId", p.getAuthor() != null ? p.getAuthor().getId() : null,
                "authorName", p.getAuthor() != null ? p.getAuthor().getName() : null,
                "authorEmail", p.getAuthor() != null ? p.getAuthor().getEmail() : null,
                "createdAt", p.getCreatedAt()
        )).toList();
        return ResponseEntity.ok(Map.of(
                "posts", list,
                "total", postPage.getTotalElements(),
                "page", page,
                "pageSize", pageSize
        ));
    }

    // ================== 公告管理 ==================

    @GetMapping("/notices")
    public ResponseEntity<AdminDtos.NoticeListResp> listNotices(
            @AuthenticationPrincipal User currentUser,
            @RequestParam(required = false) String q,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int pageSize) {
        if (!isAdmin(currentUser)) {
            return ResponseEntity.status(403).build();
        }
        Page<AdminNotice> noticePage = adminService.listNotices(q, PageRequest.of(page, pageSize));
        var list = noticePage.getContent().stream()
                .map(this::toNoticeResp)
                .toList();
        return ResponseEntity.ok(new AdminDtos.NoticeListResp(
                list,
                noticePage.getTotalElements(),
                page,
                pageSize
        ));
    }

    @PostMapping("/notices")
    public ResponseEntity<?> createNotice(@AuthenticationPrincipal User currentUser,
                                          @Valid @RequestBody AdminDtos.NoticeReq req) {
        if (!isAdmin(currentUser)) {
            return ResponseEntity.status(403).body(Map.of("message", "仅管理员可发布公告"));
        }
        AdminNotice n = adminService.createNotice(req);
        return ResponseEntity.ok(toNoticeResp(n));
    }

    @PutMapping("/notices/{id}")
    public ResponseEntity<?> updateNotice(@AuthenticationPrincipal User currentUser,
                                          @PathVariable Long id,
                                          @Valid @RequestBody AdminDtos.NoticeReq req) {
        if (!isAdmin(currentUser)) {
            return ResponseEntity.status(403).body(Map.of("message", "仅管理员可编辑公告"));
        }
        AdminNotice n = adminService.updateNotice(id, req);
        return ResponseEntity.ok(toNoticeResp(n));
    }

    @DeleteMapping("/notices/{id}")
    public ResponseEntity<?> deleteNotice(@AuthenticationPrincipal User currentUser,
                                          @PathVariable Long id) {
        if (!isAdmin(currentUser)) {
            return ResponseEntity.status(403).body(Map.of("message", "仅管理员可删除公告"));
        }
        adminService.deleteNotice(id);
        return ResponseEntity.ok(Map.of("message", "删除成功"));
    }

    private AdminDtos.NoticeResp toNoticeResp(AdminNotice n) {
        return new AdminDtos.NoticeResp(
                n.getId(),
                n.getTitle(),
                n.getContent(),
                n.getAttachments(),
                n.isPublished(),
                n.getCreatedAt(),
                n.getUpdatedAt()
        );
    }

    private AdminDtos.SimpleUserInfo toSimpleUser(User u) {
        if (u == null) return null;
        return new AdminDtos.SimpleUserInfo(
                u.getId(),
                u.getName(),
                u.getEmail(),
                u.getRole() != null ? u.getRole().name() : "USER",
                u.getStatus() != null ? u.getStatus().name() : "NORMAL"
        );
    }

    private AdminDtos.ReportResp toReportResp(AdminReport r) {
        Long postId = r.getPost() != null ? r.getPost().getId() : null;
        Long commentId = r.getComment() != null ? r.getComment().getId() : null;
        return new AdminDtos.ReportResp(
                r.getId(),
                toSimpleUser(r.getReporter()),
                r.getTargetType() != null ? r.getTargetType().name() : null,
                toSimpleUser(r.getReportedUser()),
                postId,
                commentId,
                r.getReason(),
                r.getStatus() != null ? r.getStatus().name() : null,
                r.getResolution(),
                r.getCreatedAt()
        );
    }

    // ================== 权限管理（授权 / 收回） ==================

    @PostMapping("/permissions/{userId}/grant-admin")
    public ResponseEntity<?> grantAdmin(@AuthenticationPrincipal User currentUser,
                                        @PathVariable Long userId) {
        try {
            adminService.grantAdmin(userId, currentUser);
            return ResponseEntity.ok(Map.of("message", "已授予管理员权限"));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    @PostMapping("/permissions/{userId}/revoke-admin")
    public ResponseEntity<?> revokeAdmin(@AuthenticationPrincipal User currentUser,
                                         @PathVariable Long userId) {
        try {
            adminService.revokeAdmin(userId, currentUser);
            return ResponseEntity.ok(Map.of("message", "已收回管理员权限"));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    // ================== 管理员申请审核 ==================

    @PostMapping("/applications")
    public ResponseEntity<?> createApplication(@AuthenticationPrincipal User currentUser,
                                               @Valid @RequestBody AdminDtos.AdminApplicationReq req) {
        try {
            AdminApplication app = adminService.createAdminApplication(req, currentUser);
            return ResponseEntity.ok(toApplicationResp(app));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    @GetMapping("/applications")
    public ResponseEntity<AdminDtos.AdminApplicationListResp> listApplications(
            @AuthenticationPrincipal User currentUser,
            @RequestParam(required = false) AdminDtos.AdminApplicationStatus status,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int pageSize) {
        if (!isSuperAdmin(currentUser)) {
            return ResponseEntity.status(403).build();
        }
        Page<AdminApplication> applicationPage =
                adminService.listApplications(status, PageRequest.of(page, pageSize));
        var list = applicationPage.getContent().stream()
                .map(this::toApplicationResp)
                .toList();
        return ResponseEntity.ok(new AdminDtos.AdminApplicationListResp(
                list,
                applicationPage.getTotalElements(),
                page,
                pageSize
        ));
    }

    @PostMapping("/applications/{id}/approve")
    public ResponseEntity<?> approveApplication(@AuthenticationPrincipal User currentUser,
                                                @PathVariable Long id) {
        try {
            AdminApplication app = adminService.approveApplication(id, currentUser);
            return ResponseEntity.ok(toApplicationResp(app));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    @PostMapping("/applications/{id}/reject")
    public ResponseEntity<?> rejectApplication(@AuthenticationPrincipal User currentUser,
                                               @PathVariable Long id) {
        try {
            AdminApplication app = adminService.rejectApplication(id, currentUser);
            return ResponseEntity.ok(toApplicationResp(app));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    private AdminDtos.AdminApplicationResp toApplicationResp(AdminApplication app) {
        return new AdminDtos.AdminApplicationResp(
                app.getId(),
                toSimpleUser(app.getRecommender()),
                toSimpleUser(app.getCandidate()),
                app.getReason(),
                app.getStatus() != null ? app.getStatus().name() : null,
                app.getCreatedAt(),
                app.getDecidedAt()
        );
    }

    // java
    @PostMapping("/post/{postId}/approve-audit")
    public ResponseEntity<?> approveAuditPost(@AuthenticationPrincipal User currentUser,
                                              @PathVariable Long postId) {
        if (!isAdmin(currentUser)) {
            return ResponseEntity.status(403).body(Map.of("message", "需要管理员权限"));
        }
        try {
            adminService.approveAuditPost(postId);
            return ResponseEntity.ok(Map.of("message", "审核通过"));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    @PostMapping("/post/{postId}/reject-audit")
    public ResponseEntity<?> rejectAuditPost(@AuthenticationPrincipal User currentUser,
                                             @PathVariable Long postId,
                                             @RequestBody Map<String, String> body) {
        if (!isAdmin(currentUser)) {
            return ResponseEntity.status(403).body(Map.of("message", "需要管理员权限"));
        }
        try {
            String reason = body.getOrDefault("reason", "不符合发布要求");
            adminService.rejectAuditPost(postId, reason);
            return ResponseEntity.ok(Map.of("message", "已打回草稿"));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }
}


