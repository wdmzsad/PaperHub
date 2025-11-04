//auth模块，负责处理用户认证相关的业务逻辑,包括注册、登录、邮箱验证、密码重置等功能
package com.example.paperhub.auth;

import com.example.paperhub.auth.dto.AuthDtos.*;
import com.example.paperhub.jwt.JwtService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController//定义控制器层
@RequestMapping("/auth")//所有以/auth开头的前端请求都会被映射到该控制器中进行处理
public class AuthController {
    private final AuthService authService;
    private final JwtService jwtService;

    public AuthController(AuthService authService, JwtService jwtService) {
        this.authService = authService;
        this.jwtService = jwtService;
    }

    @PostMapping("/register")//处理所有以/auth/register开头的请求，注册新用户
    public ResponseEntity<MessageResp> register(@Valid @RequestBody RegisterReq req) {
        authService.register(req.email(), req.password());
        return ResponseEntity.status(201).body(new MessageResp("注册成功，已发送验证邮件"));
    }

    @PostMapping("/send-verification")//处理所有以/auth/send-verification开头的请求，重新发送验证邮件
    public ResponseEntity<MessageResp> sendVerification(@Valid @RequestBody EmailReq req) {
        authService.resendVerification(req.email());
        return ResponseEntity.ok(new MessageResp("已重新发送验证邮件"));
    }

    @PostMapping("/verify")//处理所有以/auth/verify开头的请求，验证用户邮箱
    public ResponseEntity<MessageResp> verify(@Valid @RequestBody VerifyReq req) {
        authService.verify(req.email(), req.code());
        return ResponseEntity.ok(new MessageResp("验证成功，注册完成"));
    }

    @PostMapping("/login")//处理所有以/auth/login开头的请求，用户登录
    public ResponseEntity<LoginResp> login(@Valid @RequestBody LoginReq req) {
        User u = authService.validateLogin(req.email(), req.password());
        String token = jwtService.generateToken(u.getEmail());
        long expiresIn = jwtService.getExpiresInSeconds();
        return ResponseEntity.ok(new LoginResp("登录成功", token, expiresIn));
    }

    @PostMapping("/request-reset")//处理所有以/auth/request-reset开头的请求，请求重置密码
    public ResponseEntity<MessageResp> requestReset(@Valid @RequestBody EmailReq req) {
        authService.requestReset(req.email());
        return ResponseEntity.ok(new MessageResp("重置邮件已发送"));
    }

    @PostMapping("/reset-password")//处理所有以/auth/reset-password开头的请求，重置用户密码
    public ResponseEntity<MessageResp> resetPassword(@Valid @RequestBody ResetReq req) {
        authService.resetPassword(req.email(), req.code(), req.newPassword());
        return ResponseEntity.ok(new MessageResp("密码已重置"));
    }

    @ExceptionHandler(IllegalArgumentException.class)//处理所有以/auth/开头的请求，返回错误信息
    public ResponseEntity<MessageResp> handleBadRequest(IllegalArgumentException ex) {
        String msg = ex.getMessage();
        if (msg != null) {
            if (msg.contains("未注册")) return ResponseEntity.status(404).body(new MessageResp(msg));
            if (msg.contains("未验证")) return ResponseEntity.status(403).body(new MessageResp(msg));
            if (msg.contains("密码错误")) return ResponseEntity.status(401).body(new MessageResp(msg));
        }
        return ResponseEntity.badRequest().body(new MessageResp(msg != null ? msg : "Bad request"));
    }
}


