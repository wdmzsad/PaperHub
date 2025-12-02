package com.example.paperhub.admin;

import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserRepository;
import com.example.paperhub.auth.UserRole;
import com.example.paperhub.auth.UserStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AdminService {

    private final AdminNoticeRepository noticeRepository;
    private final UserRepository userRepository;
    private final AdminReportRepository reportRepository;
    private final AdminApplicationRepository applicationRepository;

    public AdminService(AdminNoticeRepository noticeRepository,
                        UserRepository userRepository,
                        AdminReportRepository reportRepository,
                        AdminApplicationRepository applicationRepository) {
        this.noticeRepository = noticeRepository;
        this.userRepository = userRepository;
        this.reportRepository = reportRepository;
        this.applicationRepository = applicationRepository;
    }

    // ========== 公告相关 ==========

    public Page<AdminNotice> listNotices(String keyword, Pageable pageable) {
        if (keyword != null && !keyword.isBlank()) {
            return noticeRepository.findByTitleContainingIgnoreCase(keyword, pageable);
        }
        return noticeRepository.findAll(pageable);
    }

    public AdminNotice createNotice(AdminDtos.NoticeReq req) {
        AdminNotice n = new AdminNotice();
        n.setTitle(req.title());
        n.setContent(req.content());
        n.setAttachments(req.attachments());
        n.setPublished(Boolean.TRUE.equals(req.published()));
        return noticeRepository.save(n);
    }

    public AdminNotice updateNotice(Long id, AdminDtos.NoticeReq req) {
        AdminNotice n = noticeRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("公告不存在"));
        n.setTitle(req.title());
        n.setContent(req.content());
        n.setAttachments(req.attachments());
        n.setPublished(Boolean.TRUE.equals(req.published()));
        n.setUpdatedAt(java.time.Instant.now());
        return noticeRepository.save(n);
    }

    public void deleteNotice(Long id) {
        noticeRepository.deleteById(id);
    }

    // ========== 举报相关 ==========

    public Page<AdminReport> listReports(String keyword,
                                         ReportStatus status,
                                         ReportTargetType targetType,
                                         Pageable pageable) {
        Page<AdminReport> page;
        if (status != null && targetType != null) {
            page = reportRepository.findByStatusAndTargetType(status, targetType, pageable);
        } else if (status != null) {
            page = reportRepository.findByStatus(status, pageable);
        } else if (targetType != null) {
            page = reportRepository.findByTargetType(targetType, pageable);
        } else {
            page = reportRepository.findAll(pageable);
        }
        if (keyword == null || keyword.isBlank()) {
            return page;
        }
        // 简单实现：对当前页进行内存过滤，匹配举报人/被举报人名字或邮箱、理由
        var filtered = page.getContent().stream().filter(r -> {
            String q = keyword.toLowerCase();
            return matchesUser(r.getReporter(), q)
                    || matchesUser(r.getReportedUser(), q)
                    || (r.getReason() != null && r.getReason().toLowerCase().contains(q));
        }).toList();
        return new org.springframework.data.domain.PageImpl<>(filtered, pageable, filtered.size());
    }

    private boolean matchesUser(com.example.paperhub.auth.User u, String q) {
        if (u == null) return false;
        if (u.getName() != null && u.getName().toLowerCase().contains(q)) return true;
        return u.getEmail() != null && u.getEmail().toLowerCase().contains(q);
    }

    @Transactional
    public AdminReport handleReport(Long reportId,
                                    AdminDtos.ReportAction action,
                                    String note,
                                    User currentUser) {
        if (currentUser == null || (currentUser.getRole() != UserRole.ADMIN
                && currentUser.getRole() != UserRole.SUPER_ADMIN)) {
            throw new IllegalArgumentException("仅管理员可以处理举报");
        }
        AdminReport r = reportRepository.findById(reportId)
                .orElseThrow(() -> new IllegalArgumentException("举报不存在"));
        r.setStatus(ReportStatus.RESOLVED);
        r.setHandledBy(currentUser);
        r.setResolution(action.name() + (note != null ? (": " + note) : ""));
        r.setUpdatedAt(java.time.Instant.now());
        // TODO: 根据 action 执行具体操作（删除帖子/评论、封禁用户），当前仅记录处理结果
        return reportRepository.save(r);
    }

    // ========== 管理员申请相关 ==========

    @Transactional
    public AdminApplication createAdminApplication(AdminDtos.AdminApplicationReq req,
                                                   User currentUser) {
        if (currentUser == null || (currentUser.getRole() != UserRole.ADMIN
                && currentUser.getRole() != UserRole.SUPER_ADMIN)) {
            throw new IllegalArgumentException("仅管理员可以发起推荐");
        }
        User candidate = userRepository.findById(req.candidateUserId())
                .orElseThrow(() -> new IllegalArgumentException("被推荐用户不存在"));
        AdminApplication app = new AdminApplication();
        app.setRecommender(currentUser);
        app.setCandidate(candidate);
        app.setReason(req.reason());
        return applicationRepository.save(app);
    }

    public Page<AdminApplication> listApplications(AdminDtos.AdminApplicationStatus status,
                                                   Pageable pageable) {
        if (status != null) {
            return applicationRepository.findByStatus(status, pageable);
        }
        return applicationRepository.findAll(pageable);
    }

    @Transactional
    public AdminApplication approveApplication(Long appId, User currentUser) {
        ensureSuperAdmin(currentUser);
        AdminApplication app = applicationRepository.findById(appId)
                .orElseThrow(() -> new IllegalArgumentException("申请不存在"));
        app.setStatus(AdminDtos.AdminApplicationStatus.APPROVED);
        app.setDecidedBy(currentUser);
        app.setDecidedAt(java.time.Instant.now());
        // 同时授予被推荐用户管理员权限
        User candidate = app.getCandidate();
        if (candidate.getRole() != UserRole.SUPER_ADMIN) {
            candidate.setRole(UserRole.ADMIN);
            userRepository.save(candidate);
        }
        return applicationRepository.save(app);
    }

    @Transactional
    public AdminApplication rejectApplication(Long appId, User currentUser) {
        ensureSuperAdmin(currentUser);
        AdminApplication app = applicationRepository.findById(appId)
                .orElseThrow(() -> new IllegalArgumentException("申请不存在"));
        app.setStatus(AdminDtos.AdminApplicationStatus.REJECTED);
        app.setDecidedBy(currentUser);
        app.setDecidedAt(java.time.Instant.now());
        return applicationRepository.save(app);
    }

    // ========== 权限相关（仅核心接口，后续可扩展） ==========

    @Transactional
    public void grantAdmin(Long targetUserId, User currentUser) {
        ensureSuperAdmin(currentUser);
        User u = userRepository.findById(targetUserId)
                .orElseThrow(() -> new IllegalArgumentException("用户不存在"));
        if (u.getRole() == UserRole.SUPER_ADMIN) {
            throw new IllegalArgumentException("不能修改超级管理员角色");
        }
        u.setRole(UserRole.ADMIN);
        userRepository.save(u);
    }

    @Transactional
    public void revokeAdmin(Long targetUserId, User currentUser) {
        ensureSuperAdmin(currentUser);
        User u = userRepository.findById(targetUserId)
                .orElseThrow(() -> new IllegalArgumentException("用户不存在"));
        if (u.getRole() == UserRole.SUPER_ADMIN) {
            throw new IllegalArgumentException("不能修改超级管理员角色");
        }
        u.setRole(UserRole.USER);
        userRepository.save(u);
    }

    // ========== 用户封禁 / 禁言 ==========

    @Transactional
    public void banUser(Long targetUserId, User currentUser) {
        if (currentUser == null || (currentUser.getRole() != UserRole.ADMIN
                && currentUser.getRole() != UserRole.SUPER_ADMIN)) {
            throw new IllegalArgumentException("仅管理员可以封禁用户");
        }
        User u = userRepository.findById(targetUserId)
                .orElseThrow(() -> new IllegalArgumentException("用户不存在"));
        if (u.getRole() == UserRole.SUPER_ADMIN || u.getRole() == UserRole.ADMIN) {
            throw new IllegalArgumentException("不能封禁管理员或超级管理员");
        }
        u.setStatus(UserStatus.BANNED);
        u.setMuteUntil(null);
        userRepository.save(u);
    }

    @Transactional
    public void unbanUser(Long targetUserId, User currentUser) {
        if (currentUser == null || (currentUser.getRole() != UserRole.ADMIN
                && currentUser.getRole() != UserRole.SUPER_ADMIN)) {
            throw new IllegalArgumentException("仅管理员可以解除封禁");
        }
        User u = userRepository.findById(targetUserId)
                .orElseThrow(() -> new IllegalArgumentException("用户不存在"));
        u.setStatus(UserStatus.NORMAL);
        u.setMuteUntil(null);
        userRepository.save(u);
    }

    @Transactional
    public void muteUser(Long targetUserId, java.time.Instant muteUntil, User currentUser) {
        if (currentUser == null || (currentUser.getRole() != UserRole.ADMIN
                && currentUser.getRole() != UserRole.SUPER_ADMIN)) {
            throw new IllegalArgumentException("仅管理员可以禁言用户");
        }
        User u = userRepository.findById(targetUserId)
                .orElseThrow(() -> new IllegalArgumentException("用户不存在"));
        if (u.getRole() == UserRole.SUPER_ADMIN || u.getRole() == UserRole.ADMIN) {
            throw new IllegalArgumentException("不能禁言管理员或超级管理员");
        }
        u.setStatus(UserStatus.MUTED);
        u.setMuteUntil(muteUntil);
        userRepository.save(u);
    }

    @Transactional
    public void unmuteUser(Long targetUserId, User currentUser) {
        if (currentUser == null || (currentUser.getRole() != UserRole.ADMIN
                && currentUser.getRole() != UserRole.SUPER_ADMIN)) {
            throw new IllegalArgumentException("仅管理员可以解除禁言");
        }
        User u = userRepository.findById(targetUserId)
                .orElseThrow(() -> new IllegalArgumentException("用户不存在"));
        if (u.getStatus() == UserStatus.MUTED) {
            u.setStatus(UserStatus.NORMAL);
            u.setMuteUntil(null);
            userRepository.save(u);
        }
    }

    private void ensureSuperAdmin(User currentUser) {
        if (currentUser == null || currentUser.getRole() != UserRole.SUPER_ADMIN) {
            throw new IllegalArgumentException("仅超级管理员可以执行此操作");
        }
    }
}


