package com.example.paperhub.auth;

import com.example.paperhub.notify.MailService;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.security.SecureRandom;
import java.time.Instant;

@Service//定义服务层
public class AuthService {
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final MailService mailService;
    private final SecureRandom random = new SecureRandom();

    public AuthService(UserRepository userRepository, PasswordEncoder passwordEncoder, MailService mailService) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.mailService = mailService;
    }
    
    //以下函数是对应AuthController中的函数，负责处理用户认证相关的业务逻辑
    public void register(String email, String rawPassword) {//注册新用户
        if (userRepository.existsByEmail(email)) {
            throw new IllegalArgumentException("该邮箱已注册，请直接登录或找回密码");
        }
        User user = new User();
        user.setEmail(email);
        user.setPasswordHash(passwordEncoder.encode(rawPassword));
        user.setRole(UserRole.USER);
        String code = generateCode(6);
        user.setVerifyCode(code);
        user.setVerifyExpiry(Instant.now().plusSeconds(5 * 60));
        userRepository.save(user);
        mailService.sendVerificationMail(email, code);
    }

    public void resendVerification(String email) {//重新发送验证邮件
        User user = userRepository.findByEmail(email).orElseThrow(() -> new IllegalArgumentException("邮箱未注册"));
        String code = generateCode(6);
        user.setVerifyCode(code);
        user.setVerifyExpiry(Instant.now().plusSeconds(5 * 60));
        userRepository.save(user);
        mailService.sendVerificationMail(email, code);
    }

    public void verify(String email, String code) {//验证用户邮箱
        User user = userRepository.findByEmail(email).orElseThrow(() -> new IllegalArgumentException("邮箱未注册"));
        if (user.getVerifyCode() == null || user.getVerifyExpiry() == null) {
            throw new IllegalArgumentException("无验证请求，请先注册或重新发送验证码");
        }
        if (Instant.now().isAfter(user.getVerifyExpiry())) {
            throw new IllegalArgumentException("验证码已过期，请重新获取验证邮件");
        }
        if (!user.getVerifyCode().equals(code)) {
            throw new IllegalArgumentException("验证码不正确");
        }
        user.setVerified(true);
        user.setVerifyCode(null);
        user.setVerifyExpiry(null);
        userRepository.save(user);
    }

    public User validateLogin(String email, String rawPassword) {//验证用户登录
        User user = userRepository.findByEmail(email).orElseThrow(() -> new IllegalArgumentException("邮箱未注册"));
        if (!user.isVerified()) {
            throw new IllegalArgumentException("邮箱未验证，请先完成邮件验证");
        }
        if (!passwordEncoder.matches(rawPassword, user.getPasswordHash())) {
            throw new IllegalArgumentException("密码错误");
        }
        if (user.getStatus() == UserStatus.BANNED) {
            throw new IllegalArgumentException("账号已被封禁，请联系管理员");
        }
        return user;
    }

    public java.util.Optional<User> findByEmail(String email) {//根据邮箱查找用户
        return userRepository.findByEmail(email);
    }

    public void requestReset(String email) {//请求重置密码
        User user = userRepository.findByEmail(email).orElseThrow(() -> new IllegalArgumentException("邮箱未注册"));
        String code = generateCode(6);
        user.setResetCode(code);
        user.setResetExpiry(Instant.now().plusSeconds(10 * 60));
        userRepository.save(user);
        mailService.sendResetMail(email, code);
    }

    public void resetPassword(String email, String code, String newRawPassword) {//重置用户密码
        User user = userRepository.findByEmail(email).orElseThrow(() -> new IllegalArgumentException("邮箱未注册"));
        if (user.getResetCode() == null || user.getResetExpiry() == null) {
            throw new IllegalArgumentException("无重置请求，请先请求重置邮件");
        }
        if (Instant.now().isAfter(user.getResetExpiry())) {
            throw new IllegalArgumentException("重置验证码已过期，请重新发送");
        }
        if (!user.getResetCode().equals(code)) {
            throw new IllegalArgumentException("重置验证码不正确");
        }
        user.setPasswordHash(passwordEncoder.encode(newRawPassword));
        user.setResetCode(null);
        user.setResetExpiry(null);
        userRepository.save(user);
    }

    private String generateCode(int len) {//生成验证码
        String digits = "0123456789";
        StringBuilder sb = new StringBuilder(len);
        for (int i = 0; i < len; i++) {
            sb.append(digits.charAt(random.nextInt(digits.length())));
        }
        return sb.toString();
    }
}


