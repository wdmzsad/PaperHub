package com.example.paperhub.post;

import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

@Service
public class PostService {
    private final PostRepository postRepository;
    private final UserRepository userRepository;

    public PostService(PostRepository postRepository, UserRepository userRepository) {
        this.postRepository = postRepository;
        this.userRepository = userRepository;
    }

    public Optional<Post> findById(Long id) {
        return postRepository.findById(id);
    }

    /**
     * 获取帖子列表（分页）
     */
    public Page<Post> getPosts(int page, int pageSize) {
        Pageable pageable = PageRequest.of(page - 1, pageSize);
        return postRepository.findAllByOrderByCreatedAtDesc(pageable);
    }

    public Page<Post> getPostsByAuthor(Long authorId, int page, int pageSize) {
        Pageable pageable = PageRequest.of(page - 1, pageSize);
        return postRepository.findByAuthorIdOrderByCreatedAtDesc(authorId, pageable);
    }

    /**
     * 创建帖子
     */
    @Transactional
    public Post createPost(String title, String content, User author, List<String> media, 
                          List<String> tags, String doi, String journal, Integer year, List<String> externalLinks) {
        Post post = new Post();
        post.setTitle(title);
        post.setContent(content != null ? content : "");
        post.setAuthor(author);
        post.setMedia(media != null ? media : List.of());
        post.setTags(tags != null ? tags : List.of());
        post.setDoi(doi);
        post.setJournal(journal);
        post.setYear(year);
        // 外部链接列表（可为空）
        post.setExternalLinks(externalLinks != null ? externalLinks : List.of());
        post.setLikesCount(0);
        post.setCommentsCount(0);
        post.setViewsCount(0);
        post.setCreatedAt(Instant.now());
        post.setUpdatedAt(Instant.now());
        
        return postRepository.save(post);
    }

    @Transactional
    public Post save(Post post) {
        return postRepository.save(post);
    }
    
    @Transactional
    public void incrementViewsCount(Long postId) {
        Post post = postRepository.findById(postId)
            .orElseThrow(() -> new IllegalArgumentException("帖子不存在"));
        post.setViewsCount(post.getViewsCount() + 1);
        postRepository.save(post);
    }

    @Transactional
    public void incrementLikesCount(Long postId) {
        Post post = postRepository.findById(postId)
            .orElseThrow(() -> new IllegalArgumentException("帖子不存在"));
        post.setLikesCount(post.getLikesCount() + 1);
        postRepository.save(post);
    }

    @Transactional
    public void decrementLikesCount(Long postId) {
        Post post = postRepository.findById(postId)
            .orElseThrow(() -> new IllegalArgumentException("帖子不存在"));
        if (post.getLikesCount() > 0) {
            post.setLikesCount(post.getLikesCount() - 1);
            postRepository.save(post);
        }
    }

    @Transactional
    public void incrementCommentsCount(Long postId) {
        Post post = postRepository.findById(postId)
            .orElseThrow(() -> new IllegalArgumentException("帖子不存在"));
        post.setCommentsCount(post.getCommentsCount() + 1);
        postRepository.save(post);
    }

    @Transactional
    public void decrementCommentsCount(Long postId) {
        Post post = postRepository.findById(postId)
            .orElseThrow(() -> new IllegalArgumentException("帖子不存在"));
        if (post.getCommentsCount() > 0) {
            post.setCommentsCount(post.getCommentsCount() - 1);
            postRepository.save(post);
        }
    }
}

