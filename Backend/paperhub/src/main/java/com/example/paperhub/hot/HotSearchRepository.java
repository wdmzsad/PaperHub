package com.example.paperhub.hot;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;

@Repository
public interface HotSearchRepository extends JpaRepository<HotSearch, Long> {

    /**
     * 获取最新的热搜榜单（按排名排序）
     * @param limit 返回数量限制
     * @return 热搜列表，按排名升序
     */
    @Query("SELECT h FROM HotSearch h WHERE h.periodEnd = (SELECT MAX(h2.periodEnd) FROM HotSearch h2) ORDER BY h.rank ASC")
    List<HotSearch> findLatestHotSearches(int limit);

    /**
     * 获取指定时间段内的热搜榜单
     * @param periodEnd 统计周期结束时间
     * @param limit 返回数量限制
     * @return 热搜列表，按排名升序
     */
    @Query("SELECT h FROM HotSearch h WHERE h.periodEnd = :periodEnd ORDER BY h.rank ASC")
    List<HotSearch> findByPeriodEnd(@Param("periodEnd") Instant periodEnd, int limit);

    /**
     * 获取最新的热搜榜单（按排名排序），限制数量
     */
    @Query(value = "SELECT * FROM hot_search h WHERE h.period_end = (SELECT MAX(period_end) FROM hot_search) ORDER BY h.rank_position ASC LIMIT :limit", nativeQuery = true)
    List<HotSearch> findLatestHotSearchesNative(@Param("limit") int limit);

    /**
     * 删除指定周期之前的所有热搜记录（清理旧数据）
     */
    @Modifying
    @Query("DELETE FROM HotSearch h WHERE h.periodEnd < :cutoffTime")
    int deleteByPeriodEndBefore(@Param("cutoffTime") Instant cutoffTime);

    /**
     * 删除指定周期的热搜记录
     */
    @Modifying
    @Query("DELETE FROM HotSearch h WHERE h.periodEnd = :periodEnd")
    int deleteByPeriodEnd(@Param("periodEnd") Instant periodEnd);

    /**
     * 获取最新的统计周期结束时间
     */
    @Query("SELECT MAX(h.periodEnd) FROM HotSearch h")
    Instant findLatestPeriodEnd();

    /**
     * 检查指定关键词和搜索类型在最新周期中是否存在
     */
    @Query("SELECT COUNT(h) > 0 FROM HotSearch h WHERE h.keyword = :keyword AND h.searchType = :searchType AND h.periodEnd = (SELECT MAX(h2.periodEnd) FROM HotSearch h2)")
    boolean existsInLatestPeriod(@Param("keyword") String keyword, @Param("searchType") String searchType);

    /**
     * 获取指定关键词的历史热搜排名（用于计算增长率）
     */
    @Query("SELECT h FROM HotSearch h WHERE h.keyword = :keyword AND h.searchType = :searchType ORDER BY h.periodEnd DESC")
    List<HotSearch> findHistoricalByKeywordAndType(@Param("keyword") String keyword, @Param("searchType") String searchType, org.springframework.data.domain.Pageable pageable);
}