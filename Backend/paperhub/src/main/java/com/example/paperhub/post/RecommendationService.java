package com.example.paperhub.post;

import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserRepository;
import com.example.paperhub.favorite.FavoritePost;
import com.example.paperhub.favorite.FavoritePostRepository;
import com.example.paperhub.history.BrowseHistory;
import com.example.paperhub.history.BrowseHistoryRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

/**
 * 首页推荐服务：
 * - 基于研究方向 + 收藏 + 浏览历史 + 自己发帖 + 帖子热度 + 时间进行综合排序
 * - 只对最近 200 条正常状态的帖子打分
 * - 使用“自然兜底”：当兴趣信号较弱时，会逐渐退化为按时间 + 热度排序
 */
@Service
public class RecommendationService {

    private static final int MAX_CANDIDATE_COUNT = 200;

    private final PostRepository postRepository;
    private final UserRepository userRepository;
    private final BrowseHistoryRepository browseHistoryRepository;
    private final FavoritePostRepository favoritePostRepository;

    public RecommendationService(PostRepository postRepository,
                                 UserRepository userRepository,
                                 BrowseHistoryRepository browseHistoryRepository,
                                 FavoritePostRepository favoritePostRepository) {
        this.postRepository = postRepository;
        this.userRepository = userRepository;
        this.browseHistoryRepository = browseHistoryRepository;
        this.favoritePostRepository = favoritePostRepository;
    }

    /**
     * 获取首页推荐帖子列表。
     *
     * @param userId   当前用户 ID（必须登录）
     * @param page     页码（从 1 开始）
     * @param pageSize 每页大小
     */
    @Transactional(readOnly = true)
    public Page<Post> getRecommendations(Long userId, int page, int pageSize) {
        if (userId == null) {
            return Page.empty();
        }

        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("用户不存在: " + userId));

        UserInterest interest = buildUserInterest(user);

        // 只对最近 200 条 NORMAL 状态的帖子打分
        Pageable candidatePageable = PageRequest.of(0, MAX_CANDIDATE_COUNT);
        Page<Post> recentPage = postRepository.findByStatusOrderByCreatedAtDesc(PostStatus.NORMAL, candidatePageable);
        List<Post> candidates = recentPage.getContent();
        if (candidates.isEmpty()) {
            return Page.empty();
        }

        // 计算时间和热度的归一化因子
        NormalizationContext norm = buildNormalizationContext(candidates);

        // 为每个候选帖子计算得分
        List<ScoredPost> scored = new ArrayList<>(candidates.size());
        for (Post post : candidates) {
            double score = computeScore(post, user, interest, norm);
            scored.add(new ScoredPost(post, score));
        }

        // 按分数从高到低排序
        scored.sort(Comparator.comparingDouble(ScoredPost::score).reversed());

        // 把排序结果转换为帖子列表
        List<Post> sortedPosts = scored.stream()
                .map(ScoredPost::post)
                .collect(Collectors.toList());

        // 做分页（内存分页即可）
        int fromIndex = Math.max(0, (page - 1) * pageSize);
        if (fromIndex >= sortedPosts.size()) {
            return new PageImpl<>(Collections.emptyList(), PageRequest.of(page - 1, pageSize), sortedPosts.size());
        }
        int toIndex = Math.min(sortedPosts.size(), fromIndex + pageSize);
        List<Post> pageContent = sortedPosts.subList(fromIndex, toIndex);

        return new PageImpl<>(pageContent, PageRequest.of(page - 1, pageSize), sortedPosts.size());
    }

    /**
     * 构建当前用户的兴趣画像。
     */
    private UserInterest buildUserInterest(User user) {
        UserInterest interest = new UserInterest();
        interest.setResearchDirections(splitResearchDirections(user.getResearchDirections()));

        // 浏览历史：取最近 50 条
        List<BrowseHistory> histories = browseHistoryRepository.findTop50ByUserOrderByViewedAtDesc(user);
        for (BrowseHistory history : histories) {
            Post post = history.getPost();
            if (post == null) continue;
            interest.getViewedPostIds().add(post.getId());
            // 二级标签：来自 post_tags 表的标签列表（不含主标签）
            UserInterest.addTagWeights(interest.getBrowseTagWeights(), extractSecondaryTags(post), 1.0);
        }

        // 收藏的帖子：取最近 200 条
        Pageable favPageable = PageRequest.of(0, 200);
        List<FavoritePost> favorites = favoritePostRepository.findByUserIdOrderByCreatedAtDesc(user.getId(), favPageable)
                .getContent();
        for (FavoritePost favorite : favorites) {
            Post post = favorite.getPost();
            if (post == null) continue;
            interest.getFavoritedPostIds().add(post.getId());
            // 收藏比普通浏览更能代表偏好，权重略高
            UserInterest.addTagWeights(interest.getFavoriteTagWeights(), extractSecondaryTags(post), 2.0);
        }

        // 自己发过的帖子：最多取最近 200 条 NORMAL 帖子
        Pageable ownPageable = PageRequest.of(0, 200);
        Page<Post> ownPostsPage = postRepository.findByAuthorIdAndStatusOrderByCreatedAtDesc(
                user.getId(), PostStatus.NORMAL, ownPageable);
        for (Post post : ownPostsPage.getContent()) {
            interest.getOwnPostIds().add(post.getId());
            UserInterest.addTagWeights(interest.getSelfPostTagWeights(), extractSecondaryTags(post), 1.5);
        }

        return interest;
    }

    private List<String> splitResearchDirections(String raw) {
        if (raw == null || raw.isBlank()) {
            return List.of();
        }
        return List.of(raw.split(","))
                .stream()
                .map(String::trim)
                .filter(s -> !s.isEmpty())
                .collect(Collectors.toList());
    }

    /**
     * 计算单个帖子的总得分。
     * 权重：研究方向 2 分、收藏兴趣 1 分、发帖兴趣 1 分、时间 1 分、热度 1 分、浏览历史 0.5 分。
     */
    private double computeScore(Post post, User user, UserInterest interest, NormalizationContext norm) {
        // 研究方向匹配（0~1）
        double researchScore = computeResearchScore(post, interest.getResearchDirections());

        // 标签兴趣分（0~1）
        double favoriteInterestScore = computeTagInterestScore(post, interest.getFavoriteTagWeights());
        double selfPostInterestScore = computeTagInterestScore(post, interest.getSelfPostTagWeights());
        double browseInterestScore = computeTagInterestScore(post, interest.getBrowseTagWeights());

        // 时间新鲜度（0~1）
        double timeScore = norm.normalizeTime(post.getCreatedAt());

        // 热度：基于 likes + comments + views 的归一化（0~1）
        double hotScore = norm.normalizeHot(post);

        // 对已经看过很多遍 / 自己发的帖子稍微降权，更多推荐“新内容”
        boolean viewed = interest.getViewedPostIds().contains(post.getId());
        boolean own = interest.getOwnPostIds().contains(post.getId());
        double repeatPenalty = 1.0;
        if (own) {
            repeatPenalty *= 0.7; // 自己的帖子不优先推荐
        } else if (viewed) {
            repeatPenalty *= 0.85; // 已浏览的稍微降一点
        }

        // 总分（线性组合）
        double score =
                2.0 * researchScore +
                1.0 * favoriteInterestScore +
                1.0 * selfPostInterestScore +
                0.5 * browseInterestScore +
                1.0 * timeScore +
                1.0 * hotScore;

        return score * repeatPenalty;
    }

    /**
     * 研究方向匹配：如果帖子的标签或标题中包含研究方向关键字则加分。
     */
    private double computeResearchScore(Post post, List<String> directions) {
        if (directions == null || directions.isEmpty()) {
            return 0.0;
        }
        String title = Optional.ofNullable(post.getTitle()).orElse("").toLowerCase(Locale.ROOT);
        // 主标签（一级分区）：存储在帖子表单的最后一个字段
        String mainTag = Optional.ofNullable(extractMainTag(post))
                .map(s -> s.toLowerCase(Locale.ROOT))
                .orElse(null);

        double matches = 0.0;
        for (String dirRaw : directions) {
            if (dirRaw == null || dirRaw.isBlank()) continue;
            String dir = dirRaw.toLowerCase(Locale.ROOT);
            boolean matched = title.contains(dir);
            if (!matched && mainTag != null) {
                matched = mainTag.contains(dir);
            }
            if (matched) {
                matches += 1.0;
            }
        }
        // 最多记为 1.0
        return Math.min(1.0, matches);
    }

    /**
     * 根据标签权重 map 计算当前帖子的兴趣重叠度（0~1）。
     */
    private double computeTagInterestScore(Post post, Map<String, Double> tagWeights) {
        if (tagWeights == null || tagWeights.isEmpty()) {
            return 0.0;
        }
        List<String> tags = post.getTags();
        if (tags == null || tags.isEmpty()) {
            return 0.0;
        }
        double sum = 0.0;
        for (String raw : tags) {
            if (raw == null) continue;
            String tag = raw.trim();
            if (tag.isEmpty()) continue;
            Double w = tagWeights.get(tag);
            if (w != null) {
                sum += w;
            }
        }
        // 简单归一化：假设 10 分以上就视为完全匹配
        return Math.max(0.0, Math.min(1.0, sum / 10.0));
    }

    /**
     * 时间和热度归一化所需的上下文。
     */
    private static class NormalizationContext {
        private final Instant minCreatedAt;
        private final Instant maxCreatedAt;
        private final double maxHotValue;

        NormalizationContext(Instant minCreatedAt, Instant maxCreatedAt, double maxHotValue) {
            this.minCreatedAt = minCreatedAt;
            this.maxCreatedAt = maxCreatedAt;
            this.maxHotValue = maxHotValue <= 0 ? 1.0 : maxHotValue;
        }

        double normalizeTime(Instant createdAt) {
            if (createdAt == null || minCreatedAt == null || maxCreatedAt == null) {
                return 0.0;
            }
            long totalMinutes = ChronoUnit.MINUTES.between(minCreatedAt, maxCreatedAt);
            if (totalMinutes <= 0) {
                return 1.0;
            }
            long diffMinutes = ChronoUnit.MINUTES.between(minCreatedAt, createdAt);
            double ratio = (double) diffMinutes / totalMinutes;
            return Math.max(0.0, Math.min(1.0, ratio));
        }

        double normalizeHot(Post post) {
            int likes = Optional.ofNullable(post.getLikesCount()).orElse(0);
            int comments = Optional.ofNullable(post.getCommentsCount()).orElse(0);
            int views = Optional.ofNullable(post.getViewsCount()).orElse(0);
            double raw = likes + comments + views / 10.0;
            if (raw <= 0) {
                return 0.0;
            }
            double ratio = raw / maxHotValue;
            return Math.max(0.0, Math.min(1.0, ratio));
        }
    }

    /**
     * 计算给定候选帖子列表的时间范围和最大热度。
     */
    private NormalizationContext buildNormalizationContext(List<Post> candidates) {
        Instant minCreated = null;
        Instant maxCreated = null;
        double maxHot = 0.0;

        for (Post p : candidates) {
            Instant created = p.getCreatedAt();
            if (created != null) {
                if (minCreated == null || created.isBefore(minCreated)) {
                    minCreated = created;
                }
                if (maxCreated == null || created.isAfter(maxCreated)) {
                    maxCreated = created;
                }
            }
            int likes = Optional.ofNullable(p.getLikesCount()).orElse(0);
            int comments = Optional.ofNullable(p.getCommentsCount()).orElse(0);
            int views = Optional.ofNullable(p.getViewsCount()).orElse(0);
            double hot = likes + comments + views / 10.0;
            if (hot > maxHot) {
                maxHot = hot;
            }
        }

        return new NormalizationContext(minCreated, maxCreated, maxHot);
    }

    /**
     * 从 Post.tags 中提取主标签（一级分区）。
     * 约定：当前版本中主标签存放在表单的最后一个字段，
     * 因此前端会将主标签作为 tags 列表的最后一个元素提交。
     */
    private String extractMainTag(Post post) {
        List<String> tags = post.getTags();
        if (tags == null || tags.isEmpty()) {
            return null;
        }
        String last = tags.get(tags.size() - 1);
        return (last != null && !last.trim().isEmpty()) ? last.trim() : null;
    }

    /**
     * 提取二级标签列表（post_tags 表中的普通标签），不包含主标签。
     * 约定：主标签为 tags 列表最后一个元素，其余元素视为二级标签。
     */
    private List<String> extractSecondaryTags(Post post) {
        List<String> tags = post.getTags();
        if (tags == null || tags.isEmpty()) {
            return List.of();
        }
        if (tags.size() == 1) {
            // 只有主标签，没有二级标签
            return List.of();
        }
        return tags.subList(0, tags.size() - 1);
    }

    private record ScoredPost(Post post, double score) {}
}


