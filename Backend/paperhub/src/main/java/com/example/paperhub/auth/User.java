package com.example.paperhub.auth;

import jakarta.persistence.*;
import java.time.Instant;

@Entity//定义实体类
@Table(name = "users", indexes = { @Index(name = "idx_email", columnList = "email", unique = true) })//定义数据库表和索引
public class User {
    @Id//主键
    @GeneratedValue(strategy = GenerationType.IDENTITY)//定义主键生成策略
    @Column(name = "id")
    private Long id;//用户ID

    @Column(name = "email", nullable = false, unique = true)//邮箱列
    private String email;

    @Column(name = "password_hash", nullable = false)//密码列
    private String passwordHash;

    @Column(name = "name")//用户昵称
    private String name;
    
    @Column(name = "avatar")//头像URL
    private String avatar;
    
    @Column(name = "affiliation")//所属机构
    private String affiliation;

    @Column(name = "bio", columnDefinition = "TEXT")//个人简介
    private String bio;

    @Enumerated(EnumType.STRING)
    @Column(name = "role", nullable = false, columnDefinition = "varchar(20) default 'USER'")
    private UserRole role = UserRole.USER;

    @Enumerated(EnumType.STRING)
    @Column(
            name = "status",
            nullable = false,
            columnDefinition = "ENUM('NORMAL','BANNED','MUTE','AUDIT') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT 'NORMAL'"
    )
    private UserStatus status = UserStatus.NORMAL;

    /**
     * 禁言截止时间（可为空，空表示不限期）
     */
    @Column(name = "mute_until")
    private Instant muteUntil;

    @Column(name = "research_directions", columnDefinition = "TEXT")//研究方向(逗号分隔)
    private String researchDirections;

    @Column(name = "profile_background")//主页背景图URL
    private String profileBackground;

    // ============ 隐私设置相关字段 ============
    /**
     * 是否隐藏关注列表（true 时除本人外他人无法查看其关注列表）
     */
    @Column(name = "hide_following", nullable = false)
    private boolean hideFollowing = false;

    /**
     * 是否隐藏粉丝列表（true 时除本人外他人无法查看其粉丝列表）
     */
    @Column(name = "hide_followers", nullable = false)
    private boolean hideFollowers = false;

    /**
     * 收藏是否公开（false 时除本人外他人无法查看其收藏列表）
     */
    @Column(name = "public_favorites", nullable = false)
    private boolean publicFavorites = true;

    @Column(name = "verified", nullable = false)//验证状态列
    private boolean verified = false;

    @Column(name = "verify_code")//验证码
    private String verifyCode;
    
    @Column(name = "verify_expiry")//验证码过期时间
    private Instant verifyExpiry;

    @Column(name = "reset_code")//重置码
    private String resetCode;
    
    @Column(name = "reset_expiry")//重置码过期时间
    private Instant resetExpiry;

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
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    public String getAvatar() { return avatar; }
    public void setAvatar(String avatar) { this.avatar = avatar; }
    public String getAffiliation() { return affiliation; }
    public void setAffiliation(String affiliation) { this.affiliation = affiliation; }
    public String getBio() { return bio; }
    public void setBio(String bio) { this.bio = bio; }
    public UserRole getRole() { return role; }
    public void setRole(UserRole role) { this.role = role; }
    public UserStatus getStatus() { return status; }
    public void setStatus(UserStatus status) { this.status = status; }
    public Instant getMuteUntil() { return muteUntil; }
    public void setMuteUntil(Instant muteUntil) { this.muteUntil = muteUntil; }
    public String getResearchDirections() { return researchDirections; }
    public void setResearchDirections(String researchDirections) { this.researchDirections = researchDirections; }
    public String getProfileBackground() { return profileBackground; }
    public void setProfileBackground(String profileBackground) { this.profileBackground = profileBackground; }

    public boolean isHideFollowing() { return hideFollowing; }
    public void setHideFollowing(boolean hideFollowing) { this.hideFollowing = hideFollowing; }

    public boolean isHideFollowers() { return hideFollowers; }
    public void setHideFollowers(boolean hideFollowers) { this.hideFollowers = hideFollowers; }

    public boolean isPublicFavorites() { return publicFavorites; }
    public void setPublicFavorites(boolean publicFavorites) { this.publicFavorites = publicFavorites; }

    @PrePersist
    public void ensureRole() {
        if (role == null) {
            role = UserRole.USER;
        }
        if (status == null) {
            status = UserStatus.NORMAL;
        }
    }
}


