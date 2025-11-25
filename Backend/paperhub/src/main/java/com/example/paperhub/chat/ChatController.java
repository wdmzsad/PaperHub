package com.example.paperhub.chat;

import com.example.paperhub.chat.dto.ConversationResponse;
import com.example.paperhub.chat.dto.CreateConversationRequest;
import com.example.paperhub.chat.dto.MessageResponse;
import com.example.paperhub.chat.dto.SendMessageRequest;
import com.example.paperhub.chat.Conversation;
import com.example.paperhub.chat.MessageType;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import jakarta.validation.Valid;
import java.util.List;

@RestController
@RequestMapping("/api/conversations")
public class ChatController {

    @Autowired
    private ChatService chatService;

    /**
     * 获取当前用户的所有会话列表
     */
    @GetMapping
    public ResponseEntity<List<ConversationResponse>> getConversations(@AuthenticationPrincipal Long userId) {
        List<ConversationResponse> conversations = chatService.getUserConversations(userId);
        return ResponseEntity.ok(conversations);
    }

    /**
     * 创建或获取私聊会话
     */
    @PostMapping
    public ResponseEntity<ConversationResponse> createOrGetConversation(
            @AuthenticationPrincipal Long currentUserId,
            @Valid @RequestBody CreateConversationRequest request) {

        Conversation conversation = chatService.createOrGetPrivateConversation(currentUserId, request.getTargetUserId());

        // 构建响应
        List<ConversationResponse> userConversations = chatService.getUserConversations(currentUserId);
        ConversationResponse response = userConversations.stream()
                .filter(c -> c.getId().equals(conversation.getId()))
                .findFirst()
                .orElseThrow(() -> new RuntimeException("创建会话失败"));

        return ResponseEntity.ok(response);
    }

    /**
     * 获取会话消息列表
     */
    @GetMapping("/{conversationId}/messages")
    public ResponseEntity<Page<MessageResponse>> getMessages(
            @AuthenticationPrincipal Long userId,
            @PathVariable Long conversationId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {

        Page<MessageResponse> messages = chatService.getConversationMessages(conversationId, userId, page, size);
        return ResponseEntity.ok(messages);
    }

    /**
     * 发送消息
     */
    @PostMapping("/{conversationId}/messages")
    public ResponseEntity<MessageResponse> sendMessage(
            @AuthenticationPrincipal Long userId,
            @PathVariable Long conversationId,
            @Valid @RequestBody SendMessageRequest request) {

        Message message = chatService.sendMessage(
            conversationId,
            userId,
            request.getContent(),
            request.getType() != null ? request.getType() : MessageType.TEXT,
            request.getFileUrl(),
            request.getFileName(),
            request.getFileSize()
        );

        // 构建响应
        MessageResponse response = new MessageResponse(message);
        // TODO: 设置发送者信息
        response.setIsMe(true);

        return ResponseEntity.ok(response);
    }

    /**
     * 标记会话为已读
     */
    @PutMapping("/{conversationId}/read")
    public ResponseEntity<Void> markAsRead(
            @AuthenticationPrincipal Long userId,
            @PathVariable Long conversationId) {

        chatService.markAsRead(conversationId, userId);
        return ResponseEntity.ok().build();
    }
}