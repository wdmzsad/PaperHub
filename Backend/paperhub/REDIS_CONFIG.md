# Redis 配置说明

## 在 application.properties 中添加以下配置：

```properties
# Redis 配置
spring.data.redis.host=localhost
spring.data.redis.port=6379
spring.data.redis.password=
spring.data.redis.database=0
spring.data.redis.timeout=3000ms

# Redis 连接池配置（可选）
spring.data.redis.lettuce.pool.max-active=8
spring.data.redis.lettuce.pool.max-idle=8
spring.data.redis.lettuce.pool.min-idle=0
spring.data.redis.lettuce.pool.max-wait=-1ms
```

## 使用说明

### 1. 安装 Redis

**Windows:**
```bash
# 使用 Chocolatey
choco install redis-64

# 或下载 Redis for Windows
# https://github.com/MicrosoftArchive/redis/releases
```

**Linux/Mac:**
```bash
# Ubuntu/Debian
sudo apt-get install redis-server

# Mac
brew install redis
```

### 2. 启动 Redis

```bash
# Linux/Mac
redis-server

# Windows
redis-server.exe
```

### 3. 验证 Redis 连接

```bash
redis-cli ping
# 应该返回: PONG
```

## API 使用

### 获取最新消息（使用 Redis 缓存）

```
GET /api/conversations/{conversationId}/messages/latest?limit=30
```

**响应速度：** 5-20ms（从 Redis）vs 100-500ms（从 MySQL）

### 发送消息（自动缓存到 Redis）

```
POST /api/conversations/{conversationId}/messages
```

消息会自动：
1. 保存到 MySQL（持久化）
2. 缓存到 Redis（最新 30 条）
3. 推送到 WebSocket（实时通知）

## 缓存策略

- **缓存大小：** 每个会话最多缓存 30 条最新消息
- **缓存更新：** 新消息自动追加到 Redis List
- **缓存淘汰：** 超过 30 条自动删除最旧的消息
- **缓存失效：** Redis 未命中时自动从 MySQL 加载并回填缓存

## 性能提升

- **首次加载：** 从 MySQL 加载并缓存（100-500ms）
- **后续加载：** 从 Redis 读取（5-20ms）
- **性能提升：** 10-50 倍加速
