package com.example.paperhub.websocket;

import com.example.paperhub.chat.dto.MessageResponse;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.TextWebSocketHandler;

import java.io.IOException;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * 聊天WebSocket处理器
 * 处理私聊的实时消息推送
 */
@Component
public class ChatWebSocketHandler extends TextWebSocketHandler {

    // 存储每个用户ID对应的WebSocket会话
    private final Map<Long, WebSocketSession> userSessions = new ConcurrentHashMap<>();
    private final ObjectMapper objectMapper = new ObjectMapper();

    @Override
    public void afterConnectionEstablished(WebSocketSession session) throws Exception {
        // 从URI中提取userId
        String path = session.getUri().getPath();
        Long userId = extractUserId(path);

        if (userId != null) {
            userSessions.put(userId, session);
        }
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) throws Exception {
        // 移除会话
        String path = session.getUri().getPath();
        Long userId = extractUserId(path);

        if (userId != null) {
            userSessions.remove(userId);
        }
    }

    @Override
    protected void handleTextMessage(WebSocketSession session, TextMessage message) throws Exception {
        // 可以处理客户端发送的消息，比如输入状态等
        // 这里暂时不需要处理客户端发送的消息
    }

    /**
     * 向指定用户发送消息
     */
    public void sendToUser(Long userId, Object message) {
        WebSocketSession session = userSessions.get(userId);
        if (session != null && session.isOpen()) {
            try {
                String json = objectMapper.writeValueAsString(message);
                TextMessage textMessage = new TextMessage(json);
                session.sendMessage(textMessage);
            } catch (IOException e) {
                // 记录错误
                e.printStackTrace();
            }
        }
    }

    /**
     * 向多个用户发送消息
     */
    public void sendToUsers(Iterable<Long> userIds, Object message) {
        for (Long userId : userIds) {
            sendToUser(userId, message);
        }
    }

    private Long extractUserId(String path) {
        try {
            // 路径格式: /ws/chat/{userId}
            String[] parts = path.split("/");
            if (parts.length >= 4 && "chat".equals(parts[2])) {
                return Long.parseLong(parts[3]);
            }
        } catch (Exception e) {
            // 忽略解析错误
        }
        return null;
    }
}