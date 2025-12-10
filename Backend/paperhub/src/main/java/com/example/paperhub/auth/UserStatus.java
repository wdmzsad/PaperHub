package com.example.paperhub.auth;

public enum UserStatus {
    NORMAL,   // 正常
    AUDIT,    // 待审核：被举报后等待管理员审核
    BANNED,   // 封禁中：无法登录
    MUTE      // 禁言中：可登录但无法进行互动
}


