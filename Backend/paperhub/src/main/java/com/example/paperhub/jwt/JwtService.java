package com.example.paperhub.jwt;

import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.time.Instant;
import java.util.Date;

@Service
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


