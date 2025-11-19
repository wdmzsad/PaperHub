package com.example.paperhub.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.web.client.RestTemplate;

import java.time.Duration;

/**
 * RestTemplate 配置类
 * 用于 HTTP 客户端请求
 */
@Configuration
public class RestTemplateConfig {
    
    @Bean
    public RestTemplate restTemplate() {
        // 配置请求工厂，设置超时时间
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(10000); // 连接超时 10 秒
        factory.setReadTimeout(30000);     // 读取超时 30 秒
        
        RestTemplate restTemplate = new RestTemplate(factory);
        
        // 配置 RestTemplate 自动跟随重定向（虽然我们已经使用 HTTPS，但保留此配置以防万一）
        // RestTemplate 默认会跟随重定向，但显式配置更安全
        
        return restTemplate;
    }
}

