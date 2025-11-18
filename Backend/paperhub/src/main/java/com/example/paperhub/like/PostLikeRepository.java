package com.example.paperhub.like;

import com.example.paperhub.auth.User;
import com.example.paperhub.post.Post;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface PostLikeRepository extends JpaRepository<PostLike, Long> {
    Optional<PostLike> findByPostAndUser(Post post, User user);
    boolean existsByPostIdAndUserId(Long postId, Long userId);
    long countByPostId(Long postId);
    @Query("select count(pl) from PostLike pl where pl.post.author.id = :authorId")
    long countByAuthorId(@Param("authorId") Long authorId);
    void deleteByPostId(Long postId);
}

