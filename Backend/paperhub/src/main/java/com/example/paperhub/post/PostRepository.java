package com.example.paperhub.post;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

@Repository
public interface PostRepository extends JpaRepository<Post, Long> {
    Page<Post> findAllByOrderByCreatedAtDesc(Pageable pageable);
    Page<Post> findByAuthorIdOrderByCreatedAtDesc(Long authorId, Pageable pageable);
    long countByAuthorId(Long authorId);

    // 只查询正常状态的帖子
    Page<Post> findByStatusOrderByCreatedAtDesc(PostStatus status, Pageable pageable);
    Page<Post> findByAuthorIdAndStatusOrderByCreatedAtDesc(Long authorId, PostStatus status, Pageable pageable);

    /**
     * 按关键词搜索帖子并按热度排序
     * 热度计算公式：likesCount + commentsCount
     * 搜索范围：标题、内容、标签
     */
    @Query("SELECT DISTINCT p FROM Post p LEFT JOIN p.tags t " +
           "WHERE LOWER(p.title) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
           "   OR LOWER(p.content) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
           "   OR LOWER(t) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
           "ORDER BY (p.likesCount + p.commentsCount) DESC")
    Page<Post> searchByKeywordOrderByHot(@Param("keyword") String keyword, Pageable pageable);

    /**
     * 按关键词搜索帖子并按发布时间排序（最新优先）
     * 搜索范围：标题、内容、标签
     */
    @Query("SELECT DISTINCT p FROM Post p LEFT JOIN p.tags t " +
           "WHERE (LOWER(p.title) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
           "   OR LOWER(p.content) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
           "   OR LOWER(t) LIKE LOWER(CONCAT('%', :keyword, '%'))) " +
           "AND p.status = 'NORMAL' " +
           "ORDER BY p.createdAt DESC")
    Page<Post> searchByKeywordOrderByNew(@Param("keyword") String keyword, Pageable pageable);
    Page<Post> findByTitleContainingIgnoreCaseOrContentContainingIgnoreCase(
            String title, String content, Pageable pageable);

    Page<Post> findByAuthor_NameContainingIgnoreCaseOrAuthor_EmailContainingIgnoreCase(
            String name, String email, Pageable pageable);

    /**
     * 根据状态查询帖子
     */
    Page<Post> findByStatus(PostStatus status, Pageable pageable);

    /**
     * 根据作者和状态查询帖子
     */
    Page<Post> findByAuthorIdAndStatus(Long authorId, PostStatus status, Pageable pageable);

    /**
     * 查询作者的所有帖子（包括下架的）
     */
    Page<Post> findByAuthorIdAndStatusInOrderByCreatedAtDesc(
            Long authorId, java.util.List<PostStatus> statuses, Pageable pageable);

    /**
     * 按标签查询帖子（支持精确匹配标签名，大小写不敏感）
     * @param tag 标签名称
     * @param pageable 分页参数
     * @return 包含指定标签的帖子分页
     */
    @Query("SELECT DISTINCT p FROM Post p JOIN p.tags t WHERE LOWER(t) = LOWER(:tag) ORDER BY p.createdAt DESC")
    Page<Post> findByTagOrderByCreatedAtDesc(@Param("tag") String tag, Pageable pageable);

    /**
     * 按标签查询帖子并按热度排序（大小写不敏感）
     * 热度计算公式：likesCount + commentsCount
     * @param tag 标签名称
     * @param pageable 分页参数
     * @return 包含指定标签的帖子分页（按热度降序）
     */
    @Query("SELECT p FROM Post p JOIN p.tags t WHERE LOWER(t) = LOWER(:tag) ORDER BY (p.likesCount + p.commentsCount) DESC")
    Page<Post> findByTagOrderByHot(@Param("tag") String tag, Pageable pageable);

    /**
     * 统计包含指定标签的帖子数量
     * @param tag 标签名称
     * @return 包含指定标签的帖子数量
     */
    @Query("SELECT COUNT(DISTINCT p) FROM Post p JOIN p.tags t WHERE t = :tag")
    long countByTag(@Param("tag") String tag);

    /**
     * 按主分区过滤帖子
     * @param mainDiscipline 主分区名称
     * @param pageable 分页参数
     * @return 属于指定主分区的帖子分页
     */
    Page<Post> findByMainDisciplineOrderByCreatedAtDesc(String mainDiscipline, Pageable pageable);

    /**
     * 统计属于指定主分区的帖子数量
     * @param mainDiscipline 主分区名称
     * @return 属于指定主分区的帖子数量
     */
    long countByMainDiscipline(String mainDiscipline);
}

