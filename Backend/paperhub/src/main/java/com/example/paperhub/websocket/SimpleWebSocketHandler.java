package com.example.paperhub.websocket;

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
 * 简单的WebSocket处理器
 * 处理原生WebSocket连接，不使用STOMP
 */
@Component
public class SimpleWebSocketHandler extends TextWebSocketHandler {
    // 存储每个帖子ID对应的WebSocket会话
    private final Map<Long, Map<String, WebSocketSession>> postSessions = new ConcurrentHashMap<>();
    private final ObjectMapper objectMapper = new ObjectMapper();

    @Override
    public void afterConnectionEstablished(WebSocketSession session) throws Exception {
        // 从URI中提取postId
        String path = session.getUri().getPath();
        Long postId = extractPostId(path);
        
        if (postId != null) {
            postSessions.computeIfAbsent(postId, k -> new ConcurrentHashMap<>())
                .put(session.getId(), session);
        }
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) throws Exception {
        // 移除会话
        String path = session.getUri().getPath();
        Long postId = extractPostId(path);
        
        if (postId != null) {
            Map<String, WebSocketSession> sessions = postSessions.get(postId);
            if (sessions != null) {
                sessions.remove(session.getId());
                if (sessions.isEmpty()) {
                    postSessions.remove(postId);
                }
            }
        }
    }

    @Override
    protected void handleTextMessage(WebSocketSession session, TextMessage message) throws Exception {
        // 可以处理客户端发送的消息，这里暂时不需要
    }

    /**
     * 向指定帖子的所有客户端发送消息
     */
    public void sendToPost(Long postId, Object message) {
        Map<String, WebSocketSession> sessions = postSessions.get(postId);
        if (sessions != null) {
            try {
                String json = objectMapper.writeValueAsString(message);
                TextMessage textMessage = new TextMessage(json);
                
                sessions.values().forEach(session -> {
                    try {
                        if (session.isOpen()) {
                            session.sendMessage(textMessage);
                        }
                    } catch (IOException e) {
                        // 记录错误
                        e.printStackTrace();
                    }
                });
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
    }

    private Long extractPostId(String path) {
        try {
            // 路径格式: /ws/posts/{postId}
            String[] parts = path.split("/");
            if (parts.length >= 4 && "posts".equals(parts[2])) {
                return Long.parseLong(parts[3]);
            }
        } catch (Exception e) {
            // 忽略解析错误
        }
        return null;
    }
}

