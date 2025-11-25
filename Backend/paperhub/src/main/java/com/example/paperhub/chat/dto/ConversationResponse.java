package com.example.paperhub.chat.dto;

import com.example.paperhub.chat.Conversation;
import com.example.paperhub.chat.Message;

import java.time.LocalDateTime;

public class ConversationResponse {
    private Long id;
    private String type;
    private String displayName;
    private String displayAvatar;
    private MessageResponse lastMessage;
    private Integer unreadCount;
    private LocalDateTime updatedAt;
    private Boolean isOnline;

    public ConversationResponse() {}

    public ConversationResponse(Conversation conversation, Message lastMessage, Integer unreadCount, String displayName, String displayAvatar, Boolean isOnline) {
        this.id = conversation.getId();
        this.type = conversation.getType().name();
        this.displayName = displayName;
        this.displayAvatar = displayAvatar;
        this.lastMessage = lastMessage != null ? new MessageResponse(lastMessage) : null;
        this.unreadCount = unreadCount;
        this.updatedAt = conversation.getUpdatedAt();
        this.isOnline = isOnline;
    }

    // Getters and Setters
    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getType() {
        return type;
    }

    public void setType(String type) {
        this.type = type;
    }

    public String getDisplayName() {
        return displayName;
    }

    public void setDisplayName(String displayName) {
        this.displayName = displayName;
    }

    public String getDisplayAvatar() {
        return displayAvatar;
    }

    public void setDisplayAvatar(String displayAvatar) {
        this.displayAvatar = displayAvatar;
    }

    public MessageResponse getLastMessage() {
        return lastMessage;
    }

    public void setLastMessage(MessageResponse lastMessage) {
        this.lastMessage = lastMessage;
    }

    public Integer getUnreadCount() {
        return unreadCount;
    }

    public void setUnreadCount(Integer unreadCount) {
        this.unreadCount = unreadCount;
    }

    public LocalDateTime getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(LocalDateTime updatedAt) {
        this.updatedAt = updatedAt;
    }

    public Boolean getIsOnline() {
        return isOnline;
    }

    public void setIsOnline(Boolean isOnline) {
        this.isOnline = isOnline;
    }
}