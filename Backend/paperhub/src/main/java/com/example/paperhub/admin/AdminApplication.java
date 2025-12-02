package com.example.paperhub.admin;

import com.example.paperhub.auth.User;
import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name = "admin_applications", indexes = {
        @Index(name = "idx_admin_app_status", columnList = "status")
})
public class AdminApplication {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // 推荐该用户的管理员
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "recommender_id", nullable = false)
    private User recommender;

    // 被推荐成为管理员的普通用户
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "candidate_id", nullable = false)
    private User candidate;

    @Column(name = "reason", columnDefinition = "TEXT", nullable = false)
    private String reason;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false)
    private AdminDtos.AdminApplicationStatus status = AdminDtos.AdminApplicationStatus.PENDING;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "decided_by_id")
    private User decidedBy;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    @Column(name = "decided_at")
    private Instant decidedAt;

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public User getRecommender() {
        return recommender;
    }

    public void setRecommender(User recommender) {
        this.recommender = recommender;
    }

    public User getCandidate() {
        return candidate;
    }

    public void setCandidate(User candidate) {
        this.candidate = candidate;
    }

    public String getReason() {
        return reason;
    }

    public void setReason(String reason) {
        this.reason = reason;
    }

    public AdminDtos.AdminApplicationStatus getStatus() {
        return status;
    }

    public void setStatus(AdminDtos.AdminApplicationStatus status) {
        this.status = status;
    }

    public User getDecidedBy() {
        return decidedBy;
    }

    public void setDecidedBy(User decidedBy) {
        this.decidedBy = decidedBy;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(Instant createdAt) {
        this.createdAt = createdAt;
    }

    public Instant getDecidedAt() {
        return decidedAt;
    }

    public void setDecidedAt(Instant decidedAt) {
        this.decidedAt = decidedAt;
    }
}


