# JWT Token 过期问题修复说明

## 问题描述
用户登录后，第一次评论成功，第二次评论就报错 403（权限不足）。怀疑系统在发了一条评论之后就退出了。

## 问题原因

### 1. JWT Token 过期时间太短
- **配置值**：`jwt.expires-in-seconds=36`（只有 36 秒！）
- **问题**：用户登录后，token 在 36 秒后就过期了
- **表现**：
  - 第一次评论时，token 还没过期，成功
  - 第二次评论时，如果超过 36 秒，token 就过期了，返回 403

### 2. SecurityConfig 没有启用 JWT 过滤器
- **问题**：虽然设置了 `permitAll()`，但是 JWT 过滤器被注释掉了
- **影响**：即使 token 过期，也不会被正确验证和处理

## 修复内容

### 1. 增加 JWT Token 过期时间
**文件**：`Backend/paperhub/src/main/resources/application.properties`

**修改前**：
```properties
jwt.expires-in-seconds=36
```

**修改后**：
```properties
jwt.expires-in-seconds=3600
```

**说明**：从 36 秒改为 3600 秒（1小时），这样用户登录后可以正常使用 1 小时。

### 2. 启用 JWT 过滤器
**文件**：`Backend/paperhub/src/main/java/com/example/paperhub/config/SecurityConfig.java`

**修改前**：
```java
.authorizeHttpRequests(reg -> reg
    .anyRequest().permitAll() // 允许所有请求，不需要认证
);

// 不添加 JWT 过滤器
// .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class);
```

**修改后**：
```java
.authorizeHttpRequests(reg -> reg
    .requestMatchers("/auth/**").permitAll() // 允许所有以/auth开头的请求
    .requestMatchers("/ws/**").permitAll() // 允许WebSocket连接
    .requestMatchers(HttpMethod.GET, "/posts/health").permitAll() // 允许健康检查
    .requestMatchers(HttpMethod.GET, "/posts").permitAll() // 允许未登录用户查看帖子列表
    .requestMatchers(HttpMethod.GET, "/posts/*").permitAll() // 允许未登录用户查看帖子详情
    .requestMatchers(HttpMethod.GET, "/posts/*/comments").permitAll() // 允许未登录用户查看评论列表
    .anyRequest().authenticated() // 任何其他请求都需要认证
)
.addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class);
```

**说明**：
- 启用了 JWT 过滤器，确保所有需要认证的请求都会验证 token
- 配置了哪些接口需要认证，哪些不需要认证
- 创建评论、点赞等操作需要认证

## 配置说明

### 不需要认证的接口（permitAll）
- `/auth/**` - 认证相关接口（登录、注册等）
- `/ws/**` - WebSocket 连接
- `GET /posts/health` - 健康检查
- `GET /posts` - 查看帖子列表
- `GET /posts/*` - 查看帖子详情
- `GET /posts/*/comments` - 查看评论列表

### 需要认证的接口（authenticated）
- `POST /posts` - 创建帖子
- `POST /posts/{postId}/comments` - 创建评论
- `POST /posts/{postId}/like` - 点赞帖子
- `DELETE /posts/{postId}/like` - 取消点赞
- `POST /posts/{postId}/comments/{commentId}/like` - 点赞评论
- `DELETE /posts/{postId}/comments/{commentId}/like` - 取消点赞评论
- 其他所有需要认证的操作

## 测试建议

### 1. 正常流程测试
1. **登录**：使用正确的邮箱和密码登录
2. **查看帖子**：应该可以正常查看（不需要登录）
3. **创建评论**：应该可以正常创建（需要登录）
4. **连续创建多条评论**：应该都可以成功（token 有效期 1 小时）

### 2. Token 过期测试
1. **登录**：获取 token
2. **等待 1 小时**：让 token 过期
3. **创建评论**：应该返回 401 或 403 错误
4. **重新登录**：获取新的 token
5. **创建评论**：应该可以成功

### 3. 未登录测试
1. **不登录**：直接尝试创建评论
2. **应该返回**：401 或 403 错误，提示"未认证，请先登录"

## 注意事项

### 1. Token 过期时间
- **当前设置**：3600 秒（1小时）
- **可以根据需要调整**：
  - 开发环境：可以设置更长（如 86400 秒 = 24 小时）
  - 生产环境：建议设置合理的时间（如 3600 秒 = 1 小时）

### 2. 前端 Token 管理
- 前端应该保存 token 到 LocalStorage
- 如果收到 401 或 403 错误，应该提示用户重新登录
- 可以考虑实现自动刷新 token 的机制

### 3. 安全性
- JWT token 包含用户信息，应该妥善保管
- 不要在 URL 中传递 token
- 使用 HTTPS 传输 token

## 如果问题仍然存在

### 检查点1：Token 是否过期
查看后端日志，确认 token 是否过期：
```
Token无效，继续执行过滤器链
```

### 检查点2：用户是否已认证
查看后端日志，确认用户是否已认证：
```
=== 创建评论请求 ===
用户: null  // 如果为 null，说明未认证
```

### 检查点3：前端 Token 是否正确
检查前端是否正确发送 token：
- 查看浏览器开发者工具的 Network 标签
- 确认请求头中包含 `Authorization: Bearer <token>`

### 检查点4：后端配置是否正确
确认：
1. `application.properties` 中的 `jwt.expires-in-seconds=3600`
2. `SecurityConfig` 中已启用 JWT 过滤器
3. 后端服务已重启，新配置已生效

## 总结

- ✅ 已修复 JWT token 过期时间（从 36 秒改为 3600 秒）
- ✅ 已启用 JWT 过滤器
- ✅ 已配置需要认证的接口
- ✅ 已配置不需要认证的接口

现在用户登录后可以正常使用 1 小时，不会出现"发了一条评论就退出"的问题。

