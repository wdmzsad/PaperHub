package com.example.paperhub.hot;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 热搜榜单API控制器
 *
 * 提供热搜榜单的查询接口，支持：
 * 1. 获取最新热搜榜单
 * 2. 获取热搜详情（历史趋势）
 * 3. 手动触发热搜计算（管理员功能）
 */
@RestController
@RequestMapping("/hot-searches")
public class HotSearchController {

    private final HotSearchService hotSearchService;

    public HotSearchController(HotSearchService hotSearchService) {
        this.hotSearchService = hotSearchService;
    }

    /**
     * GET /hot-searches
     * 获取最新的热搜榜单
     *
     * 查询参数：
     * - limit: 返回数量，默认20，最大50
     * - type: 搜索类型筛选（可选，keyword/tag/author）
     *
     * 响应格式：
     * {
     *   "items": [
     *     {
     *       "rank": 1,
     *       "keyword": "深度学习",
     *       "searchType": "keyword",
     *       "heat": 125.6,
     *       "tag": "热",
     *       "searchCount": 150,
     *       "uniqueUsers": 45,
     *       "growthRate": 1.8
     *     },
     *     ...
     *   ],
     *   "count": 20,
     *   "periodEnd": "2025-01-01T12:00:00Z",
     *   "timestamp": "2025-01-01T12:05:00Z"
     * }
     */
    @GetMapping
    public ResponseEntity<Map<String, Object>> getHotSearches(
            @RequestParam(name = "limit", required = false, defaultValue = "20") int limit,
            @RequestParam(name = "type", required = false) String searchType) {

        // 参数验证
        if (limit <= 0) {
            limit = 20;
        }
        if (limit > 50) {
            limit = 50; // 限制最大返回数量
        }

        // 获取热搜数据
        List<HotSearch> hotSearches = hotSearchService.getLatestHotSearches(limit);

        // 按搜索类型筛选
        if (searchType != null && !searchType.trim().isEmpty()) {
            String finalSearchType = searchType.trim();
            hotSearches = hotSearches.stream()
                    .filter(hs -> finalSearchType.equals(hs.getSearchType()))
                    .toList();
        }

        // 转换为响应格式
        List<Map<String, Object>> items = hotSearches.stream().map(hs -> {
            Map<String, Object> item = new HashMap<>();
            item.put("rank", hs.getRank());
            item.put("keyword", hs.getKeyword());
            item.put("searchType", hs.getSearchType());
            item.put("heat", hs.getHeatScore());
            item.put("tag", hs.getTag());
            item.put("searchCount", hs.getSearchCount());
            item.put("uniqueUsers", hs.getUniqueUsers());
            item.put("growthRate", hs.getGrowthRate());
            item.put("periodStart", hs.getPeriodStart().toString());
            item.put("periodEnd", hs.getPeriodEnd().toString());
            return item;
        }).toList();

        // 构建响应体
        Map<String, Object> response = new HashMap<>();
        response.put("items", items);
        response.put("count", items.size());
        if (!hotSearches.isEmpty()) {
            response.put("periodEnd", hotSearches.get(0).getPeriodEnd().toString());
        } else {
            response.put("periodEnd", Instant.now().toString());
        }
        response.put("timestamp", Instant.now().toString());

        return ResponseEntity.ok(response);
    }

    /**
     * GET /hot-searches/{keyword}
     * 获取指定关键词的热搜详情（历史趋势）
     *
     * 查询参数：
     * - searchType: 搜索类型（可选，默认keyword）
     * - limit: 返回历史记录数量（可选，默认10）
     *
     * 响应格式：
     * {
     *   "keyword": "深度学习",
     *   "searchType": "keyword",
     *   "history": [
     *     {
     *       "periodEnd": "2025-01-01T12:00:00Z",
     *       "rank": 1,
     *       "heat": 125.6,
     *       "searchCount": 150,
     *       "uniqueUsers": 45,
     *       "growthRate": 1.8
     *     },
     *     ...
     *   ],
     *   "currentRank": 1,
     *   "currentHeat": 125.6,
     *   "timestamp": "2025-01-01T12:05:00Z"
     * }
     */
    @GetMapping("/{keyword}")
    public ResponseEntity<Map<String, Object>> getHotSearchDetail(
            @PathVariable String keyword,
            @RequestParam(name = "searchType", required = false, defaultValue = "keyword") String searchType,
            @RequestParam(name = "limit", required = false, defaultValue = "10") int limit) {

        // TODO: 实现历史趋势查询
        // 需要添加新的Repository方法查询指定关键词的历史排名

        Map<String, Object> response = new HashMap<>();
        response.put("keyword", keyword);
        response.put("searchType", searchType);
        response.put("message", "历史趋势功能待实现");
        response.put("timestamp", Instant.now().toString());

        return ResponseEntity.ok(response);
    }

    /**
     * POST /hot-searches/calculate
     * 手动触发热搜计算（管理员功能）
     *
     * 请求体：
     * {
     *   "force": true  // 是否强制重新计算（忽略缓存）
     * }
     *
     * 响应格式：
     * {
     *   "message": "热搜计算完成",
     *   "timestamp": "2025-01-01T12:05:00Z",
     *   "details": {
     *     "processedItems": 45,
     *     "generatedRankings": 20,
     *     "periodEnd": "2025-01-01T12:00:00Z"
     *   }
     * }
     */
    @PostMapping("/calculate")
    public ResponseEntity<Map<String, Object>> calculateHotSearches(
            @RequestBody(required = false) Map<String, Object> requestBody) {

        boolean force = false;
        if (requestBody != null && requestBody.containsKey("force")) {
            Object forceObj = requestBody.get("force");
            if (forceObj instanceof Boolean) {
                force = (Boolean) forceObj;
            } else if (forceObj instanceof String) {
                force = Boolean.parseBoolean((String) forceObj);
            }
        }

        try {
            // 执行热搜计算
            hotSearchService.calculateAndUpdateHotSearches();

            Map<String, Object> response = new HashMap<>();
            response.put("message", "热搜计算完成");
            response.put("timestamp", Instant.now().toString());
            response.put("force", force);

            // TODO: 添加更详细的统计信息

            return ResponseEntity.ok(response);
        } catch (Exception e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("message", "热搜计算失败: " + e.getMessage());
            errorResponse.put("timestamp", Instant.now().toString());
            return ResponseEntity.status(500).body(errorResponse);
        }
    }

    /**
     * GET /hot-searches/stats
     * 获取热搜统计信息（管理员功能）
     *
     * 响应格式：
     * {
     *   "latestPeriodEnd": "2025-01-01T12:00:00Z",
     *   "totalRankings": 150,
     *   "coverageHours": 168,
     *   "lastCalculationTime": "2025-01-01T12:05:00Z",
     *   "timestamp": "2025-01-01T12:06:00Z"
     * }
     */
    @GetMapping("/stats")
    public ResponseEntity<Map<String, Object>> getHotSearchStats() {
        // TODO: 实现统计信息查询

        Map<String, Object> response = new HashMap<>();
        response.put("message", "统计功能待实现");
        response.put("timestamp", Instant.now().toString());

        return ResponseEntity.ok(response);
    }
}