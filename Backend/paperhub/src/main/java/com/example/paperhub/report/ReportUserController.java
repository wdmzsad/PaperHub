package com.example.paperhub.report;

import com.example.paperhub.admin.AdminReport;
import com.example.paperhub.admin.AdminReportRepository;
import com.example.paperhub.admin.ReportStatus;
import com.example.paperhub.admin.ReportTargetType;
import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserRepository;
import com.example.paperhub.auth.UserRole;
import com.example.paperhub.post.Post;
import com.example.paperhub.post.PostRepository;
import com.example.paperhub.post.PostStatus;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/report")
@CrossOrigin(origins = "*")
public class ReportUserController {

    private final AdminReportRepository reportRepository;
    private final UserRepository userRepository;
    private final PostRepository postRepository;

    public ReportUserController(AdminReportRepository reportRepository, UserRepository userRepository, PostRepository postRepository) {
        this.reportRepository = reportRepository;
        this.userRepository = userRepository;
        this.postRepository = postRepository;
    }

    @PostMapping("/user/{userId}")
    @Transactional
    public ResponseEntity<?> reportUser(
            @PathVariable Long userId,
            @Valid @RequestBody ReportUserRequest request,
            @AuthenticationPrincipal User currentUser) {

        if (currentUser == null) {
            return ResponseEntity.status(401).body(Map.of("success", false, "message", "用户未登录"));
        }

        try {
            User reportedUser = userRepository.findById(userId)
                    .orElseThrow(() -> new IllegalArgumentException("用户不存在"));

            if (reportedUser.getRole() == UserRole.ADMIN || reportedUser.getRole() == UserRole.SUPER_ADMIN) {
                return ResponseEntity.badRequest().body(Map.of("success", false, "message", "不能举报管理员"));
            }

            if (reportedUser.getId().equals(currentUser.getId())) {
                return ResponseEntity.badRequest().body(Map.of("success", false, "message", "不能举报自己"));
            }

            if (reportRepository.existsByReporterAndReportedUser(currentUser, reportedUser)) {
                return ResponseEntity.badRequest().body(Map.of("success", false, "message", "您已经举报过该用户"));
            }

            AdminReport report = new AdminReport();
            report.setReporter(currentUser);
            report.setReportedUser(reportedUser);
            report.setTargetType(ReportTargetType.USER);
            report.setReason(request.reason());
            report.setStatus(ReportStatus.PENDING);
            report.setCreatedAt(Instant.now());
            report.setUpdatedAt(Instant.now());

            reportRepository.save(report);

            // 将被举报用户状态设置为 AUDIT
            reportedUser.setStatus(com.example.paperhub.auth.UserStatus.AUDIT);
            userRepository.save(reportedUser);

            return ResponseEntity.ok(Map.of("success", true, "message", "举报成功"));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("success", false, "message", e.getMessage()));
        }
    }

    public record ReportUserRequest(String reason) {}
}
