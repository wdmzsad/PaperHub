# 数据库表创建指南

## 问题：Unknown column 'p1_0.id' in 'field list'

这个错误表示数据库中的 `posts` 表不存在或者表结构与实体类不匹配。

## 解决方案

### 方案1：让Hibernate自动创建表（推荐）

1. **确保后端服务已停止**

2. **检查配置**
   - 确认 `application.properties` 中 `spring.jpa.hibernate.ddl-auto=update`
   - 确认数据库连接配置正确

3. **重新启动后端服务**
   - 在IntelliJ IDEA中运行 `PaperhubApplication.java`
   - Hibernate会自动创建所有表

4. **检查日志**
   - 查看控制台输出，应该能看到创建表的SQL语句
   - 例如：`create table posts ...`

### 方案2：手动删除并重建表（如果表已存在但结构不对）

**⚠️ 警告：这会删除现有数据！**

1. **连接到数据库**
   ```bash
   mysql -h 124.70.87.106 -u team -p paperHub
   ```

2. **删除旧表（如果存在）**
   ```sql
   DROP TABLE IF EXISTS post_tags;
   DROP TABLE IF EXISTS post_media;
   DROP TABLE IF EXISTS comment_likes;
   DROP TABLE IF EXISTS post_likes;
   DROP TABLE IF EXISTS comments;
   DROP TABLE IF EXISTS posts;
   ```

3. **重新启动后端服务**
   - Hibernate会自动创建新表

### 方案3：临时使用create模式（会删除所有数据）

**⚠️ 警告：这会删除所有数据！**

1. **修改 `application.properties`**
   ```properties
   spring.jpa.hibernate.ddl-auto=create
   ```

2. **启动后端服务**
   - 表会被删除并重新创建

3. **改回update模式**
   ```properties
   spring.jpa.hibernate.ddl-auto=update
   ```

## 验证表是否创建成功

### 方法1：查看后端日志
启动后端时，应该能看到类似以下的SQL语句：
```sql
create table posts (
    id bigint not null auto_increment,
    title varchar(255) not null,
    content text,
    author_id bigint not null,
    ...
    primary key (id)
)
```

### 方法2：直接查询数据库
```sql
SHOW TABLES;
DESCRIBE posts;
```

应该能看到以下表：
- `users`
- `posts`
- `post_media`
- `post_tags`
- `comments`
- `comment_likes`
- `post_likes`

## 表结构说明

### posts表
- `id` (bigint, 主键, 自增)
- `title` (varchar(255), 非空)
- `content` (text)
- `author_id` (bigint, 外键 -> users.id)
- `doi` (varchar(255))
- `journal` (varchar(255))
- `year` (int)
- `likes_count` (int, 默认0)
- `comments_count` (int, 默认0)
- `views_count` (int, 默认0)
- `created_at` (timestamp)
- `updated_at` (timestamp)

### comments表
- `id` (bigint, 主键, 自增)
- `post_id` (bigint, 外键 -> posts.id)
- `author_id` (bigint, 外键 -> users.id)
- `content` (text, 非空)
- `parent_id` (bigint, 外键 -> comments.id, 可为null)
- `reply_to_id` (bigint, 外键 -> users.id, 可为null)
- `likes_count` (int, 默认0)
- `created_at` (timestamp)
- `updated_at` (timestamp)

### post_likes表
- `id` (bigint, 主键, 自增)
- `post_id` (bigint, 外键 -> posts.id)
- `user_id` (bigint, 外键 -> users.id)
- `created_at` (timestamp)
- 唯一约束: (post_id, user_id)

### comment_likes表
- `id` (bigint, 主键, 自增)
- `comment_id` (bigint, 外键 -> comments.id)
- `user_id` (bigint, 外键 -> users.id)
- `created_at` (timestamp)
- 唯一约束: (comment_id, user_id)

## 常见问题

### Q: 为什么表没有被创建？
A: 可能的原因：
1. 后端服务没有启动
2. 数据库连接失败
3. 实体类没有被扫描到
4. 表已经存在但结构不对

### Q: 如何检查表是否存在？
A: 连接数据库后执行：
```sql
USE paperHub;
SHOW TABLES LIKE 'posts';
```

### Q: 表创建后还是报错？
A: 检查：
1. 表结构是否正确
2. 列名是否匹配（应该是下划线命名：likes_count, created_at等）
3. 是否有外键约束问题

## 下一步

表创建成功后：
1. 重新启动后端服务
2. 测试API：`http://localhost:8080/posts/health`
3. 在前端查看帖子列表

