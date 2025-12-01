package com.example.paperhub.follow;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

@Repository
public interface UserFollowRepository extends JpaRepository<UserFollow, Long> {
    boolean existsByFollowerIdAndFollowingId(Long followerId, Long followingId);
    void deleteByFollowerIdAndFollowingId(Long followerId, Long followingId);
    long countByFollowerId(Long followerId);
    long countByFollowingId(Long followingId);
    Page<UserFollow> findByFollowerId(Long followerId, Pageable pageable);
    Page<UserFollow> findByFollowingId(Long followingId, Pageable pageable);

    @Query("""
        select uf
        from UserFollow uf
        where uf.follower.id = :userId
          and exists (
            select 1
            from UserFollow uf2
            where uf2.follower.id = uf.following.id
              and uf2.following.id = :userId
          )
        """)
    Page<UserFollow> findMutualFollows(@Param("userId") Long userId, Pageable pageable);
}

