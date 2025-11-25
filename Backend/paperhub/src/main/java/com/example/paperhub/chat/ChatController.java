package com.example.paperhub.chat;

import com.example.paperhub.chat.dto.ConversationResponse;
import com.example.paperhub.chat.dto.CreateConversationRequest;
import com.example.paperhub.chat.dto.MessageResponse;
import com.example.paperhub.chat.dto.SendMessageRequest;
import com.example.paperhub.chat.Conversation;
import com.example.paperhub.chat.MessageType;
import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import jakarta.validation.Valid;
import java.util.List;
import java.util.Optional;

@RestController
@RequestMapping("/api/conversations")
public class ChatController {

    private static final Logger logger = LoggerFactory.getLogger(ChatController.class);

    @Autowired
    private ChatService chatService;

    @Autowired
    private UserRepository userRepository;

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
            @RequestParam(defaultValue = "20") int size) {

        if (user == null) {
            return ResponseEntity.badRequest().build();
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

        Message message;

        // 如果有媒体文件列表，使用新的方法
        if (request.getMediaUrls() != null && !request.getMediaUrls().isEmpty()) {
            message = chatService.sendMessageWithMedia(
                conversationId,
                user.getId(),
                request.getContent(),
                request.getType() != null ? request.getType() : MessageType.IMAGE,
                request.getMediaUrls()
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
    public ResponseEntity<Void> markAsRead(
            @AuthenticationPrincipal com.example.paperhub.auth.User user,
            @PathVariable Long conversationId) {

        if (user == null) {
            return ResponseEntity.badRequest().build();
        }

        chatService.markAsRead(conversationId, user.getId());
        return ResponseEntity.ok().build();
    }

}