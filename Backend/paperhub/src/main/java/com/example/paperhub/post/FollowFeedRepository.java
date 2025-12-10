package com.example.paperhub.post;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

/**
 * 关注动态相关查询（仅用于基于关注关系的时间线/信息流）。
 *
 * 单独拆分仓库的原因：
 * - 避免在核心 PostRepository 上堆积过多关注/推荐相关的查询；
 * - 便于后续在这里扩展更多 feed 相关的定制 SQL 或优化。
 */
@Repository
public interface FollowFeedRepository extends JpaRepository<Post, Long> {

    /**
     * 查询当前用户关注的所有作者发布的帖子，按创建时间倒序。
     *
     * @param followerId 当前用户ID（follower）
     * @param pageable   分页参数
     * @return 关注的作者发布的帖子分页结果
     */
    @Query("""
        select p
        from Post p
        where p.author.id in (
            select uf.following.id
            from com.example.paperhub.follow.UserFollow uf
            where uf.follower.id = :followerId
        )
        and p.status = 'NORMAL'
        order by p.createdAt desc
        """)
    Page<Post> findFollowingPosts(@Param("followerId") Long followerId, Pageable pageable);
}


