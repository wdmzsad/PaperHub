package com.example.paperhub.report;

import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserRepository;
import com.example.paperhub.auth.UserRole;
import com.example.paperhub.post.Post;
import com.example.paperhub.post.PostRepository;
import com.example.paperhub.post.PostStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.Arrays;
import java.util.List;

/**
 * 举报帖子服务层
 */
@Service
public class ReportPostService {

    private final ReportPostRepository reportPostRepository;
    private final PostRepository postRepository;
    private final UserRepository userRepository;
    private final com.example.paperhub.notification.NotificationService notificationService;

    public ReportPostService(ReportPostRepository reportPostRepository,
                             PostRepository postRepository,
                             UserRepository userRepository,
                             com.example.paperhub.notification.NotificationService notificationService) {
        this.reportPostRepository = reportPostRepository;
        this.postRepository = postRepository;
        this.userRepository = userRepository;
        this.notificationService = notificationService;
    }

    // ==================== 用户端功能 ====================

    /**
     * 用户举报帖子
     */
    @Transactional
    public ReportPost reportPost(Long postId, String description, User reporter) {
        if (reporter == null) {
            throw new IllegalArgumentException("用户未登录");
        }

        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new IllegalArgumentException("帖子不存在"));

        // 检查是否已经举报过
        if (reportPostRepository.existsByReporterAndPost(reporter, post)) {
            throw new IllegalArgumentException("您已经举报过该帖子");
        }

        // 不能举报自己的帖子
        if (post.getAuthor().getId().equals(reporter.getId())) {
            throw new IllegalArgumentException("不能举报自己的帖子");
        }

        ReportPost report = new ReportPost();
        report.setReporter(reporter);
        report.setPost(post);
        report.setDescription(description);
        report.setStatus(ReportStatus.PENDING);
        report.setReportTime(Instant.now());

        return reportPostRepository.save(report);
    }

    /**
     * 获取帖子详情（根据用户身份和帖子状态返回不同内容）
     */
    public PostDetailResponse getPostDetail(Long postId, User currentUser) {
        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new IllegalArgumentException("帖子不存在"));

        PostDetailResponse response = new PostDetailResponse();
        response.setPost(post);

        boolean isAuthor = currentUser != null &&
                          post.getAuthor().getId().equals(currentUser.getId());

        switch (post.getStatus()) {
            case NORMAL:
                // 正常状态，所有人都可以查看
                response.setVisible(true);
                response.setMessage("正常");
                response.setCanEdit(isAuthor);
                break;

            case REMOVED:
                // 已下架状态
                if (isAuthor) {
                    // 作者本人可以查看和修改
                    response.setVisible(true);
                    response.setMessage("该帖子已被下架，原因：" +
                                      (post.getHiddenReason() != null ? post.getHiddenReason() : "违规内容") +
                                      "。您可以修改后重新提交审核。");
                    response.setCanEdit(true);
                } else {
                    // 普通用户不可见
                    response.setVisible(false);
                    response.setMessage("该帖子已被下架");
                    response.setCanEdit(false);
                }
                break;

            case DRAFT:
                // 草稿状态，只有作者可见
                if (isAuthor) {
                    response.setVisible(true);
                    response.setMessage("草稿状态，可继续编辑");
                    response.setCanEdit(true);
                } else {
                    response.setVisible(false);
                    response.setMessage("该帖子不存在或已被删除");
                    response.setCanEdit(false);
                }
                break;

            case AUDIT:
                // 审核中状态
                if (isAuthor) {
                    response.setVisible(true);
                    response.setMessage("审核中，请等待管理员审核");
                    response.setCanEdit(false);
                } else {
                    response.setVisible(false);
                    response.setMessage("该帖子正在审核中");
                    response.setCanEdit(false);
                }
                break;

            default:
                response.setVisible(false);
                response.setMessage("未知状态");
                response.setCanEdit(false);
        }

        return response;
    }

    /**
     * 作者保存草稿（修改被下架的帖子）
     */
    @Transactional
    public Post saveDraft(Long postId, String title, String content,
                         List<String> media, List<String> tags, User author) {
        if (author == null) {
            throw new IllegalArgumentException("用户未登录");
        }

        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new IllegalArgumentException("帖子不存在"));

        // 只有作者本人可以修改
        if (!post.getAuthor().getId().equals(author.getId())) {
            throw new IllegalArgumentException("只有作者本人可以修改帖子");
        }

        // 只有被下架的帖子才能修改
        if (post.getStatus() != PostStatus.REMOVED && post.getStatus() != PostStatus.DRAFT) {
            throw new IllegalArgumentException("只有被下架的帖子才能修改");
        }

        // 更新帖子内容
        post.setTitle(title);
        post.setContent(content);
        if (media != null) {
            post.setMedia(media);
        }
        if (tags != null) {
            post.setTags(tags);
        }
        post.setStatus(PostStatus.DRAFT);
        post.setUpdatedAt(Instant.now());

        return postRepository.save(post);
    }

    /**
     * 作者提交审核
     */
    @Transactional
    public Post submitForAudit(Long postId, User author) {
        if (author == null) {
            throw new IllegalArgumentException("用户未登录");
        }

        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new IllegalArgumentException("帖子不存在"));

        // 只有作者本人可以提交
        if (!post.getAuthor().getId().equals(author.getId())) {
            throw new IllegalArgumentException("只有作者本人可以提交审核");
        }

        // 只有草稿状态才能提交审核
        if (post.getStatus() != PostStatus.DRAFT) {
            throw new IllegalArgumentException("只有草稿状态的帖子才能提交审核");
        }

        post.setStatus(PostStatus.AUDIT);
        post.setUpdatedAt(Instant.now());

        return postRepository.save(post);
    }

    /**
     * 查询作者的被下架帖子列表
     */
    public Page<Post> getAuthorRemovedPosts(Long authorId, Pageable pageable) {
        return postRepository.findByAuthorIdAndStatusInOrderByCreatedAtDesc(
                authorId,
                Arrays.asList(PostStatus.REMOVED, PostStatus.DRAFT, PostStatus.AUDIT),
                pageable
        );
    }

    // ==================== 管理员端功能 ====================

    /**
     * 查看所有举报列表
     */
    public Page<ReportPost> getAllReports(Pageable pageable) {
        return reportPostRepository.findAllByOrderByReportTimeDesc(pageable);
    }

    /**
     * 根据状态查看举报列表
     */
    public Page<ReportPost> getReportsByStatus(ReportStatus status, Pageable pageable) {
        return reportPostRepository.findByStatus(status, pageable);
    }

    /**
     * 管理员处理举报：下架帖子
     */
    @Transactional
    public ReportPost removePost(Long reportId, String reason, User admin) {
        if (admin == null || (admin.getRole() != UserRole.ADMIN && admin.getRole() != UserRole.SUPER_ADMIN)) {
            throw new IllegalArgumentException("只有管理员可以处理举报");
        }

        ReportPost report = reportPostRepository.findById(reportId)
                .orElseThrow(() -> new IllegalArgumentException("举报记录不存在"));

        if (report.getStatus() != ReportStatus.PENDING) {
            throw new IllegalArgumentException("该举报已被处理");
        }

        Post post = report.getPost();

        // 更新帖子状态
        post.setStatus(PostStatus.REMOVED);
        post.setHiddenReason(reason != null ? reason : "违规内容");
        post.setUpdatedByAdmin(admin.getId());
        post.setVisibleToAuthor(true); // 作者仍可见以便修改
        post.setUpdatedAt(Instant.now());
        postRepository.save(post);

        // 更新举报记录
        report.setStatus(ReportStatus.PROCESSED);
        report.setAdmin(admin);
        report.setHandleTime(Instant.now());
        report.setHandleResult("已下架，原因：" + (reason != null ? reason : "违规内容"));
        report.setPostStatusAfter(PostStatus.REMOVED);

        // 发送通知给作者
        notificationService.createPostRemovedNotification(admin, post.getId(), reason);

        return reportPostRepository.save(report);
    }

    /**
     * 管理员忽略举报
     */
    @Transactional
    public ReportPost ignoreReport(Long reportId, String reason, User admin) {
        if (admin == null || (admin.getRole() != UserRole.ADMIN && admin.getRole() != UserRole.SUPER_ADMIN)) {
            throw new IllegalArgumentException("只有管理员可以处理举报");
        }

        ReportPost report = reportPostRepository.findById(reportId)
                .orElseThrow(() -> new IllegalArgumentException("举报记录不存在"));

        if (report.getStatus() != ReportStatus.PENDING) {
            throw new IllegalArgumentException("该举报已被处理");
        }

        // 只更新举报记录，不修改帖子
        report.setStatus(ReportStatus.IGNORED);
        report.setAdmin(admin);
        report.setHandleTime(Instant.now());
        report.setHandleResult("已忽略，原因：" + (reason != null ? reason : "未发现违规"));
        report.setPostStatusAfter(PostStatus.NORMAL);

        return reportPostRepository.save(report);
    }

    /**
     * 管理员审核通过（将审核中的帖子恢复正常）
     */
    @Transactional
    public Post approvePost(Long postId, User admin) {
        if (admin == null || (admin.getRole() != UserRole.ADMIN && admin.getRole() != UserRole.SUPER_ADMIN)) {
            throw new IllegalArgumentException("只有管理员可以审核帖子");
        }

        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new IllegalArgumentException("帖子不存在"));

        if (post.getStatus() != PostStatus.AUDIT) {
            throw new IllegalArgumentException("只有审核中的帖子才能审核通过");
        }

        // 恢复正常状态
        post.setStatus(PostStatus.NORMAL);
        post.setHiddenReason(null);
        post.setVisibleToAuthor(true);
        post.setUpdatedByAdmin(admin.getId());
        post.setUpdatedAt(Instant.now());

        // 发送通知给作者
        notificationService.createPostApprovedNotification(admin, post.getId());

        return postRepository.save(post);
    }

    /**
     * 管理员拒绝审核（将审核中的帖子重新下架）
     */
    @Transactional
    public Post rejectPost(Long postId, String reason, User admin) {
        if (admin == null || (admin.getRole() != UserRole.ADMIN && admin.getRole() != UserRole.SUPER_ADMIN)) {
            throw new IllegalArgumentException("只有管理员可以审核帖子");
        }

        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new IllegalArgumentException("帖子不存在"));

        if (post.getStatus() != PostStatus.AUDIT) {
            throw new IllegalArgumentException("只有审核中的帖子才能拒绝");
        }

        // 重新下架
        post.setStatus(PostStatus.REMOVED);
        post.setHiddenReason(reason != null ? reason : "审核未通过");
        post.setUpdatedByAdmin(admin.getId());
        post.setUpdatedAt(Instant.now());

        // 发送通知给作者
        notificationService.createPostRejectedNotification(admin, post.getId(), reason);

        return postRepository.save(post);
    }

    /**
     * 查询待审核的帖子列表
     */
    public Page<Post> getAuditPosts(Pageable pageable) {
        return postRepository.findByStatus(PostStatus.AUDIT, pageable);
    }

    /**
     * 统计待处理举报数量
     */
    public long countPendingReports() {
        return reportPostRepository.countByStatus(ReportStatus.PENDING);
    }

    /**
     * 帖子详情响应类
     */
    public static class PostDetailResponse {
        private Post post;
        private boolean visible;
        private String message;
        private boolean canEdit;

        public Post getPost() {
            return post;
        }

        public void setPost(Post post) {
            this.post = post;
        }

        public boolean isVisible() {
            return visible;
        }

        public void setVisible(boolean visible) {
            this.visible = visible;
        }

        public String getMessage() {
            return message;
        }

        public void setMessage(String message) {
            this.message = message;
        }

        public boolean isCanEdit() {
            return canEdit;
        }

        public void setCanEdit(boolean canEdit) {
            this.canEdit = canEdit;
        }
    }
}
