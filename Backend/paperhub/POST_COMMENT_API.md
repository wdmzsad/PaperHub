# 帖子点赞和评论API文档

## 概述
本文档描述了帖子点赞和评论相关的后端API接口。所有接口都需要JWT认证（除了WebSocket连接）。

## 认证
所有REST API请求需要在请求头中携带JWT token：
```
Authorization: Bearer <token>
```

## API接口

### 1. 帖子点赞

#### 点赞帖子
- **URL**: `POST /posts/{postId}/like`
- **Headers**: `Authorization: Bearer <token>`
- **Response**: 
```json
{
  "likesCount": 123,
  "isLiked": true
}
```

#### 取消点赞帖子
- **URL**: `DELETE /posts/{postId}/like`
- **Headers**: `Authorization: Bearer <token>`
- **Response**: 
```json
{
  "likesCount": 122,
  "isLiked": false
}
```

### 2. 评论管理

#### 获取评论列表
- **URL**: `GET /posts/{postId}/comments?page=1&pageSize=20&sort=time`
- **Query Parameters**:
  - `page`: 页码，从1开始（默认: 1）
  - `pageSize`: 每页数量（默认: 20）
  - `sort`: 排序方式，`time`（时间）或 `hot`（热度）（默认: time）
- **Headers**: `Authorization: Bearer <token>` (可选，未登录用户也可以查看评论)
- **Response**: 
```json
{
  "comments": [
    {
      "id": "1",
      "author": {
        "id": 1,
        "email": "user@example.com",
        "name": "用户名",
        "avatar": "头像URL",
        "affiliation": "所属机构"
      },
      "content": "评论内容",
      "parentId": null,
      "replyTo": null,
      "likesCount": 5,
      "isLiked": false,
      "createdAt": "2025-01-01T00:00:00Z",
      "replies": [
        {
          "id": "2",
          "author": {...},
          "content": "回复内容",
          "parentId": "1",
          "replyTo": {...},
          "likesCount": 2,
          "isLiked": false,
          "createdAt": "2025-01-01T01:00:00Z",
          "replies": []
        }
      ]
    }
  ],
  "total": 100,
  "page": 1,
  "pageSize": 20
}
```

#### 创建评论
- **URL**: `POST /posts/{postId}/comments`
- **Headers**: `Authorization: Bearer <token>`
- **Request Body**:
```json
{
  "content": "评论内容",
  "parentId": null,  // 可选，用于回复（父评论ID）
  "replyToId": null  // 可选，被回复的用户ID
}
```
- **Response**: 返回创建的评论对象（格式同上）

#### 更新评论
- **URL**: `PUT /posts/{postId}/comments/{commentId}`
- **Headers**: `Authorization: Bearer <token>`
- **Request Body**:
```json
{
  "content": "更新后的评论内容"
}
```
- **Response**: 返回更新后的评论对象
- **权限**: 只有评论作者可以更新

#### 删除评论
- **URL**: `DELETE /posts/{postId}/comments/{commentId}`
- **Headers**: `Authorization: Bearer <token>`
- **Response**: `204 No Content`
- **权限**: 评论作者或帖子作者可以删除

#### 点赞评论
- **URL**: `POST /posts/{postId}/comments/{commentId}/like`
- **Headers**: `Authorization: Bearer <token>`
- **Response**: 
```json
{
  "likesCount": 6,
  "isLiked": true
}
```

#### 取消点赞评论
- **URL**: `DELETE /posts/{postId}/comments/{commentId}/like`
- **Headers**: `Authorization: Bearer <token>`
- **Response**: 
```json
{
  "likesCount": 5,
  "isLiked": false
}
```

## WebSocket实时推送

### 连接WebSocket
- **URL**: `ws://localhost:8080/ws/posts/{postId}`
- **协议**: 原生WebSocket（不是STOMP）

### 消息格式

#### 帖子点赞更新
```json
{
  "type": "like_update",
  "likesCount": 123,
  "isLiked": true
}
```

#### 评论点赞更新
```json
{
  "type": "comment_like_update",
  "commentId": "1",
  "likesCount": 6,
  "isLiked": true
}
```

#### 新评论
```json
{
  "type": "comment_created",
  "comment": {
    "id": "1",
    "author": {...},
    "content": "评论内容",
    ...
  }
}
```

#### 评论更新
```json
{
  "type": "comment_updated",
  "comment": {
    "id": "1",
    "author": {...},
    "content": "更新后的评论内容",
    ...
  }
}
```

#### 评论删除
```json
{
  "type": "comment_deleted",
  "commentId": "1"
}
```

## 数据库表结构

### posts表
- id: 主键
- title: 标题
- content: 内容
- author_id: 作者ID（外键）
- likes_count: 点赞数
- comments_count: 评论数
- views_count: 浏览数
- created_at: 创建时间
- updated_at: 更新时间

### comments表
- id: 主键
- post_id: 帖子ID（外键）
- author_id: 作者ID（外键）
- content: 评论内容
- parent_id: 父评论ID（外键，可为null）
- reply_to_id: 被回复的用户ID（外键，可为null）
- likes_count: 点赞数
- created_at: 创建时间
- updated_at: 更新时间

### post_likes表
- id: 主键
- post_id: 帖子ID（外键）
- user_id: 用户ID（外键）
- created_at: 创建时间
- 唯一约束: (post_id, user_id)

### comment_likes表
- id: 主键
- comment_id: 评论ID（外键）
- user_id: 用户ID（外键）
- created_at: 创建时间
- 唯一约束: (comment_id, user_id)

### users表
已扩展字段：
- name: 用户昵称（可选）
- avatar: 头像URL（可选）
- affiliation: 所属机构（可选）

## 注意事项

1. **JWT认证**: 所有REST API（除了获取评论列表）都需要JWT认证。WebSocket连接目前不需要认证，但可以在握手时添加认证逻辑。

2. **用户信息**: 如果用户没有设置name，系统会使用email的前缀部分作为默认name。

3. **权限控制**: 
   - 更新评论：只有评论作者可以更新
   - 删除评论：评论作者或帖子作者可以删除

4. **实时推送**: WebSocket会向所有连接到该帖子的客户端推送实时更新。

5. **数据库**: 使用JPA自动创建表结构，首次启动时会自动创建表。

## 前端集成

前端代码已经在 `Frontend/lib/screens/post_detail_screen.dart` 中实现了对应的接口调用。只需要：
1. 确保后端服务运行在 `http://localhost:8080`
2. 前端使用 `ApiService` 调用API
3. WebSocket连接地址为 `ws://localhost:8080/ws/posts/{postId}`

