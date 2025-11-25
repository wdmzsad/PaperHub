package com.example.paperhub.websocket;

import com.example.paperhub.chat.dto.MessageResponse;
import org.springframework.stereotype.Service;

import java.util.Arrays;

/**
 * 聊天WebSocket服务类
 * 用于向客户端推送实时聊天消息
 */
@Service
public class ChatWebSocketService {

    private final ChatWebSocketHandler chatWebSocketHandler;

    public ChatWebSocketService(ChatWebSocketHandler chatWebSocketHandler) {
        this.chatWebSocketHandler = chatWebSocketHandler;
    }

    /**
     * 推送新消息给会话的所有参与者
     */
    public void sendNewMessage(Long conversationId, MessageResponse message, Long... participantIds) {
        ChatMessage messageWrapper = new ChatMessage("new_message", conversationId, message);
        chatWebSocketHandler.sendToUsers(Arrays.asList(participantIds), messageWrapper);
    }

    /**
     * 推送消息已读状态
     */
    public void sendMessageRead(Long conversationId, Long userId, Long messageId) {
        MessageReadMessage message = new MessageReadMessage("message_read", conversationId, userId, messageId);
        chatWebSocketHandler.sendToUser(userId, message);
    }

    /**
     * 推送用户输入状态
     */
    public void sendTypingStatus(Long conversationId, Long userId, String userName, boolean isTyping) {
        TypingMessage message = new TypingMessage("typing", conversationId, userId, userName, isTyping);
        chatWebSocketHandler.sendToUser(userId, message);
    }

    /**
     * 推送用户在线状态
     */
    public void sendOnlineStatus(Long userId, boolean isOnline) {
        OnlineStatusMessage message = new OnlineStatusMessage("online_status", userId, isOnline);
        chatWebSocketHandler.sendToUser(userId, message);
    }

    // 消息类定义
    public static class ChatMessage {
        public String type;
        public Long conversationId;
        public MessageResponse message;

        public ChatMessage(String type, Long conversationId, MessageResponse message) {
            this.type = type;
            this.conversationId = conversationId;
            this.message = message;
        }
    }

    public static class MessageReadMessage {
        public String type;
        public Long conversationId;
        public Long userId;
        public Long messageId;

        public MessageReadMessage(String type, Long conversationId, Long userId, Long messageId) {
            this.type = type;
            this.conversationId = conversationId;
            this.userId = userId;
            this.messageId = messageId;
        }
    }

    public static class TypingMessage {
        public String type;
        public Long conversationId;
        public Long userId;
        public String userName;
        public boolean isTyping;

        public TypingMessage(String type, Long conversationId, Long userId, String userName, boolean isTyping) {
            this.type = type;
            this.conversationId = conversationId;
            this.userId = userId;
            this.userName = userName;
            this.isTyping = isTyping;
        }
    }

    public static class OnlineStatusMessage {
        public String type;
        public Long userId;
        public boolean isOnline;

        public OnlineStatusMessage(String type, Long userId, boolean isOnline) {
            this.type = type;
            this.userId = userId;
            this.isOnline = isOnline;
        }
    }
}