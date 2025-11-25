package com.example.paperhub.chat.dto;

import jakarta.validation.constraints.NotNull;

public class CreateConversationRequest {
    @NotNull(message = "对方用户ID不能为空")
    private Long targetUserId;

    public Long getTargetUserId() {
        return targetUserId;
    }

    public void setTargetUserId(Long targetUserId) {
        this.targetUserId = targetUserId;
    }
}