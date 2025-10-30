package com.example.paperhub.auth;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name = "users", indexes = { @Index(columnList = "email", unique = true) })
public class User {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true)
    private String email;

    @Column(nullable = false)
    private String passwordHash;

    @Column(nullable = false)
    private boolean verified = false;

    private String verifyCode;
    private Instant verifyExpiry;

    private String resetCode;
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
}


