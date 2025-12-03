package com.example.paperhub.report.dto;

import com.example.paperhub.post.PostStatus;
import com.example.paperhub.report.ReportStatus;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.time.Instant;

/**
 * 举报帖子相关的DTO类
 */
public class ReportPostDtos {

    /**
     * 举报帖子请求
     */
    public record ReportPostRequest(
            @NotNull(message = "帖子ID不能为空")
            Long postId,

            @NotBlank(message = "举报描述不能为空")
            String description
    ) {}

    /**
     * 举报帖子响应
     */
    public record ReportPostResponse(
            Long id,
            Long reporterId,
            String reporterName,
            Long postId,
            String postTitle,
            String description,
            String status,
            Instant reportTime,
            String message
    ) {}

    /**
     * 举报列表项响应
     */
    public record ReportListItemResponse(
            Long id,
            Long reporterId,
            String reporterName,
            String reporterEmail,
            Long postId,
            String postTitle,
            Long postAuthorId,
            String postAuthorName,
            String description,
            String status,
            Instant reportTime,
            Long adminId,
            String adminName,
            Instant handleTime,
            String handleResult,
            String postStatusAfter
    ) {}

    /**
     * 举报列表响应
     */
    public record ReportListResponse(
            java.util.List<ReportListItemResponse> reports,
            long total,
            int page,
            int pageSize
    ) {}

    /**
     * 管理员处理举报请求（下架）
     */
    public record RemovePostRequest(
            @NotBlank(message = "下架原因不能为空")
            String reason
    ) {}

    /**
     * 管理员忽略举报请求
     */
    public record IgnoreReportRequest(
            String reason
    ) {}

    /**
     * 管理员审核拒绝请求
     */
    public record RejectPostRequest(
            @NotBlank(message = "拒绝原因不能为空")
            String reason
    ) {}

    /**
     * 保存草稿请求
     */
    public record SaveDraftRequest(
            @NotBlank(message = "标题不能为空")
            String title,

            @NotBlank(message = "内容不能为空")
            String content,

            java.util.List<String> media,
            java.util.List<String> tags
    ) {}

    /**
     * 帖子详情响应
     */
    public record PostDetailResponse(
            Long id,
            String title,
            String content,
            java.util.List<String> media,
            java.util.List<String> tags,
            Long authorId,
            String authorName,
            String status,
            String hiddenReason,
            boolean visible,
            boolean canEdit,
            String message,
            Instant createdAt,
            Instant updatedAt
    ) {}

    /**
     * 帖子列表项响应（用于审核列表）
     */
    public record PostListItemResponse(
            Long id,
            String title,
            Long authorId,
            String authorName,
            String authorEmail,
            String status,
            String hiddenReason,
            Instant createdAt,
            Instant updatedAt
    ) {}

    /**
     * 帖子列表响应
     */
    public record PostListResponse(
            java.util.List<PostListItemResponse> posts,
            long total,
            int page,
            int pageSize
    ) {}

    /**
     * 通用操作响应
     */
    public record OperationResponse(
            boolean success,
            String message,
            Object data
    ) {}
}
