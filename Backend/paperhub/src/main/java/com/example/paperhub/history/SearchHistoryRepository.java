package com.example.paperhub.history;

import com.example.paperhub.auth.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

@Repository
public interface SearchHistoryRepository extends JpaRepository<SearchHistory, Long> {

    /**
     * 根据用户、关键词和搜索类型查找搜索历史
     */
    Optional<SearchHistory> findByUserAndKeywordAndSearchType(User user, String keyword, String searchType);

    /**
     * 根据用户ID获取搜索历史，按时间倒序排列
     */
    List<SearchHistory> findByUserIdOrderByUpdatedAtDesc(Long userId);

    /**
     * 根据用户ID获取搜索历史，按时间倒序排列，限制数量
     */
    @Query("SELECT h FROM SearchHistory h WHERE h.user.id = :userId ORDER BY h.updatedAt DESC")
    List<SearchHistory> findByUserIdWithLimit(@Param("userId") Long userId, org.springframework.data.domain.Pageable pageable);

    /**
     * 根据用户ID删除所有搜索历史
     */
    @Modifying
    @Query("DELETE FROM SearchHistory h WHERE h.user.id = :userId")
    int deleteAllByUserId(@Param("userId") Long userId);

    /**
     * 根据用户ID和搜索历史ID删除单条记录
     */
    @Modifying
    @Query("DELETE FROM SearchHistory h WHERE h.id = :id AND h.user.id = :userId")
    int deleteByIdAndUserId(@Param("id") Long id, @Param("userId") Long userId);

    /**
     * 根据用户ID统计搜索历史数量
     */
    @Query("SELECT COUNT(h) FROM SearchHistory h WHERE h.user.id = :userId")
    long countByUserId(@Param("userId") Long userId);

    /**
     * 获取用户最近搜索的关键词（用于推荐算法）
     */
    @Query("""
        SELECT h.keyword
        FROM SearchHistory h
        WHERE h.user.id = :userId
        GROUP BY h.keyword
        ORDER BY MAX(h.updatedAt) DESC
        """)
    List<String> findRecentKeywordsByUserId(@Param("userId") Long userId, org.springframework.data.domain.Pageable pageable);

    /**
     * 获取用户某时间段内的搜索历史（用于分析）
     */
    @Query("SELECT h FROM SearchHistory h WHERE h.user.id = :userId AND h.updatedAt BETWEEN :start AND :end ORDER BY h.updatedAt DESC")
    List<SearchHistory> findByUserIdAndTimeRange(@Param("userId") Long userId,
                                                 @Param("start") Instant start,
                                                 @Param("end") Instant end);

    /**
     * 获取所有用户在某时间段内的搜索历史（用于热搜统计）
     */
    @Query("SELECT h FROM SearchHistory h WHERE h.updatedAt BETWEEN :start AND :end ORDER BY h.updatedAt DESC")
    List<SearchHistory> findByTimeRange(@Param("start") Instant start,
                                        @Param("end") Instant end);
}