package com.example.paperhub.chat;

import com.example.paperhub.auth.User;
import com.example.paperhub.config.ObsConfig;
import com.obs.services.ObsClient;
import com.obs.services.exception.ObsException;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/upload")
public class ChatFileController {

    @Autowired
    private ObsClient obsClient;

    @Autowired
    private ObsConfig obsConfig;

    /**
     * 上传聊天文件
     */
    @PostMapping("/chat-file")
    public ResponseEntity<?> uploadChatFile(
            @AuthenticationPrincipal User currentUser,
            @RequestParam("file") MultipartFile file) {

        if (currentUser == null) {
            return ResponseEntity.status(401).body(Map.of("message", "未认证，请先登录"));
        }

        if (file == null || file.isEmpty()) {
            return ResponseEntity.badRequest().body(Map.of("message", "文件不能为空"));
        }

        // 验证文件类型和大小
        String originalName = file.getOriginalFilename();
        String extension = StringUtils.hasText(originalName) && originalName.contains(".")
                ? originalName.substring(originalName.lastIndexOf('.'))
                : "";

        // 检查文件大小 (限制为 50MB)
        if (file.getSize() > 50 * 1024 * 1024) {
            return ResponseEntity.badRequest().body(Map.of("message", "文件大小不能超过50MB"));
        }

        // 检查文件类型
        if (!isAllowedFileType(extension)) {
            return ResponseEntity.badRequest().body(Map.of("message", "不支持的文件类型"));
        }

        String objectKey = "chat-files/" + UUID.randomUUID() + extension;
        String url = "https://" + obsConfig.getBucketName() + ".obs.cn-north-4.myhuaweicloud.com/" + objectKey;

        try {
            obsClient.putObject(obsConfig.getBucketName(), objectKey, file.getInputStream());
            return ResponseEntity.ok(Map.of(
                "url", url,
                "fileName", originalName,
                "fileSize", file.getSize(),
                "message", "文件上传成功"
            ));
        } catch (ObsException e) {
            return ResponseEntity.status(500).body(Map.of(
                "message", "文件上传失败: " + e.getErrorMessage(),
                "code", e.getErrorCode()
            ));
        } catch (IOException e) {
            return ResponseEntity.status(500).body(Map.of(
                "message", "文件上传失败: " + e.getMessage()
            ));
        }
    }

    private boolean isAllowedFileType(String extension) {
        String lowerExt = extension.toLowerCase();
        return lowerExt.equals(".jpg") || lowerExt.equals(".jpeg") || lowerExt.equals(".png") ||
               lowerExt.equals(".gif") || lowerExt.equals(".mp3") || lowerExt.equals(".wav") ||
               lowerExt.equals(".mp4") || lowerExt.equals(".pdf") || lowerExt.equals(".doc") ||
               lowerExt.equals(".docx") || lowerExt.equals(".txt") || lowerExt.equals(".zip") ||
               lowerExt.equals(".rar");
    }
}