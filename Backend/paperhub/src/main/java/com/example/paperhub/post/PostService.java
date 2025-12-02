package com.example.paperhub.post;

import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserRepository;
import com.example.paperhub.auth.UserStatus;
import com.example.paperhub.comment.CommentRepository;
import com.example.paperhub.favorite.FavoritePostRepository;
import com.example.paperhub.like.CommentLikeRepository;
import com.example.paperhub.like.PostLikeRepository;
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
    private final FollowFeedRepository followFeedRepository;
    private final UserRepository userRepository;
    private final PostLikeRepository postLikeRepository;
    private final FavoritePostRepository favoritePostRepository;
    private final CommentRepository commentRepository;
    private final CommentLikeRepository commentLikeRepository;

    public PostService(
            PostRepository postRepository,
            FollowFeedRepository followFeedRepository,
            UserRepository userRepository,
            PostLikeRepository postLikeRepository,
            FavoritePostRepository favoritePostRepository,
            CommentRepository commentRepository,
            CommentLikeRepository commentLikeRepository) {
        this.postRepository = postRepository;
        this.followFeedRepository = followFeedRepository;
        this.userRepository = userRepository;
        this.postLikeRepository = postLikeRepository;
        this.favoritePostRepository = favoritePostRepository;
        this.commentRepository = commentRepository;
        this.commentLikeRepository = commentLikeRepository;
    }

    public Optional<Post> findById(Long id) {
        return postRepository.findById(id);
    }

    /**
     * 获取帖子列表（分页）
     * @deprecated 请使用 {@link #getPosts(int, int, String)} 方法
     */
    public Page<Post> getPosts(int page, int pageSize) {
        return getPosts(page, pageSize, null);
    }

    public Page<Post> getPostsByAuthor(Long authorId, int page, int pageSize) {
        Pageable pageable = PageRequest.of(page - 1, pageSize);
        return postRepository.findByAuthorIdOrderByCreatedAtDesc(authorId, pageable);
    }

    /**
     * 获取帖子列表（分页），支持按标签过滤
     * @param page 页码（从1开始）
     * @param pageSize 每页大小
     * @param tag 标签名称（可选，为null时返回所有帖子）
     * @return 帖子分页结果
     */
    public Page<Post> getPosts(int page, int pageSize, String tag) {
        Pageable pageable = PageRequest.of(page - 1, pageSize);
        if (tag != null && !tag.trim().isEmpty()) {
            return postRepository.findByTagOrderByCreatedAtDesc(tag.trim(), pageable);
        } else {
            return postRepository.findAllByOrderByCreatedAtDesc(pageable);
        }
    }

    /**
     * 获取“关注”信息流：只包含当前用户关注的作者发布的帖子。
     *
     * @param followerId 当前用户ID
     * @param page       页码（从1开始）
     * @param pageSize   每页大小
     * @return 关注作者的帖子分页结果
     */
    public Page<Post> getFollowingFeed(Long followerId, int page, int pageSize) {
        Pageable pageable = PageRequest.of(page - 1, pageSize);
        return followFeedRepository.findFollowingPosts(followerId, pageable);
    }

    /**
     * 搜索帖子
     * @param keyword 搜索关键词
     * @param sort 排序方式：hot（热度）或new（最新）
     * @param page 页码（从1开始）
     * @param pageSize 每页大小
     * @return 帖子分页结果
     */
    public Page<Post> searchPosts(String keyword, String sort, int page, int pageSize) {
        Pageable pageable = PageRequest.of(page - 1, pageSize);
        if ("new".equals(sort)) {
            return postRepository.searchByKeywordOrderByNew(keyword, pageable);
        } else {
            // 默认按热度排序
            return postRepository.searchByKeywordOrderByHot(keyword, pageable);
        }
    }

    /**
     * 创建帖子
     */
    @Transactional
    public Post createPost(String title, String content, User author, List<String> media, 
                          List<String> tags, String doi, String journal, Integer year, List<String> externalLinks,
                          String arxivId, List<String> arxivAuthors, String arxivPublishedDate, List<String> arxivCategories) {
        ensureUserCanInteract(author);
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
        // arXiv 相关元数据
        post.setArxivId(arxivId);
        post.setArxivAuthors(arxivAuthors != null ? arxivAuthors : List.of());
        post.setArxivPublishedDate(arxivPublishedDate);
        post.setArxivCategories(arxivCategories != null ? arxivCategories : List.of());
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

    /// 删除帖子
    @Transactional
    public void deletePost(Long postId, Long operatorId) {
        Post post = postRepository.findById(postId)
            .orElseThrow(() -> new IllegalArgumentException("帖子不存在"));

        if (!post.getAuthor().getId().equals(operatorId)) {
            throw new SecurityException("无权删除他人的笔记");
        }

        // 先清理依赖该帖子的子表数据，避免外键约束错误
        // 1. 评论及其点赞
        var commentIds = commentRepository.findIdsByPostId(postId);
        if (!commentIds.isEmpty()) {
            commentLikeRepository.deleteByCommentIdIn(commentIds);
            commentRepository.deleteAllById(commentIds);
        }

        // 2. 帖子点赞与收藏
        postLikeRepository.deleteByPostId(postId);
        favoritePostRepository.deleteByPostId(postId);

        postRepository.delete(post);
    }

    private void ensureUserCanInteract(User user) {
        if (user == null) {
            throw new IllegalArgumentException("未认证用户无法执行此操作");
        }
        if (user.getStatus() == UserStatus.BANNED) {
            throw new IllegalArgumentException("账号已被封禁，无法执行此操作");
        }
        if (user.getStatus() == UserStatus.MUTED) {
            Instant muteUntil = user.getMuteUntil();
            if (muteUntil == null || Instant.now().isBefore(muteUntil)) {
                throw new IllegalArgumentException("账号被禁言中，暂时无法发帖");
            }
        }
    }
}

