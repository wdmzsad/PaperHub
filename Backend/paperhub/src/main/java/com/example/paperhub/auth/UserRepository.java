package com.example.paperhub.auth;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;

public interface UserRepository extends JpaRepository<User, Long> {//定义用户仓库
    Optional<User> findByEmail(String email);//根据邮箱查找用户
    boolean existsByEmail(String email);//判断用户是否存在
    boolean existsByEmailAndVerified(String email, boolean verified);//判断已验证用户是否存在
    // 根据名字模糊搜索用户
    java.util.List<User> findByNameContainingIgnoreCase(String name);
    // 根据状态查询用户
    Page<User> findByStatus(UserStatus status, Pageable pageable);
    java.util.List<User> findByStatus(UserStatus status);
    // 查询所有非指定状态的用户
    Page<User> findByStatusNot(UserStatus status, Pageable pageable);
}
