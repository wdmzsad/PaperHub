package com.example.paperhub.history;

import com.example.paperhub.auth.User;
import com.example.paperhub.post.Post;
import jakarta.persistence.*;

import java.time.Instant;

/**
 * 用户浏览历史记录实体：
 * - 每条记录对应用户浏览过的一篇帖子
 * - 使用 (user, post) 唯一约束，同一用户多次浏览同一帖子只保留一条，时间更新
 */
@Entity
@Table(
        name = "browse_history",
        uniqueConstraints = {
                @UniqueConstraint(columnNames = {"user_id", "post_id"})
        },
        indexes = {
                @Index(name = "idx_browse_history_user_time", columnList = "user_id, viewed_at DESC"),
                @Index(name = "idx_browse_history_post", columnList = "post_id")
        }
)
public class BrowseHistory {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "post_id", nullable = false)
    private Post post;

    /**
     * 冗余存储标题，便于快速展示与将来做统计分析。
     */
    @Column(name = "post_title", length = 512)
    private String postTitle;

    @Column(name = "viewed_at", nullable = false)
    private Instant viewedAt = Instant.now();

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public User getUser() {
        return user;
    }

    public void setUser(User user) {
        this.user = user;
    }

    public Post getPost() {
        return post;
    }

    public void setPost(Post post) {
        this.post = post;
    }

    public String getPostTitle() {
        return postTitle;
    }

    public void setPostTitle(String postTitle) {
        this.postTitle = postTitle;
    }

    public Instant getViewedAt() {
        return viewedAt;
    }

    public void setViewedAt(Instant viewedAt) {
        this.viewedAt = viewedAt;
    }
}


