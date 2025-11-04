package com.example.paperhub.auth;

import jakarta.persistence.*;
import java.time.Instant;

@Entity//定义实体类
@Table(name = "users", indexes = { @Index(columnList = "email", unique = true) })//定义数据库表和索引
public class User {
    @Id//主键
    @GeneratedValue(strategy = GenerationType.IDENTITY)//定义主键生成策略
    private Long id;//用户ID

    @Column(nullable = false, unique = true)//邮箱列
    private String email;

    @Column(nullable = false)//密码列
    private String passwordHash;

    @Column(nullable = false)//验证状态列
    private boolean verified = false;

    private String verifyCode;//验证码
    private Instant verifyExpiry;//验证码过期时间

    private String resetCode;//重置码
    private Instant resetExpiry;//重置码过期时间

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }
    public String getPasswordHash() { return passwordHash; }
    public void setPasswordHash(String passwordHash) { this.passwordHash = passwordHash; }
    public boolean isVerified() { return verified; }
    public void setVerified(boolean verified) { this.verified = verified; }
    public String getVerifyCode() { return verifyCode; }
    public void setVerifyCode(String verifyCode) { this.verifyCode = verifyCode; }
    public Instant getVerifyExpiry() { return verifyExpiry; }
    public void setVerifyExpiry(Instant verifyExpiry) { this.verifyExpiry = verifyExpiry; }
    public String getResetCode() { return resetCode; }
    public void setResetCode(String resetCode) { this.resetCode = resetCode; }
    public Instant getResetExpiry() { return resetExpiry; }
    public void setResetExpiry(Instant resetExpiry) { this.resetExpiry = resetExpiry; }
}


