package com.example.paperhub.config;

import com.obs.services.ObsClient;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class ObsConfig {

    @Value("${huawei.obs.endpoint}")
    private String endPoint;

    @Value("${huawei.obs.ak}")
    private String ak;

    @Value("${huawei.obs.sk}")
    private String sk;

    @Value("${huawei.obs.bucketName}")
    private String bucketName;

    // 暴露 ObsClient Bean
    @Bean
    public ObsClient obsClient() {
        return new ObsClient(ak, sk, endPoint);
    }

    public String getBucketName() {
        return bucketName;
    }
}
