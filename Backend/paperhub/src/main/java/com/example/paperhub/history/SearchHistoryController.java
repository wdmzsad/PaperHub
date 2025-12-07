package com.example.paperhub.history;

import com.example.paperhub.auth.User;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/search-history")
public class SearchHistoryController {

    private final SearchHistoryService searchHistoryService;

    public SearchHistoryController(SearchHistoryService searchHistoryService) {
        this.searchHistoryService = searchHistoryService;
    }

    /**
     * GET /search-history?limit=20
     * 返回当前用户最近的搜索历史列表。
     */
    @GetMapping
    public ResponseEntity<Map<String, Object>> list(
            @AuthenticationPrincipal User currentUser,
            @RequestParam(name = "limit", required = false) Integer limit
    ) {
        if (currentUser == null) {
            return ResponseEntity.status(401).body(Map.of("message", "未认证，请先登录"));
        }

        Long userId = currentUser.getId();
        List<SearchHistory> history = searchHistoryService.getHistory(userId, limit);

        var items = history.stream().map(h -> {
            Map<String, Object> m = new HashMap<>();
            m.put("id", h.getId());
            m.put("keyword", h.getKeyword());
            m.put("searchType", h.getSearchType());
            m.put("searchCount", h.getSearchCount());
            m.put("createdAt", h.getCreatedAt().toString());
            m.put("updatedAt", h.getUpdatedAt().toString());
            return m;
        }).toList();

        Map<String, Object> body = new HashMap<>();
        body.put("items", items);
        body.put("count", items.size());
        body.put("total", searchHistoryService.getHistoryCount(userId));
        body.put("timestamp", Instant.now().toString());

        return ResponseEntity.ok(body);
    }

    /**
     * POST /search-history
     * body: { "keyword": "深度学习", "searchType": "keyword" }
     * 记录一次搜索历史
     */
    @PostMapping
    public ResponseEntity<?> record(
            @AuthenticationPrincipal User currentUser,
            @RequestBody Map<String, Object> payload
    ) {
        if (currentUser == null) {
            return ResponseEntity.status(401).body(Map.of("message", "未认证，请先登录"));
        }

        Long userId = currentUser.getId();
        Object keywordRaw = payload.get("keyword");
        Object searchTypeRaw = payload.get("searchType");

        if (keywordRaw == null || keywordRaw.toString().trim().isEmpty()) {
            return ResponseEntity.badRequest().body(Map.of("message", "keyword 不能为空"));
        }

        String keyword = keywordRaw.toString();
        String searchType = searchTypeRaw != null ? searchTypeRaw.toString() : "keyword";

        // 验证 searchType 是否合法
        if (!isValidSearchType(searchType)) {
            return ResponseEntity.badRequest().body(Map.of("message", "searchType 必须为 'keyword', 'tag' 或 'author'"));
        }

        try {
            searchHistoryService.recordSearch(userId, keyword, searchType);
            return ResponseEntity.ok(Map.of("message", "ok"));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    /**
     * DELETE /search-history/{id}
     * 删除当前用户的一条搜索历史。
     */
    @DeleteMapping("/{id}")
    public ResponseEntity<?> deleteOne(
            @AuthenticationPrincipal User currentUser,
            @PathVariable("id") Long id
    ) {
        if (currentUser == null) {
            return ResponseEntity.status(401).body(Map.of("message", "未认证，请先登录"));
        }

        Long userId = currentUser.getId();

        try {
            searchHistoryService.deleteOne(userId, id);
            return ResponseEntity.noContent().build();
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(404).body(Map.of("message", e.getMessage()));
        }
    }

    /**
     * DELETE /search-history
     * 清空当前用户的所有搜索历史。
     */
    @DeleteMapping
    public ResponseEntity<?> clearAll(
            @AuthenticationPrincipal User currentUser
    ) {
        if (currentUser == null) {
            return ResponseEntity.status(401).body(Map.of("message", "未认证，请先登录"));
        }

        Long userId = currentUser.getId();
        searchHistoryService.clearAll(userId);
        return ResponseEntity.noContent().build();
    }

    /**
     * GET /search-history/recent-keywords?limit=50
     * 获取用户最近搜索的关键词（用于推荐算法）
     */
    @GetMapping("/recent-keywords")
    public ResponseEntity<Map<String, Object>> getRecentKeywords(
            @AuthenticationPrincipal User currentUser,
            @RequestParam(name = "limit", defaultValue = "50") int limit
    ) {
        if (currentUser == null) {
            return ResponseEntity.status(401).body(Map.of("message", "未认证，请先登录"));
        }

        Long userId = currentUser.getId();
        List<String> keywords = searchHistoryService.getRecentKeywords(userId, limit);

        Map<String, Object> body = new HashMap<>();
        body.put("keywords", keywords);
        body.put("count", keywords.size());
        body.put("timestamp", Instant.now().toString());

        return ResponseEntity.ok(body);
    }

    /**
     * 验证搜索类型是否合法
     */
    private boolean isValidSearchType(String searchType) {
        return "keyword".equals(searchType) || "tag".equals(searchType) || "author".equals(searchType);
    }
}