package com.example.paperhub.report;

import com.example.paperhub.auth.User;
import com.example.paperhub.post.Post;
import com.example.paperhub.post.PostStatus;
import jakarta.persistence.*;
import java.time.Instant;

/**
 * 帖子举报实体类
 */
@Entity
@Table(name = "report_post")
public class ReportPost {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // 举报信息
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "reporter_id", nullable = false)
    private User reporter;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "post_id", nullable = false)
    private Post post;

    @Column(name = "description", length = 500)
    private String description;

    @Column(name = "report_time", nullable = false, updatable = false)
    private Instant reportTime = Instant.now();

    // 处理状态
    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false)
    private ReportStatus status = ReportStatus.PENDING;

    // 管理员处理信息
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "admin_id")
    private User admin;

    @Column(name = "handle_time")
    private Instant handleTime;

    @Column(name = "handle_result", length = 500)
    private String handleResult;

    // 帖子处理后的状态
    @Enumerated(EnumType.STRING)
    @Column(name = "post_status_after")
    private PostStatus postStatusAfter;

    // Getters and Setters
    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public User getReporter() {
        return reporter;
    }

    public void setReporter(User reporter) {
        this.reporter = reporter;
    }

    public Post getPost() {
        return post;
    }

    public void setPost(Post post) {
        this.post = post;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public Instant getReportTime() {
        return reportTime;
    }

    public void setReportTime(Instant reportTime) {
        this.reportTime = reportTime;
    }

    public ReportStatus getStatus() {
        return status;
    }

    public void setStatus(ReportStatus status) {
        this.status = status;
    }

    public User getAdmin() {
        return admin;
    }

    public void setAdmin(User admin) {
        this.admin = admin;
    }

    public Instant getHandleTime() {
        return handleTime;
    }

    public void setHandleTime(Instant handleTime) {
        this.handleTime = handleTime;
    }

    public String getHandleResult() {
        return handleResult;
    }

    public void setHandleResult(String handleResult) {
        this.handleResult = handleResult;
    }

    public PostStatus getPostStatusAfter() {
        return postStatusAfter;
    }

    public void setPostStatusAfter(PostStatus postStatusAfter) {
        this.postStatusAfter = postStatusAfter;
    }
}
