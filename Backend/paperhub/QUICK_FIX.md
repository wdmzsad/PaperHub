# 快速修复：数据库表不存在问题

## 问题
错误：`Unknown column 'p1_0.id' in 'field list'`

## 原因
数据库中的 `posts` 表不存在或表结构与实体类不匹配。

## 解决方案（3步）

### 步骤1：重新启动后端服务
1. **停止当前运行的后端服务**（如果在运行）
2. **在IntelliJ IDEA中重新运行** `PaperhubApplication.java`
3. **观察启动日志**，应该能看到创建表的SQL语句

### 步骤2：检查表是否创建成功
在浏览器中访问：
```
http://localhost:8080/posts/health
```

如果返回：
```json
{
  "status": "ok",
  "message": "后端服务运行正常"
}
```
说明后端正常运行。

### 步骤3：测试获取帖子列表
在浏览器中访问：
```
http://localhost:8080/posts?page=1&pageSize=6
```

如果返回：
```json
{
  "posts": [],
  "total": 0,
  "page": 1,
  "pageSize": 6
}
```
说明表已创建成功（即使列表为空也是正常的）。

## 如果还是报错

### 方案A：手动删除旧表（如果有）

1. 连接到数据库：
   ```bash
   mysql -h 124.70.87.106 -u team -p paperHub
   ```

2. 删除旧表：
   ```sql
   DROP TABLE IF EXISTS post_tags;
   DROP TABLE IF EXISTS post_media;
   DROP TABLE IF EXISTS comment_likes;
   DROP TABLE IF EXISTS post_likes;
   DROP TABLE IF EXISTS comments;
   DROP TABLE IF EXISTS posts;
   ```

3. 重新启动后端服务

### 方案B：临时使用create模式

1. 修改 `application.properties`：
   ```properties
   spring.jpa.hibernate.ddl-auto=create
   ```

2. 启动后端服务

3. 改回 `update` 模式：
   ```properties
   spring.jpa.hibernate.ddl-auto=update
   ```

**⚠️ 注意：这会删除所有数据！**

## 验证

启动后端后，查看控制台日志，应该能看到类似以下的SQL：
```sql
create table posts (
    id bigint not null auto_increment,
    title varchar(255) not null,
    ...
    primary key (id)
) engine=InnoDB
```

## 已完成

✅ 所有实体类字段都已添加明确的列名映射
✅ 配置已优化
✅ 命名策略已简化

现在只需要重新启动后端服务，Hibernate会自动创建表。

