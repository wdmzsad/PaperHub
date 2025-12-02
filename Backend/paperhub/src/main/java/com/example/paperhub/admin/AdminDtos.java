package com.example.paperhub.admin;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.time.Instant;
import java.util.List;

public class AdminDtos {

    // ===== 公告 =====
    public record NoticeReq(
            @NotBlank String title,
            String content,
            /**
             * 前端可序列化图片、链接等附件信息为 JSON 字符串传入。
             */
            String attachments,
            @NotNull Boolean published
    ) {}

    public record NoticeResp(
            Long id,
            String title,
            String content,
            String attachments,
            boolean published,
            Instant createdAt,
            Instant updatedAt
    ) {}

    public record NoticeListResp(
            List<NoticeResp> notices,
            long total,
            int page,
            int pageSize
    ) {}

    // ===== 举报 =====
    public enum ReportAction {
        DELETE_POST,
        NO_VIOLATION,
        BAN_USER
    }

    public record ReportFilterReq(
            String q,
            ReportStatus status,
            ReportTargetType targetType
    ) {}

    public record SimpleUserInfo(
            Long id,
            String name,
            String email
    ) {}

    public record ReportResp(
            Long id,
            SimpleUserInfo reporter,
            String targetType,
            SimpleUserInfo reportedUser,
            Long postId,
            Long commentId,
            String reason,
            String status,
            String resolution,
            Instant createdAt
    ) {}

    public record ReportListResp(
            List<ReportResp> reports,
            long total,
            int page,
            int pageSize
    ) {}

    public record HandleReportReq(
            @NotNull ReportAction action,
            String resolutionNote
    ) {}

    // ===== 管理员申请 =====

    public enum AdminApplicationStatus {
        PENDING,
        APPROVED,
        REJECTED
    }

    public record AdminApplicationReq(
            @NotNull Long candidateUserId,
            @NotBlank String reason
    ) {}

    public record AdminApplicationResp(
            Long id,
            SimpleUserInfo recommender,
            SimpleUserInfo candidate,
            String reason,
            String status,
            Instant createdAt,
            Instant decidedAt
    ) {}

    public record AdminApplicationListResp(
            List<AdminApplicationResp> applications,
            long total,
            int page,
            int pageSize
    ) {}
}


