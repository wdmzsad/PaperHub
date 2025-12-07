package com.example.paperhub.history;

import com.example.paperhub.auth.User;
import jakarta.persistence.*;

import java.time.Instant;

/**
 * 用户搜索历史记录实体：
 * - 每条记录对应用户的一次搜索操作
 * - 使用 (user, keyword, searchType) 唯一约束，同一用户重复搜索相同关键词和类型时更新时间为最新
 */
@Entity
@Table(
        name = "search_history",
        uniqueConstraints = {
                @UniqueConstraint(columnNames = {"user_id", "keyword", "search_type"})
        },
        indexes = {
                @Index(name = "idx_search_history_user_time", columnList = "user_id, created_at DESC"),
                @Index(name = "idx_search_history_keyword", columnList = "keyword")
        }
)
public class SearchHistory {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    /**
     * 搜索关键词
     */
    @Column(name = "keyword", nullable = false, length = 512)
    private String keyword;

    /**
     * 搜索类型：'keyword' | 'tag' | 'author'
     */
    @Column(name = "search_type", nullable = false, length = 20)
    private String searchType;

    /**
     * 搜索次数（用于推荐算法加权）
     */
    @Column(name = "search_count", nullable = false)
    private Integer searchCount = 1;

    /**
     * 搜索时间
     */
    @Column(name = "created_at", nullable = false)
    private Instant createdAt = Instant.now();

    /**
     * 最后搜索时间（用于更新时间）
     */
    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt = Instant.now();

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

    public String getKeyword() {
        return keyword;
    }

    public void setKeyword(String keyword) {
        this.keyword = keyword;
    }

    public String getSearchType() {
        return searchType;
    }

    public void setSearchType(String searchType) {
        this.searchType = searchType;
    }

    public Integer getSearchCount() {
        return searchCount;
    }

    public void setSearchCount(Integer searchCount) {
        this.searchCount = searchCount;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(Instant createdAt) {
        this.createdAt = createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(Instant updatedAt) {
        this.updatedAt = updatedAt;
    }
}