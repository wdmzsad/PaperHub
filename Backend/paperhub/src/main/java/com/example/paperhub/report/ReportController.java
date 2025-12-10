package com.example.paperhub.report;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;
import org.springframework.security.core.annotation.AuthenticationPrincipal;

import java.util.Map;

@RestController
@RequestMapping("/report")
public class ReportController {
    @PostMapping("/user/{userId}")
    public ResponseEntity<?> reportUser(@PathVariable Long userId,
                                        @RequestBody Map<String, String> body,
                                        @AuthenticationPrincipal UserDetails reporter) {
        String reason = body.get("reason");
        // TODO: 调用 service 层处理举报逻辑
        // 返回成功/失败
        return ResponseEntity.ok(Map.of("message", "举报成功"));
    }
}