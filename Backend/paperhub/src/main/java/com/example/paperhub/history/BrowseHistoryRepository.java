package com.example.paperhub.history;

import com.example.paperhub.auth.User;
import com.example.paperhub.post.Post;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

public interface BrowseHistoryRepository extends JpaRepository<BrowseHistory, Long> {

    Optional<BrowseHistory> findByUserAndPost(User user, Post post);

    List<BrowseHistory> findTop50ByUserOrderByViewedAtDesc(User user);

    List<BrowseHistory> findByUserAndViewedAtLessThanOrderByViewedAtDesc(User user, Instant viewedAt);

    void deleteByUserAndPost(User user, Post post);

    void deleteByPost(Post post);
}


