//SecurityConfig模块，负责配置Spring Security的安全性，具体内容就是配置哪些请求需要认证，哪些请求不需要认证
package com.example.paperhub.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.web.cors.CorsConfiguration;

import java.util.List;

@Configuration//定义配置类
public class SecurityConfig {
    @Bean//定义Bean，用于Spring Boot自动配置
    SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {//定义安全过滤器链
        http
            .csrf(csrf -> csrf.disable())
            .cors(cors -> cors.configurationSource(request -> {
                CorsConfiguration cfg = new CorsConfiguration();
                cfg.setAllowedOrigins(List.of("*"));
                cfg.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE", "OPTIONS"));
                cfg.setAllowedHeaders(List.of("*"));
                return cfg;
            }))
            .authorizeHttpRequests(reg -> reg
                .requestMatchers("/auth/**").permitAll()//允许所有以/auth开头的请求
                .anyRequest().authenticated())//任何其他请求都需要认证
            .httpBasic(Customizer.withDefaults());
        return http.build();
    }

    @Bean
    PasswordEncoder passwordEncoder() {//定义密码编码器，用于在后端中加密用户密码
        return new BCryptPasswordEncoder();
    }
}


