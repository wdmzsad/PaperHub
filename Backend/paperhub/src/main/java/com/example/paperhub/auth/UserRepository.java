package com.example.paperhub.auth;

import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;

public interface UserRepository extends JpaRepository<User, Long> {//定义用户仓库
    Optional<User> findByEmail(String email);//根据邮箱查找用户
    boolean existsByEmail(String email);//判断用户是否存在
    // 根据名字模糊搜索用户
    java.util.List<User> findByNameContainingIgnoreCase(String name);
}
