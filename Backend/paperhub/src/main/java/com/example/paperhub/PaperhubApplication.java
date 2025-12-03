package com.example.paperhub;//包名，用于组织代码

import org.springframework.boot.SpringApplication; //Spring Boot应用的启动类
import org.springframework.boot.autoconfigure.SpringBootApplication; //Spring Boot应用的自动配置类

@SpringBootApplication//Spring Boot应用的注解，自动配置Spring Boot应用
public class
PaperhubApplication {//Spring Boot应用的入口类

    public static void main(String[] args) {//程序入口，启动Spring Boot应用
        SpringApplication.run(PaperhubApplication.class, args);//启动Spring Boot应用
    }

}
