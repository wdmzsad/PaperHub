package com.example.paperhub.auth.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

public class AuthDtos {
    public record RegisterReq(@Email @NotBlank String email, @NotBlank String password) {}
    public record EmailReq(@Email @NotBlank String email) {}
    public record VerifyReq(@Email @NotBlank String email, @NotBlank String code) {}
    public record LoginReq(@Email @NotBlank String email, @NotBlank String password) {}
    public record ResetReq(@Email @NotBlank String email, @NotBlank String code, @NotBlank String newPassword) {}

    public record MessageResp(String message) {}
    public record LoginResp(String message, String token, long expiresIn) {}
}


