package com.example.paperhub.post;

import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserRepository;
import com.example.paperhub.auth.UserStatus;
import com.example.paperhub.comment.CommentRepository;
import com.example.paperhub.favorite.FavoritePostRepository;
import com.example.paperhub.like.CommentLikeRepository;
import com.example.paperhub.like.PostLikeRepository;
import com.example.paperhub.report.ReportPost;
import com.example.paperhub.report.ReportPostRepository;
import com.example.paperhub.report.ReportStatus;
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
    private final PostLikeRepository postLikeRepository;
    private final FavoritePostRepository favoritePostRepository;
    private final CommentRepository commentRepository;
    private final CommentLikeRepository commentLikeRepository;
    private final ReportPostRepository reportPostRepository;

    public PostService(
            PostRepository postRepository,
            UserRepository userRepository,
            PostLikeRepository postLikeRepository,
            FavoritePostRepository favoritePostRepository,
            CommentRepository commentRepository,
            CommentLikeRepository commentLikeRepository,
            ReportPostRepository reportPostRepository) {
        this.postRepository = postRepository;
        this.userRepository = userRepository;
        this.postLikeRepository = postLikeRepository;
        this.favoritePostRepository = favoritePostRepository;
        this.commentRepository = commentRepository;
        this.commentLikeRepository = commentLikeRepository;
        this.reportPostRepository = reportPostRepository;
    }

    public Optional<Post> findById(Long id) {
        return postRepository.findById(id);
    }

    /**
     * 获取帖子列表（分页）- 只返回正常状态的帖子
     */
    public Page<Post> getPosts(int page, int pageSize) {
        Pageable pageable = PageRequest.of(page - 1, pageSize);
        return postRepository.findByStatusOrderByCreatedAtDesc(PostStatus.NORMAL, pageable);
    }

    public Page<Post> getPostsByAuthor(Long authorId, int page, int pageSize) {
        Pageable pageable = PageRequest.of(page - 1, pageSize);
        return postRepository.findByAuthorIdAndStatusOrderByCreatedAtDesc(authorId, PostStatus.NORMAL, pageable);
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

    /**
     * 举报帖子
     */
    @Transactional
    public ReportPost reportPost(Long postId, String description, User reporter) {
        if (reporter == null) {
            throw new IllegalArgumentException("用户未登录");
        }

        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new IllegalArgumentException("帖子不存在"));

        // 检查是否已经举报过
        if (reportPostRepository.existsByReporterAndPost(reporter, post)) {
            throw new IllegalArgumentException("您已经举报过该帖子");
        }

        // 不能举报自己的帖子
        if (post.getAuthor().getId().equals(reporter.getId())) {
            throw new IllegalArgumentException("不能举报自己的帖子");
        }

        ReportPost report = new ReportPost();
        report.setReporter(reporter);
        report.setPost(post);
        report.setDescription(description);
        report.setStatus(ReportStatus.PENDING);
        report.setReportTime(Instant.now());

        return reportPostRepository.save(report);
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

