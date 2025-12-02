package com.example.paperhub.history;

import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserRepository;
import com.example.paperhub.post.Post;
import com.example.paperhub.post.PostRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;

@Service
public class BrowseHistoryService {

    private static final int MAX_HISTORY_COUNT = 50;

    private final BrowseHistoryRepository historyRepository;
    private final UserRepository userRepository;
    private final PostRepository postRepository;

    public BrowseHistoryService(BrowseHistoryRepository historyRepository,
                                UserRepository userRepository,
                                PostRepository postRepository) {
        this.historyRepository = historyRepository;
        this.userRepository = userRepository;
        this.postRepository = postRepository;
    }

    /**
     * 记录一次浏览：
     * - 如果已有 (user, post) 记录，更新 viewedAt 和标题
     * - 否则新建一条记录
     * - 保证每个用户最多保留 MAX_HISTORY_COUNT 条最新记录
     */
    @Transactional
    public void recordHistory(Long userId, Long postId, String postTitle) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("User not found: " + userId));
        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new IllegalArgumentException("Post not found: " + postId));

        BrowseHistory history = historyRepository.findByUserAndPost(user, post)
                .orElseGet(() -> {
                    BrowseHistory h = new BrowseHistory();
                    h.setUser(user);
                    h.setPost(post);
                    return h;
                });

        history.setPostTitle(postTitle != null ? postTitle : post.getTitle());
        history.setViewedAt(Instant.now());
        historyRepository.save(history);

        // 只保留最近 MAX_HISTORY_COUNT 条
        List<BrowseHistory> latest = historyRepository.findTop50ByUserOrderByViewedAtDesc(user);
        if (latest.size() > MAX_HISTORY_COUNT) {
            Instant threshold = latest.get(MAX_HISTORY_COUNT - 1).getViewedAt();
            List<BrowseHistory> oldOnes =
                    historyRepository.findByUserAndViewedAtLessThanOrderByViewedAtDesc(user, threshold);
            historyRepository.deleteAll(oldOnes);
        }
    }

    @Transactional(readOnly = true)
    public List<BrowseHistory> getHistory(Long userId, int limit) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("User not found: " + userId));
        List<BrowseHistory> all = historyRepository.findTop50ByUserOrderByViewedAtDesc(user);
        if (limit <= 0 || limit >= all.size()) {
            return all;
        }
        return all.subList(0, limit);
    }

    @Transactional
    public void deleteOne(Long userId, Long postId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("User not found: " + userId));
        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new IllegalArgumentException("Post not found: " + postId));
        historyRepository.deleteByUserAndPost(user, post);
    }

    @Transactional
    public void clearAll(Long userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("User not found: " + userId));
        List<BrowseHistory> all = historyRepository.findTop50ByUserOrderByViewedAtDesc(user);
        historyRepository.deleteAll(all);
    }

    /**
     * 当帖子被删除时调用，清理所有与该帖子相关的浏览记录。
     */
    @Transactional
    public void deleteByPost(Long postId) {
        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new IllegalArgumentException("Post not found: " + postId));
        historyRepository.deleteByPost(post);
    }
}


