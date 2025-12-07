package com.example.paperhub.history;

import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserRepository;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;

@Service
public class SearchHistoryService {

    /**
     * 最大保存搜索历史数量（用于推荐算法）
     * 设置为较大值以保留足够数据用于推荐
     */
    private static final int MAX_HISTORY_COUNT = 1000;

    /**
     * 前端默认显示数量
     */
    private static final int DEFAULT_DISPLAY_LIMIT = 20;

    private final SearchHistoryRepository searchHistoryRepository;
    private final UserRepository userRepository;

    public SearchHistoryService(SearchHistoryRepository searchHistoryRepository,
                                UserRepository userRepository) {
        this.searchHistoryRepository = searchHistoryRepository;
        this.userRepository = userRepository;
    }

    /**
     * 记录一次搜索：
     * - 如果已有 (user, keyword, searchType) 记录，更新 updatedAt 和搜索次数
     * - 否则新建一条记录
     * - 保证每个用户最多保留 MAX_HISTORY_COUNT 条最新记录
     */
    @Transactional
    public void recordSearch(Long userId, String keyword, String searchType) {
        if (keyword == null || keyword.trim().isEmpty()) {
            return;
        }

        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("User not found: " + userId));

        String trimmedKeyword = keyword.trim();

        SearchHistory history = searchHistoryRepository
                .findByUserAndKeywordAndSearchType(user, trimmedKeyword, searchType)
                .orElseGet(() -> {
                    SearchHistory h = new SearchHistory();
                    h.setUser(user);
                    h.setKeyword(trimmedKeyword);
                    h.setSearchType(searchType);
                    h.setCreatedAt(Instant.now());
                    return h;
                });

        history.setSearchCount(history.getSearchCount() + 1);
        history.setUpdatedAt(Instant.now());

        searchHistoryRepository.save(history);

        // 清理超出限制的旧记录
        cleanupOldHistory(userId);
    }

    /**
     * 获取用户的搜索历史，按时间倒序排列
     * @param limit 限制返回数量，为0或不传时使用默认值
     */
    public List<SearchHistory> getHistory(Long userId, Integer limit) {
        int actualLimit = (limit != null && limit > 0) ? limit : DEFAULT_DISPLAY_LIMIT;
        Pageable pageable = PageRequest.of(0, actualLimit);
        return searchHistoryRepository.findByUserIdWithLimit(userId, pageable);
    }

    /**
     * 获取用户的搜索历史数量
     */
    public long getHistoryCount(Long userId) {
        return searchHistoryRepository.countByUserId(userId);
    }

    /**
     * 获取用户最近搜索的关键词（用于推荐算法）
     * @param limit 限制返回数量
     */
    public List<String> getRecentKeywords(Long userId, int limit) {
        Pageable pageable = PageRequest.of(0, limit);
        return searchHistoryRepository.findRecentKeywordsByUserId(userId, pageable);
    }

    /**
     * 删除单条搜索历史
     */
    @Transactional
    public void deleteOne(Long userId, Long historyId) {
        int deleted = searchHistoryRepository.deleteByIdAndUserId(historyId, userId);
        if (deleted == 0) {
            throw new IllegalArgumentException("Search history not found or not owned by user");
        }
    }

    /**
     * 清空用户的所有搜索历史
     */
    @Transactional
    public void clearAll(Long userId) {
        searchHistoryRepository.deleteAllByUserId(userId);
    }

    /**
     * 清理超出限制的旧历史记录
     */
    @Transactional
    public void cleanupOldHistory(Long userId) {
        long count = searchHistoryRepository.countByUserId(userId);
        if (count <= MAX_HISTORY_COUNT) {
            return;
        }

        // 获取所有记录，按时间排序，跳过前 MAX_HISTORY_COUNT 条
        List<SearchHistory> allHistory = searchHistoryRepository.findByUserIdOrderByUpdatedAtDesc(userId);
        if (allHistory.size() > MAX_HISTORY_COUNT) {
            List<SearchHistory> toDelete = allHistory.subList(MAX_HISTORY_COUNT, allHistory.size());
            searchHistoryRepository.deleteAll(toDelete);
        }
    }

    /**
     * 获取用户某时间段内的搜索历史（用于分析）
     */
    public List<SearchHistory> getHistoryByTimeRange(Long userId, Instant start, Instant end) {
        return searchHistoryRepository.findByUserIdAndTimeRange(userId, start, end);
    }
}