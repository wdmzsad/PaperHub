package com.example.paperhub.report;

import com.example.paperhub.post.Post;
import com.example.paperhub.auth.User;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

/**
 * 帖子举报 Repository
 */
@Repository
public interface ReportPostRepository extends JpaRepository<ReportPost, Long> {

    /**
     * 根据状态查询举报列表（分页）
     */
    Page<ReportPost> findByStatus(ReportStatus status, Pageable pageable);

    /**
     * 查询所有举报列表（分页）
     */
    Page<ReportPost> findAllByOrderByReportTimeDesc(Pageable pageable);

    /**
     * 根据帖子ID查询举报记录
     */
    List<ReportPost> findByPost(Post post);

    /**
     * 根据举报人查询举报记录
     */
    List<ReportPost> findByReporter(User reporter);

    /**
     * 查询某个帖子是否已被某用户举报过
     */
    boolean existsByReporterAndPost(User reporter, Post post);

    /**
     * 统计待处理的举报数量
     */
    long countByStatus(ReportStatus status);
}
