package com.example.paperhub.comment;

import com.example.paperhub.post.Post;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface CommentRepository extends JpaRepository<Comment, Long> {
    // 查找帖子的所有顶层评论（parent为null）
    Page<Comment> findByPostIdAndParentIsNullOrderByCreatedAtDesc(Long postId, Pageable pageable);

    // 查找帖子的所有顶层评论（按点赞数排序）
    @Query("SELECT c FROM Comment c WHERE c.post.id = :postId AND c.parent IS NULL ORDER BY c.likesCount DESC, c.createdAt DESC")
    Page<Comment> findTopLevelCommentsByPostIdOrderByLikesDesc(@Param("postId") Long postId, Pageable pageable);

    // 查找某个评论的所有子回复
    List<Comment> findByParentIdOrderByCreatedAtAsc(Long parentId);

    // 统计帖子的评论数（包括所有层级）
    long countByPostId(Long postId);

    // 统计某个评论的子回复数
    long countByParentId(Long parentId);
}

