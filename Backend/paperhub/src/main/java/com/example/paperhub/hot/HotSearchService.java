package com.example.paperhub.hot;

import com.example.paperhub.history.SearchHistory;
import com.example.paperhub.history.SearchHistoryRepository;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.stream.Collectors;

/**
 * 热搜服务：负责计算和更新热搜榜单
 *
 * 算法核心思想：
 * 1. 基于搜索历史数据，按(keyword, search_type)分组统计
 * 2. 热度分数 = 搜索次数 * 用户因子 * 时间衰减因子
 * 3. 考虑增长率（与上一周期比较）决定标签（新/热）
 *
 * 统计周期：默认24小时，每10分钟更新一次
 */
@Service
public class HotSearchService {

    // 配置参数
    private static final int DEFAULT_HOT_SEARCH_LIMIT = 20; // 默认返回热搜数量
    private static final int STATISTICS_PERIOD_HOURS = 24; // 统计周期（小时）
    private static final double USER_FACTOR_BASE = 2.0; // 用户因子基数
    private static final double GROWTH_THRESHOLD_HOT = 1.5; // 增长率超过150%标记为"热"
    private static final double GROWTH_THRESHOLD_NEW = 2.0; // 增长率超过200%标记为"新"（新上榜）
    private static final int MIN_SEARCH_COUNT = 1; // 最小搜索次数要求

    // 时间衰减权重配置
    private static final Map<String, Double> TIME_DECAY_WEIGHTS = Map.of(
            "1h", 1.0,   // 最近1小时
            "6h", 0.7,   // 1-6小时
            "24h", 0.4,  // 6-24小时
            "beyond", 0.1 // 24小时以上
    );

    private final HotSearchRepository hotSearchRepository;
    private final SearchHistoryRepository searchHistoryRepository;

    public HotSearchService(HotSearchRepository hotSearchRepository,
                           SearchHistoryRepository searchHistoryRepository) {
        this.hotSearchRepository = hotSearchRepository;
        this.searchHistoryRepository = searchHistoryRepository;
    }

    /**
     * 获取最新的热搜榜单
     * @param limit 返回数量，默认20
     * @return 热搜列表，按排名排序
     */
    public List<HotSearch> getLatestHotSearches(int limit) {
        if (limit <= 0) {
            limit = DEFAULT_HOT_SEARCH_LIMIT;
        }
        return hotSearchRepository.findLatestHotSearchesNative(limit);
    }

    /**
     * 计算并更新热搜榜单
     * 1. 从搜索历史中统计最近24小时的数据
     * 2. 计算每个关键词的热度分数
     * 3. 排序并生成排名
     * 4. 计算增长率并标记标签
     * 5. 保存到数据库
     */
    @Transactional
    public void calculateAndUpdateHotSearches() {
        Instant now = Instant.now();
        Instant periodStart = now.minus(STATISTICS_PERIOD_HOURS, ChronoUnit.HOURS);
        Instant periodEnd = now;

        // 1. 获取统计周期内的搜索历史
        List<SearchHistory> searchHistories = searchHistoryRepository
                .findByTimeRange(periodStart, periodEnd);

        if (searchHistories.isEmpty()) {
            return; // 没有搜索数据
        }

        // 2. 按keyword分组统计（合并不同搜索类型的相同关键词）
        Map<String, SearchStatistics> statisticsMap = new HashMap<>();

        for (SearchHistory history : searchHistories) {
            String key = history.getKeyword(); // 只按关键词分组
            SearchStatistics stats = statisticsMap.computeIfAbsent(key,
                    k -> new SearchStatistics(history.getKeyword()));

            stats.addSearch(history);
        }

        // 3. 计算热度分数并筛选
        List<SearchStatistics> allStats = statisticsMap.values().stream()
                .filter(stats -> stats.getTotalSearches() >= MIN_SEARCH_COUNT)
                .collect(Collectors.toList());

        // 计算热度分数
        allStats.forEach(stats -> {
            double heatScore = calculateHeatScore(stats, periodEnd);
            stats.setHeatScore(heatScore);
        });

        // 4. 按热度分数排序
        allStats.sort((a, b) -> Double.compare(b.getHeatScore(), a.getHeatScore()));

        // 5. 获取上一周期的数据用于计算增长率
        Map<String, HotSearch> previousHotSearches = getPreviousHotSearches();

        // 6. 生成HotSearch实体并计算标签
        List<HotSearch> hotSearches = new ArrayList<>();
        int rank = 1;
        for (SearchStatistics stats : allStats) {
            if (rank > DEFAULT_HOT_SEARCH_LIMIT) {
                break; // 只保留前N名
            }

            // 计算增长率
            double growthRate = calculateGrowthRate(stats, previousHotSearches);

            // 确定标签
            String tag = determineTag(stats, growthRate, previousHotSearches.containsKey(stats.getKey()));

            HotSearch hotSearch = new HotSearch(
                    stats.getKeyword(),
                    stats.getSearchType(),
                    stats.getHeatScore(),
                    rank,
                    stats.getTotalSearches(),
                    stats.getUniqueUsers(),
                    periodStart,
                    periodEnd
            );
            hotSearch.setGrowthRate(growthRate);
            hotSearch.setTag(tag);

            hotSearches.add(hotSearch);
            rank++;
        }

        // 7. 保存新数据前先清理旧数据（同一周期）
        hotSearchRepository.deleteByPeriodEnd(periodEnd);

        // 8. 保存新数据
        if (!hotSearches.isEmpty()) {
            hotSearchRepository.saveAll(hotSearches);
        }

        // 9. 清理过期数据（保留最近7天的数据）
        Instant cutoffTime = now.minus(7, ChronoUnit.DAYS);
        hotSearchRepository.deleteByPeriodEndBefore(cutoffTime);
    }

    /**
     * 计算单个统计项的热度分数
     * 公式：热度分数 = 搜索次数 * 用户因子 * 时间衰减因子
     */
    private double calculateHeatScore(SearchStatistics stats, Instant periodEnd) {
        // 1. 基础搜索次数
        long searchCount = stats.getTotalSearches();

        // 2. 用户因子：log10(独立用户数 + 1) * USER_FACTOR_BASE
        long uniqueUsers = stats.getUniqueUsers();
        double userFactor = Math.log10(uniqueUsers + 1) * USER_FACTOR_BASE;

        // 3. 时间衰减因子：加权平均
        double timeDecayFactor = calculateTimeDecayFactor(stats.getTimeDistribution(), periodEnd);

        // 4. 最终分数
        return searchCount * userFactor * timeDecayFactor;
    }

    /**
     * 计算时间衰减因子
     * 根据搜索时间分布加权计算
     */
    private double calculateTimeDecayFactor(Map<String, Long> timeDistribution, Instant periodEnd) {
        if (timeDistribution.isEmpty()) {
            return 0.0;
        }

        double weightedSum = 0.0;
        long totalSearches = 0;

        for (Map.Entry<String, Long> entry : timeDistribution.entrySet()) {
            String timeRange = entry.getKey();
            Long count = entry.getValue();
            Double weight = TIME_DECAY_WEIGHTS.get(timeRange);

            if (weight != null) {
                weightedSum += count * weight;
                totalSearches += count;
            }
        }

        return totalSearches > 0 ? weightedSum / totalSearches : 0.0;
    }

    /**
     * 获取上一周期的热搜数据
     * 注意：现在只按keyword匹配，忽略searchType
     */
    private Map<String, HotSearch> getPreviousHotSearches() {
        Map<String, HotSearch> previousMap = new HashMap<>();
        Instant latestPeriodEnd = hotSearchRepository.findLatestPeriodEnd();

        if (latestPeriodEnd != null) {
            // 获取上一周期的数据（当前周期前一个）
            Instant previousPeriodEnd = latestPeriodEnd.minus(10, ChronoUnit.MINUTES); // 假设每10分钟更新一次
            List<HotSearch> previous = hotSearchRepository.findByPeriodEnd(previousPeriodEnd, DEFAULT_HOT_SEARCH_LIMIT);

            for (HotSearch hs : previous) {
                String key = hs.getKeyword(); // 只按keyword匹配
                // 如果已有相同keyword的记录，保留heatScore较高的
                HotSearch existing = previousMap.get(key);
                if (existing == null || hs.getHeatScore() > existing.getHeatScore()) {
                    previousMap.put(key, hs);
                }
            }
        }

        return previousMap;
    }

    /**
     * 计算增长率
     * @return 当前周期与上一周期的热度分数增长率（如果上一周期不存在，返回2.0表示新上榜）
     */
    private double calculateGrowthRate(SearchStatistics stats, Map<String, HotSearch> previousHotSearches) {
        String key = stats.getKey();
        HotSearch previous = previousHotSearches.get(key);

        if (previous == null) {
            // 新上榜，给予较高的增长率
            return 2.0;
        }

        double previousHeat = previous.getHeatScore();
        double currentHeat = stats.getHeatScore();

        if (previousHeat <= 0) {
            return 2.0; // 避免除零
        }

        return currentHeat / previousHeat;
    }

    /**
     * 确定标签
     * @param isPreviousExisted 上一周期是否存在
     * @return "新"：新上榜且增长率高；"热"：持续热门；null：普通
     */
    private String determineTag(SearchStatistics stats, double growthRate, boolean isPreviousExisted) {
        if (!isPreviousExisted) {
            // 新上榜
            if (growthRate >= GROWTH_THRESHOLD_NEW) {
                return "新";
            }
        } else {
            // 持续上榜
            if (growthRate >= GROWTH_THRESHOLD_HOT) {
                return "热";
            }
        }

        return null;
    }

    /**
     * 内部类：用于统计搜索数据
     */
    private static class SearchStatistics {
        private final String keyword;
        private final Set<Long> userIds = new HashSet<>();
        private final Map<String, Long> timeDistribution = new HashMap<>(); // 时间分布：1h, 6h, 24h, beyond
        private long totalSearches = 0;
        private double heatScore = 0.0;

        public SearchStatistics(String keyword) {
            this.keyword = keyword;
        }

        public void addSearch(SearchHistory history) {
            // 用户统计
            userIds.add(history.getUser().getId());

            // 搜索次数
            totalSearches += history.getSearchCount();

            // 时间分布统计（根据updatedAt）
            Instant searchTime = history.getUpdatedAt();
            String timeRange = categorizeTimeRange(searchTime);
            timeDistribution.put(timeRange, timeDistribution.getOrDefault(timeRange, 0L) + history.getSearchCount());
        }

        private String categorizeTimeRange(Instant searchTime) {
            Instant now = Instant.now();
            long hoursDiff = ChronoUnit.HOURS.between(searchTime, now);

            if (hoursDiff <= 1) {
                return "1h";
            } else if (hoursDiff <= 6) {
                return "6h";
            } else if (hoursDiff <= 24) {
                return "24h";
            } else {
                return "beyond";
            }
        }

        public String getKey() {
            return keyword;
        }

        public String getKeyword() {
            return keyword;
        }

        public String getSearchType() {
            return "keyword"; // 固定值，因为热搜按关键词合并，不区分搜索类型
        }

        public long getTotalSearches() {
            return totalSearches;
        }

        public long getUniqueUsers() {
            return userIds.size();
        }

        public Map<String, Long> getTimeDistribution() {
            return timeDistribution;
        }

        public double getHeatScore() {
            return heatScore;
        }

        public void setHeatScore(double heatScore) {
            this.heatScore = heatScore;
        }
    }

    /**
     * 定时任务：每10分钟执行一次热搜计算
     * 使用cron表达式：0 *除以10 * * * *
     */
    @Scheduled(cron = "0 */10 * * * *")
    @Transactional
    public void scheduledHotSearchCalculation() {
        try {
            calculateAndUpdateHotSearches();
        } catch (Exception e) {
            // 记录错误，但不要抛出异常，以免影响其他定时任务
            System.err.println("热搜计算定时任务执行失败: " + e.getMessage());
            e.printStackTrace();
        }
    }
}