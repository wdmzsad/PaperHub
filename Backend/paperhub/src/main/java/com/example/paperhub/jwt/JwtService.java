//JWT模块，负责生成和验证JWT令牌，具体内容就是在用户登录之后生成一个JWT令牌，在后续该用户发请求的时候就使用这个JWT令牌进行身份验证
//如果后续添加的模块实现的都是用户登录之后才能使用的功能，那么jwt无需修改，只需要在后续的模块中使用JwtService生成JWT令牌并进行身份验证即可
package com.example.paperhub.jwt;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.time.Instant;
import java.util.Date;

@Service//定义服务层
public class JwtService {
    private final SecretKey key;
    private final long expiresInSeconds;
    private final long refreshExpiresInSeconds;

    public JwtService(
        @Value("${jwt.secret:change-this-to-strong-secret-change}") String secret,
        @Value("${jwt.expires-in-seconds:3600}") long expiresInSeconds,
        @Value("${jwt.refresh-expires-in-seconds:604800}") long refreshExpiresInSeconds
    ) {
        this.key = Keys.hmacShaKeyFor(secret.getBytes());
        this.expiresInSeconds = expiresInSeconds;
        this.refreshExpiresInSeconds = refreshExpiresInSeconds;
    }

    /**
     * 生成Access Token（短期令牌，用于API请求）
     */
    public String generateToken(String subject) {
        Instant now = Instant.now();
        return Jwts.builder()
            .setSubject(subject)
            .setIssuedAt(Date.from(now))
            .setExpiration(Date.from(now.plusSeconds(expiresInSeconds)))
            .signWith(key, SignatureAlgorithm.HS256)
            .compact();
    }

    /**
     * 生成Refresh Token（长期令牌，用于刷新Access Token）
     */
    public String generateRefreshToken(String subject) {
        Instant now = Instant.now();
        return Jwts.builder()
            .setSubject(subject)
            .setIssuedAt(Date.from(now))
            .setExpiration(Date.from(now.plusSeconds(refreshExpiresInSeconds)))
            .claim("type", "refresh") // 标记为refresh token
            .signWith(key, SignatureAlgorithm.HS256)
            .compact();
    }

    public long getExpiresInSeconds() {
        return expiresInSeconds;
    }

    public long getRefreshExpiresInSeconds() {
        return refreshExpiresInSeconds;
    }

    /**
     * 验证并解析JWT token
     * @param token JWT token
     * @return Claims对象，包含token中的所有信息
     * @throws io.jsonwebtoken.JwtException 如果token无效或已过期
     */
    public Claims parseToken(String token) {
        return Jwts.parserBuilder()
            .setSigningKey(key)
            .build()
            .parseClaimsJws(token)
            .getBody();
    }

    /**
     * 从token中提取email（subject）
     * @param token JWT token
     * @return email地址
     */
    public String extractEmail(String token) {
        Claims claims = parseToken(token);
        return claims.getSubject();
    }

    /**
     * 验证token是否有效
     * @param token JWT token
     * @return true if valid, false otherwise
     */
    public boolean validateToken(String token) {
        try {
            parseToken(token);
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * 验证refresh token是否有效
     * @param token Refresh token
     * @return true if valid, false otherwise
     */
    public boolean validateRefreshToken(String token) {
        try {
            Claims claims = parseToken(token);
            // 检查是否是refresh token类型
            String type = claims.get("type", String.class);
            return "refresh".equals(type);
        } catch (Exception e) {
            return false;
        }
    }
}


