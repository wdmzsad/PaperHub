# 枚举大小写问题修复指南

## 问题原因

**错误信息：**
```
No enum constant com.example.paperhub.post.PostStatus.normal
```

**根本原因：**
- 数据库枚举值定义为小写：`ENUM('normal','removed','draft','audit')`
- Java 枚举定义为大写：`NORMAL, REMOVED, DRAFT, AUDIT`
- JPA 使用 `@Enumerated(EnumType.STRING)` 时，会将 Java 枚举的名称（大写）存储到数据库
- 数据库列只接受小写值，导致类型不匹配

## 解决方案

### 步骤 1: 执行修复 SQL 脚本

```bash
mysql -u root -p paperhub < Backend/paperhub/FIX_ENUM_CASE.sql
```

或者手动执行：

```sql
-- 修改 post 表的 status 字段
ALTER TABLE post
MODIFY COLUMN status ENUM('NORMAL','REMOVED','DRAFT','AUDIT') DEFAULT 'NORMAL';

-- 如果表中已有数据，先更新现有数据
UPDATE post SET status = UPPER(status) WHERE status IS NOT NULL;

-- 修改 report_post 表的 post_status_after 字段
ALTER TABLE report_post
MODIFY COLUMN post_status_after ENUM('NORMAL','REMOVED','AUDIT','DRAFT');

-- 如果表中已有数据，先更新现有数据
UPDATE report_post
SET post_status_after = UPPER(post_status_after)
WHERE post_status_after IS NOT NULL;

-- 修改 report_post 表的 status 字段
ALTER TABLE report_post
MODIFY COLUMN status ENUM('PENDING','PROCESSED','IGNORED') DEFAULT 'PENDING';

-- 如果表中已有数据，先更新现有数据
UPDATE report_post
SET status = UPPER(status)
WHERE status IS NOT NULL;
```

### 步骤 2: 验证修复

```sql
-- 查看 post 表结构
SHOW CREATE TABLE post;

-- 查看 report_post 表结构
SHOW CREATE TABLE report_post;

-- 查看现有数据
SELECT id, title, status FROM post LIMIT 10;
SELECT id, status, post_status_after FROM report_post LIMIT 10;
```

### 步骤 3: 重启后端服务

```bash
cd Backend/paperhub
mvn clean
mvn spring-boot:run
```

## 验证测试

### 测试 1: 创建新帖子
```bash
# 应该成功，status 默认为 NORMAL
curl -X POST http://localhost:8080/api/posts \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "测试帖子",
    "content": "测试内容"
  }'
```

### 测试 2: 查询帖子
```bash
# 应该成功返回帖子详情
curl http://localhost:8080/api/post/1 \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### 测试 3: 举报帖子
```bash
# 应该成功创建举报记录
curl -X POST http://localhost:8080/api/report/post \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "postId": 1,
    "description": "测试举报"
  }'
```

## 常见问题

### Q1: 如果表中已有数据怎么办？

**A:** 先更新现有数据为大写，再修改列定义：

```sql
-- 更新现有数据
UPDATE post SET status = UPPER(status);
UPDATE report_post SET status = UPPER(status);
UPDATE report_post SET post_status_after = UPPER(post_status_after);

-- 然后执行修复脚本
```

### Q2: 为什么不把 Java 枚举改成小写？

**A:** Java 枚举约定使用大写，修改数据库更符合规范。

### Q3: 如果使用了 Flyway 或 Liquibase 怎么办？

**A:** 创建新的迁移文件：

```sql
-- V2__fix_enum_case.sql
ALTER TABLE post
MODIFY COLUMN status ENUM('NORMAL','REMOVED','DRAFT','AUDIT') DEFAULT 'NORMAL';

ALTER TABLE report_post
MODIFY COLUMN status ENUM('PENDING','PROCESSED','IGNORED') DEFAULT 'PENDING';

ALTER TABLE report_post
MODIFY COLUMN post_status_after ENUM('NORMAL','REMOVED','AUDIT','DRAFT');
```

## 预防措施

### 1. 数据库设计时使用大写枚举

```sql
-- ✅ 推荐
ENUM('NORMAL','REMOVED','DRAFT','AUDIT')

-- ❌ 不推荐
ENUM('normal','removed','draft','audit')
```

### 2. JPA 实体类使用 @Enumerated(EnumType.STRING)

```java
@Enumerated(EnumType.STRING)
@Column(name = "status")
private PostStatus status;
```

### 3. 测试时检查枚举值

```java
@Test
void testPostStatusMapping() {
    Post post = new Post();
    post.setStatus(PostStatus.NORMAL);
    postRepository.save(post);

    Post saved = postRepository.findById(post.getId()).orElseThrow();
    assertEquals(PostStatus.NORMAL, saved.getStatus());
}
```

## 修复完成检查清单

- [ ] 执行 FIX_ENUM_CASE.sql 脚本
- [ ] 验证数据库枚举值已改为大写
- [ ] 更新现有数据（如果有）
- [ ] 重启后端服务
- [ ] 测试创建帖子功能
- [ ] 测试查询帖子功能
- [ ] 测试举报功能
- [ ] 测试管理员功能

## 相关文件

- `Backend/paperhub/FIX_ENUM_CASE.sql` - 修复脚本
- `Backend/paperhub/REPORT_POST_SYSTEM.sql` - 已更新为大写枚举
- `Backend/paperhub/src/main/java/com/example/paperhub/post/PostStatus.java` - Java 枚举类
- `Backend/paperhub/src/main/java/com/example/paperhub/report/ReportStatus.java` - 举报状态枚举

## 总结

枚举大小写不匹配是一个常见的 JPA 问题。通过将数据库枚举值改为大写，可以与 Java 枚举保持一致，避免此类问题。

修复后，系统应该能够正常工作。如果仍有问题，请检查：
1. 数据库枚举值是否真的改为大写了
2. 现有数据是否已更新
3. 后端服务是否已重启
4. 是否有其他地方硬编码了小写的状态值
