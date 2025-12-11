package com.example.paperhub.websocket;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.socket.config.annotation.EnableWebSocket;
import org.springframework.web.socket.config.annotation.WebSocketConfigurer;
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistry;

/**
 * 简单的WebSocket配置
 * 使用原生WebSocket而不是STOMP
 */
@Configuration
@EnableWebSocket
public class SimpleWebSocketConfig implements WebSocketConfigurer {
    private final SimpleWebSocketHandler webSocketHandler;
    private final ChatWebSocketHandler chatWebSocketHandler;

    public SimpleWebSocketConfig(SimpleWebSocketHandler webSocketHandler,
                                ChatWebSocketHandler chatWebSocketHandler) {
        this.webSocketHandler = webSocketHandler;
        this.chatWebSocketHandler = chatWebSocketHandler;
    }

    @Override
    public void registerWebSocketHandlers(WebSocketHandlerRegistry registry) {
        registry.addHandler(webSocketHandler, "/ws/posts/{postId}")
            .setAllowedOrigins("*");

        registry.addHandler(webSocketHandler, "/ws/admin")
            .setAllowedOrigins("*");

        registry.addHandler(webSocketHandler, "/ws/notifications/{userId}")
            .setAllowedOrigins("*");

        registry.addHandler(chatWebSocketHandler, "/ws/chat/{userId}")
            .setAllowedOrigins("*");
    }
}

