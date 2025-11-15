package com.example.paperhub.auth.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

public class AuthDtos {//定义数据传输对象,说明的是前端请求传输的数据需要符合以下格式，否则会报错
    public record RegisterReq(@Email @NotBlank String email, @NotBlank String password) {}//注册请求
    public record EmailReq(@Email @NotBlank String email) {}//邮箱请求
    public record VerifyReq(@Email @NotBlank String email, @NotBlank String code) {}//验证请求
    public record LoginReq(@Email @NotBlank String email, @NotBlank String password) {}//登录请求
    public record ResetReq(@Email @NotBlank String email, @NotBlank String code, @NotBlank String newPassword) {}//重置请求

    public record MessageResp(String message) {}//消息响应
    public record LoginResp(String message, String token, String refreshToken, long expiresIn, long refreshExpiresIn) {}//登录响应
    public record RefreshTokenReq(@NotBlank String refreshToken) {}//刷新令牌请求
    public record RefreshTokenResp(String token, String refreshToken, long expiresIn, long refreshExpiresIn) {}//刷新令牌响应
}


