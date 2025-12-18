package com.example.paperhub.chat;

import com.example.paperhub.chat.dto.ConversationResponse;
import com.example.paperhub.chat.dto.CreateConversationRequest;
import com.example.paperhub.chat.dto.MessageResponse;
import com.example.paperhub.chat.dto.SendMessageRequest;
import com.example.paperhub.chat.Conversation;
import com.example.paperhub.chat.MessageType;
import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserRepository;
import com.example.paperhub.config.ObsConfig;
import com.obs.services.ObsClient;
import com.obs.services.exception.ObsException;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import jakarta.validation.Valid;
import java.io.IOException;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

@RestController
@RequestMapping("/api/conversations")
public class ChatController {

    private static final Logger logger = LoggerFactory.getLogger(ChatController.class);

    @Autowired
    private ChatService chatService;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private ObsClient obsClient;

    @Autowired
    private ObsConfig obsConfig;

    @Autowired
    private ConversationParticipantRepository conversationParticipantRepository;

    /**
     * 获取当前用户的所有会话列表
     */
    @GetMapping
    public ResponseEntity<List<ConversationResponse>> getConversations(@AuthenticationPrincipal com.example.paperhub.auth.User user) {
        if (user == null) {
            return ResponseEntity.badRequest().build();
        }
        List<ConversationResponse> conversations = chatService.getUserConversations(user.getId());
        return ResponseEntity.ok(conversations);
    }

    /**
     * 创建或获取私聊会话
     */
    @PostMapping
    public ResponseEntity<ConversationResponse> createOrGetConversation(
            @AuthenticationPrincipal com.example.paperhub.auth.User currentUser,
            @Valid @RequestBody CreateConversationRequest request) {

        if (currentUser == null) {
            return ResponseEntity.badRequest().build();
        }

        logger.info("收到创建会话请求: currentUserId={}, targetUserId={}", currentUser.getId(), request.getTargetUserId());

        // 首先验证目标用户是否存在
        Optional<User> otherUser = userRepository.findById(request.getTargetUserId());
        if (otherUser.isEmpty()) {
            logger.warn("目标用户不存在: {}", request.getTargetUserId());
            return ResponseEntity.badRequest().build();
        }

        logger.info("目标用户存在: {}", otherUser.get().getName());

        Conversation conversation = chatService.createOrGetPrivateConversation(currentUser.getId(), request.getTargetUserId());

        // 构建响应 - 直接创建响应对象，而不是从列表中查找
        User user = otherUser.get();
        ConversationResponse response = new ConversationResponse(
            conversation,
            null, // 最后一条消息为空
            0,    // 未读消息数为0
            user.getName(),
            user.getAvatar(),
            false // 在线状态
        );

        logger.info("会话创建成功: conversationId={}, displayName={}", conversation.getId(), user.getName());

        return ResponseEntity.ok(response);
    }

    /**
     * 获取会话消息列表
     */
    @GetMapping("/{conversationId}/messages")
    public ResponseEntity<Page<MessageResponse>> getMessages(
            @AuthenticationPrincipal com.example.paperhub.auth.User user,
            @PathVariable Long conversationId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "100") int size) {

        if (user == null) {
            return ResponseEntity.badRequest().build();
        }

        logger.info("【会话消息访问】conversationId={}, userId={}, userName={}",
                conversationId, user.getId(), user.getName());

        // 验证用户是否是会话参与者
        boolean isParticipant = conversationParticipantRepository
                .existsByConversationIdAndUserId(conversationId, user.getId());

        logger.info("【权限验证结果】conversationId={}, userId={}, isParticipant={}",
                conversationId, user.getId(), isParticipant);

        if (!isParticipant) {
            logger.warn("【越权访问被拦截】conversationId={}, userId={}, userName={}",
                    conversationId, user.getId(), user.getName());
            return ResponseEntity.status(403).build();
        }

        Page<MessageResponse> messages = chatService.getConversationMessages(conversationId, user.getId(), page, size);
        return ResponseEntity.ok(messages);
    }

    /**
     * 发送消息
     */
    @PostMapping("/{conversationId}/messages")
    public ResponseEntity<MessageResponse> sendMessage(
            @AuthenticationPrincipal com.example.paperhub.auth.User user,
            @PathVariable Long conversationId,
            @Valid @RequestBody SendMessageRequest request) {

        if (user == null) {
            return ResponseEntity.badRequest().build();
        }

        // 验证用户是否是会话参与者
        boolean isParticipant = conversationParticipantRepository
                .existsByConversationIdAndUserId(conversationId, user.getId());
        if (!isParticipant) {
            return ResponseEntity.status(403).build();
        }

        Message message;

        // 如果有媒体文件列表，使用新的方法
        if (request.getMediaUrls() != null && !request.getMediaUrls().isEmpty()) {
            message = chatService.sendMessageWithMedia(
                conversationId,
                user.getId(),
                request.getContent(),
                request.getType() != null ? request.getType() : MessageType.IMAGE,
                request.getMediaUrls(),
                request.getFileName(),
                request.getFileSize()
            );
        } else {
            // 否则使用旧的方法
            message = chatService.sendMessage(
                conversationId,
                user.getId(),
                request.getContent(),
                request.getType() != null ? request.getType() : MessageType.TEXT,
                request.getFileUrl(),
                request.getFileName(),
                request.getFileSize()
            );
        }

        if (message == null) {
            return ResponseEntity.badRequest().build();
        }

        // 构建响应
        MessageResponse response = new MessageResponse(message);
        // 设置发送者信息
        response.setSenderName(user.getName());
        response.setSenderAvatar(user.getAvatar());
        response.setIsMe(true);

        return ResponseEntity.ok(response);
    }

    /**
     * 标记会话为已读
     */
    @PutMapping("/{conversationId}/read")
    public ResponseEntity<Map<String, Object>> markAsRead(
            @AuthenticationPrincipal com.example.paperhub.auth.User user,
            @PathVariable Long conversationId) {

        if (user == null) {
            return ResponseEntity.badRequest().body(Map.of("error", "用户未认证"));
        }

        // 验证用户是否是会话参与者
        boolean isParticipant = conversationParticipantRepository
                .existsByConversationIdAndUserId(conversationId, user.getId());
        if (!isParticipant) {
            return ResponseEntity.status(403).body(Map.of("error", "无权限访问此会话"));
        }

        chatService.markAsRead(conversationId, user.getId());
        return ResponseEntity.ok(Map.of("success", true));
    }

    /**
     * 获取最新消息（从 Redis 缓存）
     */
    @GetMapping("/{conversationId}/messages/latest")
    public ResponseEntity<List<MessageResponse>> getLatestMessages(
            @AuthenticationPrincipal com.example.paperhub.auth.User user,
            @PathVariable Long conversationId,
            @RequestParam(defaultValue = "30") int limit) {

        if (user == null) {
            return ResponseEntity.badRequest().build();
        }

        logger.info("【获取最新消息】conversationId={}, userId={}, userName={}, limit={}",
                conversationId, user.getId(), user.getName(), limit);

        // 验证用户是否是会话参与者
        boolean isParticipant = conversationParticipantRepository
                .existsByConversationIdAndUserId(conversationId, user.getId());

        logger.info("【权限验证结果】conversationId={}, userId={}, isParticipant={}",
                conversationId, user.getId(), isParticipant);

        if (!isParticipant) {
            logger.warn("【越权访问被拦截】conversationId={}, userId={}, userName={}",
                    conversationId, user.getId(), user.getName());
            return ResponseEntity.status(403).build();
        }

        List<MessageResponse> messages = chatService.getLatestMessages(conversationId, user.getId(), limit);
        return ResponseEntity.ok(messages);
    }

    /**
     * 上传语音消息
     */
    @PostMapping("/{conversationId}/messages/voice")
    public ResponseEntity<?> uploadVoiceMessage(
            @AuthenticationPrincipal User currentUser,
            @PathVariable Long conversationId,
            @RequestParam("file") MultipartFile file,
            @RequestParam(value = "duration", required = false, defaultValue = "0") Long duration) {

        if (currentUser == null) {
            return ResponseEntity.status(401).body(Map.of("message", "未认证，请先登录"));
        }

        if (file == null || file.isEmpty()) {
            return ResponseEntity.badRequest().body(Map.of("message", "语音文件不能为空"));
        }

        // 验证用户是否是会话参与者
        boolean isParticipant = conversationParticipantRepository
                .existsByConversationIdAndUserId(conversationId, currentUser.getId());
        if (!isParticipant) {
            return ResponseEntity.status(403).body(Map.of("message", "无权限访问此会话"));
        }

        // 验证文件类型
        String originalName = file.getOriginalFilename();
        String extension = StringUtils.hasText(originalName) && originalName.contains(".")
                ? originalName.substring(originalName.lastIndexOf('.'))
                : "";

        if (!isAudioFile(extension)) {
            return ResponseEntity.badRequest().body(Map.of("message", "不支持的音频格式"));
        }

        // 限制文件大小 (10MB)
        if (file.getSize() > 10 * 1024 * 1024) {
            return ResponseEntity.badRequest().body(Map.of("message", "语音文件不能超过10MB"));
        }

        // 上传到 OBS
        String objectKey = "chat-voice/" + UUID.randomUUID() + extension;
        String url = "https://" + obsConfig.getBucketName() + ".obs.cn-north-4.myhuaweicloud.com/" + objectKey;

        try {
            obsClient.putObject(obsConfig.getBucketName(), objectKey, file.getInputStream());
            logger.info("语音文件上传成功: {}", url);

            // 创建语音消息
            Message message = chatService.sendMessage(
                conversationId,
                currentUser.getId(),
                "", // 语音消息内容为空
                MessageType.VOICE,
                url,
                originalName,
                    Long.valueOf(file.getSize())
            );

            if (message == null) {
                return ResponseEntity.status(500).body(Map.of("message", "消息发送失败"));
            }

            // 构建响应
            MessageResponse response = new MessageResponse(message);
            response.setSenderName(currentUser.getName());
            response.setSenderAvatar(currentUser.getAvatar());
            response.setIsMe(true);

            logger.info("语音消息发送成功: messageId={}, conversationId={}", message.getId(), conversationId);
            return ResponseEntity.ok(response);

        } catch (ObsException e) {
            logger.error("OBS上传失败: {}", e.getErrorMessage(), e);
            return ResponseEntity.status(500).body(Map.of(
                "message", "文件上传失败: " + e.getErrorMessage(),
                "code", e.getErrorCode()
            ));
        } catch (IOException e) {
            logger.error("文件读取失败: {}", e.getMessage(), e);
            return ResponseEntity.status(500).body(Map.of("message", "文件读取失败: " + e.getMessage()));
        }
    }

    private boolean isAudioFile(String extension) {
        String lowerExt = extension.toLowerCase();
        return lowerExt.equals(".mp3") || lowerExt.equals(".wav") || lowerExt.equals(".m4a") ||
               lowerExt.equals(".ogg") || lowerExt.equals(".aac") || lowerExt.equals(".webm");
    }

}