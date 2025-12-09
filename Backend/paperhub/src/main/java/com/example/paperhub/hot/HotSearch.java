package com.example.paperhub.hot;

import jakarta.persistence.*;
import java.time.Instant;

/**
 * 热搜榜单实体类：
 * - 存储计算后的热搜排名结果
 * - 定时更新（如每10分钟）
 * - 包含热度分数、排名、标签（新/热）等展示信息
 */
@Entity
@Table(name = "hot_search")
public class HotSearch {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /**
     * 热搜关键词
     */
    @Column(name = "keyword", nullable = false, length = 512)
    private String keyword;

    /**
     * 搜索类型：'keyword' | 'tag' | 'author'
     */
    @Column(name = "search_type", nullable = false, length = 20)
    private String searchType;

    /**
     * 热度分数（计算得出，用于排序）
     */
    @Column(name = "heat_score", nullable = false)
    private Double heatScore;

    /**
     * 排名（1-based）
     */
    @Column(name = "rank_position", nullable = false)
    private Integer rank;

    /**
     * 标签：'新' - 新上榜，'热' - 持续热门，null - 普通
     */
    @Column(name = "tag", length = 10)
    private String tag;

    /**
     * 搜索总次数（统计周期内）
     */
    @Column(name = "search_count", nullable = false)
    private Long searchCount;

    /**
     * 独立用户数（统计周期内）
     */
    @Column(name = "unique_users", nullable = false)
    private Long uniqueUsers;

    /**
     * 增长率（与上一周期比较）
     */
    @Column(name = "growth_rate")
    private Double growthRate;

    /**
     * 统计周期开始时间
     */
    @Column(name = "period_start", nullable = false)
    private Instant periodStart;

    /**
     * 统计周期结束时间
     */
    @Column(name = "period_end", nullable = false)
    private Instant periodEnd;

    /**
     * 创建时间
     */
    @Column(name = "created_at", nullable = false)
    private Instant createdAt = Instant.now();

    /**
     * 更新时间
     */
    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt = Instant.now();

    // 构造函数
    public HotSearch() {}

    public HotSearch(String keyword, String searchType, Double heatScore, Integer rank,
                     Long searchCount, Long uniqueUsers, Instant periodStart, Instant periodEnd) {
        this.keyword = keyword;
        this.searchType = searchType;
        this.heatScore = heatScore;
        this.rank = rank;
        this.searchCount = searchCount;
        this.uniqueUsers = uniqueUsers;
        this.periodStart = periodStart;
        this.periodEnd = periodEnd;
        this.createdAt = Instant.now();
        this.updatedAt = Instant.now();
    }

    // Getter 和 Setter 方法
    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
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

    public Double getHeatScore() {
        return heatScore;
    }

    public void setHeatScore(Double heatScore) {
        this.heatScore = heatScore;
    }

    public Integer getRank() {
        return rank;
    }

    public void setRank(Integer rank) {
        this.rank = rank;
    }

    public String getTag() {
        return tag;
    }

    public void setTag(String tag) {
        this.tag = tag;
    }

    public Long getSearchCount() {
        return searchCount;
    }

    public void setSearchCount(Long searchCount) {
        this.searchCount = searchCount;
    }

    public Long getUniqueUsers() {
        return uniqueUsers;
    }

    public void setUniqueUsers(Long uniqueUsers) {
        this.uniqueUsers = uniqueUsers;
    }

    public Double getGrowthRate() {
        return growthRate;
    }

    public void setGrowthRate(Double growthRate) {
        this.growthRate = growthRate;
    }

    public Instant getPeriodStart() {
        return periodStart;
    }

    public void setPeriodStart(Instant periodStart) {
        this.periodStart = periodStart;
    }

    public Instant getPeriodEnd() {
        return periodEnd;
    }

    public void setPeriodEnd(Instant periodEnd) {
        this.periodEnd = periodEnd;
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