package com.example.paperhub.post;

import com.example.paperhub.auth.User;
import jakarta.persistence.*;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

/**
 * 帖子实体类
 */
@Entity
@Table(name = "posts")
public class Post {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id")
    private Long id;

    @Column(name = "title", nullable = false)
    private String title;

    @Column(name = "content", columnDefinition = "TEXT")
    private String content;

    @ElementCollection
    @CollectionTable(name = "post_media", joinColumns = @JoinColumn(name = "post_id"))
    @Column(name = "media_url")
    private List<String> media = new ArrayList<>();

    @ElementCollection
    @CollectionTable(name = "post_tags", joinColumns = @JoinColumn(name = "post_id"))
    @Column(name = "tag")
    private List<String> tags = new ArrayList<>();
    
    //外部链接列表
    @ElementCollection
    @CollectionTable(name = "post_external_links", joinColumns = @JoinColumn(name = "post_id"))
    @Column(name = "external_link")
    private List<String> externalLinks = new ArrayList<>();


    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "author_id", nullable = false)
    private User author;

    // 论文元数据（可选）
    @Column(name = "doi")
    private String doi;
    
    @Column(name = "journal")
    private String journal;
    
    @Column(name = "year")
    private Integer year;
    
    // arXiv 相关元数据（可选）
    @Column(name = "arxiv_id")
    private String arxivId;
    
    @ElementCollection
    @CollectionTable(name = "post_arxiv_authors", joinColumns = @JoinColumn(name = "post_id"))
    @Column(name = "author_name")
    private List<String> arxivAuthors = new ArrayList<>();
    
    @Column(name = "arxiv_published_date")
    private String arxivPublishedDate;
    
    @ElementCollection
    @CollectionTable(name = "post_arxiv_categories", joinColumns = @JoinColumn(name = "post_id"))
    @Column(name = "category")
    private List<String> arxivCategories = new ArrayList<>();

    // 统计信息
    @Column(name = "likes_count", nullable = false)
    private Integer likesCount = 0;

    @Column(name = "comments_count", nullable = false)
    private Integer commentsCount = 0;

    @Column(name = "views_count", nullable = false)
    private Integer viewsCount = 0;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt = Instant.now();

    // 举报系统相关字段
    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false)
    private PostStatus status = PostStatus.NORMAL;

    @Column(name = "hidden_reason")
    private String hiddenReason;

    @Column(name = "updated_by_admin")
    private Long updatedByAdmin;

    @Column(name = "visible_to_author", nullable = false)
    private Boolean visibleToAuthor = true;

    // Getters and Setters
    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getTitle() {
        return title;
    }

    public void setTitle(String title) {
        this.title = title;
    }

    public String getContent() {
        return content;
    }

    public void setContent(String content) {
        this.content = content;
    }

    public List<String> getMedia() {
        return media;
    }

    public void setMedia(List<String> media) {
        this.media = media;
    }

    public List<String> getTags() {
        return tags;
    }

    public void setTags(List<String> tags) {
        this.tags = tags;
    }

    public User getAuthor() {
        return author;
    }

    public void setAuthor(User author) {
        this.author = author;
    }

    public String getDoi() {
        return doi;
    }

    public void setDoi(String doi) {
        this.doi = doi;
    }

    public String getJournal() {
        return journal;
    }

    public void setJournal(String journal) {
        this.journal = journal;
    }

    public Integer getYear() {
        return year;
    }

    public void setYear(Integer year) {
        this.year = year;
    }

    public List<String> getExternalLinks() {
        return externalLinks;
    }

    public void setExternalLinks(List<String> externalLinks) {
        this.externalLinks = externalLinks;
    }

    public Integer getLikesCount() {
        return likesCount;
    }

    public void setLikesCount(Integer likesCount) {
        this.likesCount = likesCount;
    }

    public Integer getCommentsCount() {
        return commentsCount;
    }

    public void setCommentsCount(Integer commentsCount) {
        this.commentsCount = commentsCount;
    }

    public Integer getViewsCount() {
        return viewsCount;
    }

    public void setViewsCount(Integer viewsCount) {
        this.viewsCount = viewsCount;
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

    // arXiv 相关字段的 Getter 和 Setter
    public String getArxivId() {
        return arxivId;
    }

    public void setArxivId(String arxivId) {
        this.arxivId = arxivId;
    }

    public List<String> getArxivAuthors() {
        return arxivAuthors;
    }

    public void setArxivAuthors(List<String> arxivAuthors) {
        this.arxivAuthors = arxivAuthors != null ? arxivAuthors : new ArrayList<>();
    }

    public String getArxivPublishedDate() {
        return arxivPublishedDate;
    }

    public void setArxivPublishedDate(String arxivPublishedDate) {
        this.arxivPublishedDate = arxivPublishedDate;
    }

    public List<String> getArxivCategories() {
        return arxivCategories;
    }

    public void setArxivCategories(List<String> arxivCategories) {
        this.arxivCategories = arxivCategories != null ? arxivCategories : new ArrayList<>();
    }

    // 举报系统相关字段的 Getter 和 Setter
    public PostStatus getStatus() {
        return status;
    }

    public void setStatus(PostStatus status) {
        this.status = status;
    }

    public String getHiddenReason() {
        return hiddenReason;
    }

    public void setHiddenReason(String hiddenReason) {
        this.hiddenReason = hiddenReason;
    }

    public Long getUpdatedByAdmin() {
        return updatedByAdmin;
    }

    public void setUpdatedByAdmin(Long updatedByAdmin) {
        this.updatedByAdmin = updatedByAdmin;
    }

    public Boolean getVisibleToAuthor() {
        return visibleToAuthor;
    }

    public void setVisibleToAuthor(Boolean visibleToAuthor) {
        this.visibleToAuthor = visibleToAuthor;
    }
}

