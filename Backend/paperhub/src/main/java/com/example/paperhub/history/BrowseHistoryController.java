package com.example.paperhub.history;

import com.example.paperhub.auth.User;
import com.example.paperhub.post.Post;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/browse-history")
public class BrowseHistoryController {

    private final BrowseHistoryService browseHistoryService;

    public BrowseHistoryController(BrowseHistoryService browseHistoryService) {
        this.browseHistoryService = browseHistoryService;
    }

    /**
     * GET /browse-history?limit=50
     * 返回当前用户最近浏览的帖子列表。
     */
    @GetMapping
    public ResponseEntity<Map<String, Object>> list(
            @AuthenticationPrincipal User currentUser,
            @RequestParam(name = "limit", defaultValue = "50") int limit
    ) {
        if (currentUser == null) {
            // 页面刷新时容忍匿名状态，返回空历史
            Map<String, Object> body = new HashMap<>();
            body.put("items", List.of());
            body.put("count", 0);
            body.put("timestamp", Instant.now().toString());
            return ResponseEntity.ok(body);
        }
        Long userId = currentUser.getId();
        List<BrowseHistory> history = browseHistoryService.getHistory(userId, limit);

        var items = history.stream().map(h -> {
            Map<String, Object> m = new HashMap<>();
            Post p = h.getPost();
            m.put("postId", p.getId());
            m.put("title", h.getPostTitle());
            m.put("viewedAt", h.getViewedAt().toString());
            return m;
        }).toList();

        Map<String, Object> body = new HashMap<>();
        body.put("items", items);
        body.put("count", items.size());
        body.put("timestamp", Instant.now().toString());
        return ResponseEntity.ok(body);
    }

    /**
     * POST /browse-history
     * body: { "postId": 123, "title": "..." }
     * 一般前端不需要单独调这个接口，因为你已经在详情页里记录，
     * 但保留一个显式的记录接口也无妨。
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
        Object postIdRaw = payload.get("postId");
        if (postIdRaw == null) {
            return ResponseEntity.badRequest().body(Map.of("message", "postId 不能为空"));
        }
        Long postId = postIdRaw instanceof Number
                ? ((Number) postIdRaw).longValue()
                : Long.parseLong(postIdRaw.toString());
        String title = payload.getOrDefault("title", "").toString();
        browseHistoryService.recordHistory(userId, postId, title);
        return ResponseEntity.ok(Map.of("message", "ok"));
    }

    /**
     * DELETE /browse-history/{postId}
     * 删除当前用户针对某一帖子的浏览记录。
     */
    @DeleteMapping("/{postId}")
    public ResponseEntity<?> deleteOne(
            @AuthenticationPrincipal User currentUser,
            @PathVariable("postId") Long postId
    ) {
        if (currentUser == null) {
            return ResponseEntity.status(401).body(Map.of("message", "未认证，请先登录"));
        }
        Long userId = currentUser.getId();
        browseHistoryService.deleteOne(userId, postId);
        return ResponseEntity.noContent().build();
    }

    /**
     * DELETE /browse-history
     * 清空当前用户的所有浏览历史。
     */
    @DeleteMapping
    public ResponseEntity<?> clearAll(
            @AuthenticationPrincipal User currentUser
    ) {
        if (currentUser == null) {
            return ResponseEntity.status(401).body(Map.of("message", "未认证，请先登录"));
        }
        Long userId = currentUser.getId();
        browseHistoryService.clearAll(userId);
        return ResponseEntity.noContent().build();
    }
}



