//JWT模块，负责生成和验证JWT令牌，具体内容就是在用户登录之后生成一个JWT令牌，在后续该用户发请求的时候就使用这个JWT令牌进行身份验证
//如果后续添加的模块实现的都是用户登录之后才能使用的功能，那么jwt无需修改，只需要在后续的模块中使用JwtService生成JWT令牌并进行身份验证即可
package com.example.paperhub.jwt;

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

    public JwtService(
        @Value("${jwt.secret:change-this-to-strong-secret-change}") String secret,
        @Value("${jwt.expires-in-seconds:3600}") long expiresInSeconds
    ) {
        this.key = Keys.hmacShaKeyFor(secret.getBytes());
        this.expiresInSeconds = expiresInSeconds;
    }

    public String generateToken(String subject) {
        Instant now = Instant.now();
        return Jwts.builder()
            .setSubject(subject)
            .setIssuedAt(Date.from(now))
            .setExpiration(Date.from(now.plusSeconds(expiresInSeconds)))
            .signWith(key, SignatureAlgorithm.HS256)
            .compact();
    }

    public long getExpiresInSeconds() {
        return expiresInSeconds;
    }
}


