package com.example.paperhub.post;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface PostRepository extends JpaRepository<Post, Long> {
    // 按创建时间倒序分页查询
    Page<Post> findAllByOrderByCreatedAtDesc(Pageable pageable);
}

