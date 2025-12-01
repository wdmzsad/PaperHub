package com.example.paperhub.chat;

public class RedisKeys {
    private static final String PREFIX = "chat:";

    public static String conversationMessages(Long conversationId) {
        return PREFIX + "conversation:" + conversationId;
    }
}
