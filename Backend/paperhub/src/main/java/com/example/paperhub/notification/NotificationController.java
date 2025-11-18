package com.example.paperhub.notification;

import com.example.paperhub.auth.User;
import com.example.paperhub.notification.dto.NotificationDtos;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/notifications")
public class NotificationController {
    private final NotificationService notificationService;

    public NotificationController(NotificationService notificationService) {
        this.notificationService = notificationService;
    }

    /**
     * 获取未读通知数量
     * GET /notifications/unread-count
     */
    @GetMapping("/unread-count")
    public ResponseEntity<NotificationDtos.UnreadCountResp> getUnreadCount(
            @AuthenticationPrincipal User user) {
        if (user == null) {
            return ResponseEntity.status(401).build();
        }

        Map<String, Long> counts = notificationService.getUnreadCounts(user);
        NotificationDtos.UnreadCountResp resp = new NotificationDtos.UnreadCountResp(
                counts.getOrDefault("likes", 0L),
                counts.getOrDefault("follows", 0L),
                counts.getOrDefault("comments", 0L)
        );
        return ResponseEntity.ok(resp);
    }

    /**
     * 获取赞和收藏通知
     * GET /notifications/likes?page=0&pageSize=20
     */
    @GetMapping("/likes")
    public ResponseEntity<NotificationDtos.NotificationListResp> getLikesAndFavorites(
            @AuthenticationPrincipal User user,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int pageSize) {
        if (user == null) {
            return ResponseEntity.status(401).build();
        }

        Pageable pageable = PageRequest.of(page, pageSize);
        var notificationPage = notificationService.getLikesAndFavorites(user, pageable);
        
        var notifications = notificationPage.getContent().stream()
                .map(NotificationDtos.NotificationResp::from)
                .toList();

        NotificationDtos.NotificationListResp resp = new NotificationDtos.NotificationListResp(
                notifications,
                notificationPage.getTotalElements(),
                page,
                pageSize
        );
        return ResponseEntity.ok(resp);
    }

    /**
     * 获取关注通知
     * GET /notifications/follows?page=0&pageSize=20
     */
    @GetMapping("/follows")
    public ResponseEntity<NotificationDtos.NotificationListResp> getFollows(
            @AuthenticationPrincipal User user,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int pageSize) {
        if (user == null) {
            return ResponseEntity.status(401).build();
        }

        Pageable pageable = PageRequest.of(page, pageSize);
        var notificationPage = notificationService.getFollows(user, pageable);
        
        var notifications = notificationPage.getContent().stream()
                .map(NotificationDtos.NotificationResp::from)
                .toList();

        NotificationDtos.NotificationListResp resp = new NotificationDtos.NotificationListResp(
                notifications,
                notificationPage.getTotalElements(),
                page,
                pageSize
        );
        return ResponseEntity.ok(resp);
    }

    /**
     * 获取评论和@通知
     * GET /notifications/comments?page=0&pageSize=20
     */
    @GetMapping("/comments")
    public ResponseEntity<NotificationDtos.NotificationListResp> getCommentsAndMentions(
            @AuthenticationPrincipal User user,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int pageSize) {
        if (user == null) {
            return ResponseEntity.status(401).build();
        }

        Pageable pageable = PageRequest.of(page, pageSize);
        var notificationPage = notificationService.getCommentsAndMentions(user, pageable);
        
        var notifications = notificationPage.getContent().stream()
                .map(NotificationDtos.NotificationResp::from)
                .toList();

        NotificationDtos.NotificationListResp resp = new NotificationDtos.NotificationListResp(
                notifications,
                notificationPage.getTotalElements(),
                page,
                pageSize
        );
        return ResponseEntity.ok(resp);
    }

    /**
     * 标记通知为已读
     * PUT /notifications/{id}/read
     */
    @PutMapping("/{id}/read")
    public ResponseEntity<Map<String, String>> markAsRead(
            @PathVariable Long id,
            @AuthenticationPrincipal User user) {
        if (user == null) {
            return ResponseEntity.status(401).build();
        }

        try {
            notificationService.markAsRead(id, user);
            return ResponseEntity.ok(Map.of("message", "已标记为已读"));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(404).body(Map.of("message", e.getMessage()));
        }
    }

    /**
     * 批量标记指定类型的所有未读通知为已读
     * PUT /notifications/mark-all-read?types=POST_LIKE,POST_FAVORITE
     */
    @PutMapping("/mark-all-read")
    public ResponseEntity<Map<String, String>> markAllAsReadByTypes(
            @RequestParam List<String> types,
            @AuthenticationPrincipal User user) {
        if (user == null) {
            return ResponseEntity.status(401).build();
        }

        try {
            List<NotificationType> notificationTypes = types.stream()
                    .map(String::toUpperCase)
                    .map(NotificationType::valueOf)
                    .toList();
            notificationService.markAllAsReadByTypes(user, notificationTypes);
            return ResponseEntity.ok(Map.of("message", "已标记为已读"));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(400).body(Map.of("message", "无效的通知类型"));
        }
    }
}

