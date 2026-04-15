# PaperHub 后端 API 接口文档

## 目录
1. [认证接口 (Auth API)](#认证接口)
2. [用户相关接口 (User API)](#用户相关接口)
3. [帖子相关接口 (Post API)](#帖子相关接口)
4. [评论相关接口 (Comment API)](#评论相关接口)
5. [聊天相关接口 (Chat API)](#聊天相关接口)
6. [通知相关接口 (Notification API)](#通知相关接口)
7. [举报相关接口 (Report API)](#举报相关接口)
8. [管理员相关接口 (Admin API)](#管理员相关接口)
9. [搜索历史接口 (Search History API)](#搜索历史接口)
10. [浏览历史接口 (Browse History API)](#浏览历史接口)
11. [热搜接口 (Hot Search API)](#热搜接口)
12. [arXiv接口 (ArXiv API)](#arxiv接口)
13. [文件上传接口 (File Upload API)](#文件上传接口)

---

## 认证接口

### 1. 用户注册
- **接口名称**: 用户注册
- **请求路径**: `POST /auth/register`
- **功能**: 创建新账户，注册成功后发送验证邮件
- **请求体**:
```json
{
  "email": "user@example.com",
  "password": "password123"
}
```
- **请求参数说明**:
  - `email` (string, 必需): 用户邮箱，必须是有效的邮箱格式
  - `password` (string, 必需): 用户密码

- **返回值** (HTTP 201):
```json
{
  "message": "注册成功，已发送验证邮件"
}
```

- **错误情况**:
  - HTTP 400: 邮箱格式不合法或密码为空
  - HTTP 409: 邮箱已被注册

---

### 2. 发送验证邮件
- **接口名称**: 重新发送验证邮件
- **请求路径**: `POST /auth/send-verification`
- **功能**: 为已注册但未验证的账户重新发送验证邮件
- **请求体**:
```json
{
  "email": "user@example.com"
}
```
- **请求参数说明**:
  - `email` (string, 必需): 用户邮箱

- **返回值** (HTTP 200):
```json
{
  "message": "已重新发送验证邮件"
}
```

---

### 3. 验证邮箱
- **接口名称**: 验证邮箱
- **请求路径**: `POST /auth/verify`
- **功能**: 使用邮件中的验证码验证邮箱，完成注册
- **请求体**:
```json
{
  "email": "user@example.com",
  "code": "123456"
}
```
- **请求参数说明**:
  - `email` (string, 必需): 用户邮箱
  - `code` (string, 必需): 邮件中的验证码

- **返回值** (HTTP 200):
```json
{
  "message": "验证成功，注册完成"
}
```

---

### 4. 用户登录
- **接口名称**: 用户登录
- **请求路径**: `POST /auth/login`
- **功能**: 使用邮箱和密码登录，返回Access Token和Refresh Token
- **请求体**:
```json
{
  "email": "user@example.com",
  "password": "password123"
}
```
- **请求参数说明**:
  - `email` (string, 必需): 用户邮箱
  - `password` (string, 必需): 用户密码

- **返回值** (HTTP 200):
```json
{
  "message": "登录成功",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expiresIn": 3600,
  "refreshExpiresIn": 2592000
}
```
- **返回值说明**:
  - `token` (string): JWT Access Token
  - `refreshToken` (string): JWT Refresh Token
  - `expiresIn` (long): Access Token有效期（秒）
  - `refreshExpiresIn` (long): Refresh Token有效期（秒）

- **错误情况**:
  - HTTP 401: 邮箱未注册或密码错误
  - HTTP 403: 邮箱未验证

---

### 5. 刷新令牌
- **接口名称**: 刷新Access Token
- **请求路径**: `POST /auth/refresh`
- **功能**: 使用Refresh Token获取新的Access Token
- **请求体**:
```json
{
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```
- **请求参数说明**:
  - `refreshToken` (string, 必需): Refresh Token

- **返回值** (HTTP 200):
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expiresIn": 3600,
  "refreshExpiresIn": 2592000
}
```

- **错误情况**:
  - HTTP 401: Refresh Token无效
  - HTTP 403: 用户未验证

---

### 6. 请求重置密码
- **接口名称**: 请求重置密码
- **请求路径**: `POST /auth/request-reset`
- **功能**: 请求密码重置，发送重置邮件
- **请求体**:
```json
{
  "email": "user@example.com"
}
```
- **请求参数说明**:
  - `email` (string, 必需): 用户邮箱

- **返回值** (HTTP 200):
```json
{
  "message": "重置邮件已发送"
}
```

---

### 7. 重置密码
- **接口名称**: 重置密码
- **请求路径**: `POST /auth/reset-password`
- **功能**: 使用重置码和新密码重置用户密码
- **请求体**:
```json
{
  "email": "user@example.com",
  "code": "123456",
  "newPassword": "newpassword123"
}
```
- **请求参数说明**:
  - `email` (string, 必需): 用户邮箱
  - `code` (string, 必需): 重置邮件中的验证码
  - `newPassword` (string, 必需): 新密码

- **返回值** (HTTP 200):
```json
{
  "message": "密码已重置"
}
```

---

## 用户相关接口

### 1. 获取当前用户信息
- **接口名称**: 获取当前用户资料
- **请求路径**: `GET /users/me`
- **功能**: 获取已登录用户的个人资料
- **请求方式**: GET
- **认证**: 需要
- **返回值** (HTTP 200):
```json
{
  "id": 1,
  "email": "user@example.com",
  "role": "USER",
  "status": "NORMAL",
  "statusMessage": null,
  "displayName": "张三",
  "avatar": "https://example.com/avatar.jpg",
  "backgroundImage": "https://example.com/bg.jpg",
  "bio": "个人简介",
  "researchDirections": ["深度学习", "NLP"],
  "followingCount": 10,
  "followersCount": 50,
  "postsCount": 20,
  "favoritesCount": 30,
  "favoritesReceivedCount": 100,
  "likesCount": 200,
  "isFollowing": null,
  "isFollower": null,
  "hideFollowing": false,
  "hideFollowers": false,
  "publicFavorites": true
}
```

---

### 2. 获取其他用户资料
- **接口名称**: 获取用户公开资料
- **请求路径**: `GET /users/{userId}`
- **功能**: 获取指定用户的公开资料（受隐私设置影响）
- **请求方式**: GET
- **路径参数**:
  - `userId` (long, 必需): 目标用户ID

- **返回值** (HTTP 200): 同上
- **错误情况**:
  - HTTP 404: 用户不存在

---

### 3. 更新用户资料
- **接口名称**: 更新个人资料
- **请求路径**: `PUT /users/me`
- **功能**: 更新当前用户的个人资料
- **认证**: 需要
- **请求体**:
```json
{
  "name": "李四",
  "bio": "新的个人简介",
  "researchDirections": ["计算机视觉", "机器学习"],
  "backgroundImage": "https://example.com/new-bg.jpg"
}
```
- **请求参数说明**:
  - `name` (string, 必需): 用户昵称
  - `bio` (string, 可选): 个人简介
  - `researchDirections` (array, 可选): 研究方向列表
  - `backgroundImage` (string, 可选): 背景图URL

- **返回值** (HTTP 200): 同获取用户信息格式

---

### 4. 获取隐私设置
- **接口名称**: 获取隐私设置
- **请求路径**: `GET /users/me/privacy`
- **功能**: 获取当前用户的隐私设置
- **认证**: 需要
- **返回值** (HTTP 200):
```json
{
  "hideFollowing": false,
  "hideFollowers": false,
  "publicFavorites": true
}
```
- **返回值说明**:
  - `hideFollowing` (boolean): 是否隐藏关注列表
  - `hideFollowers` (boolean): 是否隐藏粉丝列表
  - `publicFavorites` (boolean): 收藏是否公开

---

### 5. 更新隐私设置
- **接口名称**: 更新隐私设置
- **请求路径**: `PUT /users/me/privacy`
- **功能**: 更新当前用户的隐私设置
- **认证**: 需要
- **请求体**:
```json
{
  "hideFollowing": true,
  "hideFollowers": false,
  "publicFavorites": false
}
```
- **返回值** (HTTP 200): 同获取隐私设置格式

---

### 6. 上传头像
- **接口名称**: 上传用户头像
- **请求路径**: `POST /users/me/avatar`
- **功能**: 上传头像图片并自动更新用户资料
- **认证**: 需要
- **请求参数**:
  - `file` (multipart/form-data, 必需): 图片文件

- **返回值** (HTTP 200):
```json
{
  "url": "https://example.com/avatars/uuid.jpg",
  "message": "头像上传成功"
}
```

- **错误情况**:
  - HTTP 400: 文件为空
  - HTTP 500: 上传失败

---

### 7. 上传背景图
- **接口名称**: 上传个人主页背景图
- **请求路径**: `POST /users/me/background`
- **功能**: 上传个人主页背景图并自动更新用户资料
- **认证**: 需要
- **请求参数**:
  - `file` (multipart/form-data, 必需): 图片文件

- **返回值** (HTTP 200):
```json
{
  "url": "https://example.com/profile-bg/uuid.jpg",
  "message": "背景图上传成功"
}
```

---

### 8. 关注用户
- **接口名称**: 关注指定用户
- **请求路径**: `POST /users/{userId}/follow`
- **功能**: 关注指定用户
- **认证**: 需要
- **路径参数**:
  - `userId` (long, 必需): 目标用户ID

- **返回值** (HTTP 200):
```json
{
  "isFollowing": true
}
```

---

### 9. 取消关注
- **接口名称**: 取消关注用户
- **请求路径**: `DELETE /users/{userId}/follow`
- **功能**: 取消关注指定用户
- **认证**: 需要
- **路径参数**:
  - `userId` (long, 必需): 目标用户ID

- **返回值** (HTTP 200):
```json
{
  "isFollowing": false
}
```

---

### 10. 获取关注列表
- **接口名称**: 获取用户关注列表
- **请求路径**: `GET /users/{userId}/following`
- **功能**: 获取用户关注的其他用户列表（受隐私设置影响）
- **路径参数**:
  - `userId` (long, 必需): 用户ID
- **查询参数**:
  - `page` (int, 默认0): 页码
  - `pageSize` (int, 默认20): 每页数量

- **返回值** (HTTP 200):
```json
{
  "users": [
    {
      "id": 2,
      "displayName": "李四",
      "avatar": "https://example.com/avatar2.jpg",
      ...
    }
  ],
  "total": 10,
  "page": 0,
  "pageSize": 20
}
```

- **错误情况**:
  - HTTP 403: 对方已隐藏关注列表
  - HTTP 404: 用户不存在

---

### 11. 获取粉丝列表
- **接口名称**: 获取用户粉丝列表
- **请求路径**: `GET /users/{userId}/followers`
- **功能**: 获取关注用户的其他用户列表（受隐私设置影响）
- **路径参数**:
  - `userId` (long, 必需): 用户ID
- **查询参数**:
  - `page` (int, 默认0): 页码
  - `pageSize` (int, 默认20): 每页数量

- **返回值** (HTTP 200): 同关注列表格式

---

### 12. 获取互相关注列表
- **接口名称**: 获取互相关注列表
- **请求路径**: `GET /users/{userId}/mutual`
- **功能**: 获取与用户互相关注的用户列表
- **路径参数**:
  - `userId` (long, 必需): 用户ID
- **查询参数**:
  - `page` (int, 默认0): 页码
  - `pageSize` (int, 默认20): 每页数量

- **返回值** (HTTP 200): 同关注列表格式

---

### 13. 获取用户收藏的帖子
- **接口名称**: 获取用户收藏列表
- **请求路径**: `GET /users/{userId}/favorites`
- **功能**: 获取用户收藏的帖子列表（受隐私设置影响）
- **路径参数**:
  - `userId` (long, 必需): 用户ID
- **查询参数**:
  - `page` (int, 默认1): 页码
  - `pageSize` (int, 默认20): 每页数量

- **返回值** (HTTP 200):
```json
{
  "posts": [
    {
      "id": "1",
      "title": "深度学习论文",
      ...
    }
  ],
  "total": 30,
  "page": 1,
  "pageSize": 20
}
```

- **错误情况**:
  - HTTP 403: 对方已隐藏收藏
  - HTTP 404: 用户不存在

---

### 14. 获取用户发布的帖子
- **接口名称**: 获取用户发布的帖子
- **请求路径**: `GET /users/{userId}/posts`
- **功能**: 获取用户发布的所有帖子
- **路径参数**:
  - `userId` (long, 必需): 用户ID
- **查询参数**:
  - `page` (int, 默认1): 页码
  - `pageSize` (int, 默认20): 每页数量

- **返回值** (HTTP 200): 同收藏列表格式

---

## 帖子相关接口

### 1. 健康检查
- **接口名称**: 健康检查
- **请求路径**: `GET /posts/health`
- **功能**: 检查后端服务是否正常运行
- **返回值** (HTTP 200):
```json
{
  "status": "ok",
  "message": "后端服务运行正常",
  "timestamp": "2025-01-01T12:00:00Z"
}
```

---

### 2. 获取帖子列表
- **接口名称**: 获取帖子列表
- **请求路径**: `GET /posts`
- **功能**: 获取帖子列表，可按标签筛选
- **查询参数**:
  - `page` (int, 默认1): 页码
  - `pageSize` (int, 默认20): 每页数量
  - `tag` (string, 可选): 标签过滤

- **返回值** (HTTP 200):
```json
{
  "posts": [
    {
      "id": "1",
      "title": "深度学习论文",
      "content": "论文内容...",
      "media": ["https://example.com/image.jpg"],
      "mainDiscipline": "信息科学（CS）",
      "subTags": ["深度学习", "神经网络"],
      "externalLinks": ["https://arxiv.org/abs/xxxx"],
      "author": {
        "id": 1,
        "email": "user@example.com",
        "name": "张三",
        "avatar": "https://example.com/avatar.jpg",
        "affiliation": "清华大学"
      },
      "likesCount": 15,
      "commentsCount": 5,
      "favoriteCount": 10,
      "viewsCount": 100,
      "isLiked": false,
      "isSaved": false,
      "status": "NORMAL",
      "hiddenReason": null,
      "updatedByAdmin": null,
      "visibleToAuthor": true,
      "doi": "10.1234/example",
      "journal": "Nature",
      "year": 2024,
      "arxivId": "2401.12345",
      "arxivAuthors": ["Author1", "Author2"],
      "arxivPublishedDate": "2024-01-15",
      "arxivCategories": ["cs.LG", "cs.AI"],
      "references": [2, 3, 4],
      "createdAt": "2025-01-01T12:00:00Z",
      "imageAspectRatio": 1.5,
      "imageNaturalWidth": 1200,
      "imageNaturalHeight": 800
    }
  ],
  "total": 150,
  "page": 1,
  "pageSize": 20
}
```

---

### 3. 获取推荐帖子
- **接口名称**: 获取推荐帖子
- **请求路径**: `GET /posts/recommendations`
- **功能**: 获取个性化推荐帖子（已登录用户）；未登录则返回最新帖子
- **认证**: 可选
- **查询参数**:
  - `page` (int, 默认1): 页码
  - `pageSize` (int, 默认20): 每页数量

- **返回值** (HTTP 200): 同帖子列表格式

---

### 4. 获取关注信息流
- **接口名称**: 获取关注信息流
- **请求路径**: `GET /posts/following`
- **功能**: 获取当前用户关注的作者发布的帖子
- **认证**: 需要
- **查询参数**:
  - `page` (int, 默认1): 页码
  - `pageSize` (int, 默认20): 每页数量

- **返回值** (HTTP 200): 同帖子列表格式
- **错误情况**:
  - HTTP 401: 未登录

---

### 5. 获取帖子详情
- **接口名称**: 获取帖子详情
- **请求路径**: `GET /posts/{postId}`
- **功能**: 获取帖子详细信息，自动增加浏览量
- **路径参数**:
  - `postId` (long, 必需): 帖子ID

- **返回值** (HTTP 200): 同帖子列表中的单个帖子格式
- **错误情况**:
  - HTTP 404: 帖子不存在

---

### 6. 创建帖子
- **接口名称**: 创建帖子
- **请求路径**: `POST /posts`
- **功能**: 创建新帖子
- **认证**: 需要
- **请求体**:
```json
{
  "title": "深度学习论文分析",
  "content": "详细的论文内容和分析...",
  "media": ["https://example.com/image1.jpg", "https://example.com/image2.jpg"],
  "mainDiscipline": "信息科学（CS）",
  "doi": "10.1234/example",
  "journal": "Nature",
  "year": 2024,
  "externalLinks": ["https://arxiv.org/abs/2401.12345"],
  "arxivId": "2401.12345",
  "arxivAuthors": ["Author1", "Author2"],
  "arxivPublishedDate": "2024-01-15",
  "arxivCategories": ["cs.LG", "cs.AI"],
  "references": [2, 3, 4],
  "status": "NORMAL"
}
```
- **请求参数说明**:
  - `title` (string, 必需): 帖子标题
  - `content` (string, 可选): 帖子内容
  - `media` (array, 可选): 媒体文件URL列表
  - `mainDiscipline` (string, 必需): 主分区（一级标签）
  - `doi` (string, 可选): DOI号
  - `journal` (string, 可选): 期刊名称
  - `year` (integer, 可选): 发布年份
  - `externalLinks` (array, 可选): 外部链接（仅支持http/https）
  - `arxivId` (string, 可选): arXiv ID
  - `arxivAuthors` (array, 可选): arXiv作者列表
  - `arxivPublishedDate` (string, 可选): 发布日期
  - `arxivCategories` (array, 可选): arXiv分类列表
  - `references` (array, 可选): 引用文献（帖子ID列表）
  - `status` (string, 默认"NORMAL"): 帖子状态（NORMAL 或 DRAFT）

- **返回值** (HTTP 201): 同帖子详情格式
- **错误情况**:
  - HTTP 401: 未登录
  - HTTP 400: 外部链接格式非法

---

### 7. 更新帖子
- **接口名称**: 编辑帖子
- **请求路径**: `PUT /posts/{postId}`
- **功能**: 编辑已发布的帖子（仅作者可编辑）
- **认证**: 需要
- **路径参数**:
  - `postId` (long, 必需): 帖子ID
- **请求体**: 同创建帖子

- **返回值** (HTTP 200): 同帖子详情格式
- **错误情况**:
  - HTTP 401: 未登录
  - HTTP 403: 非帖子作者
  - HTTP 404: 帖子不存在

---

### 8. 点赞帖子
- **接口名称**: 点赞帖子
- **请求路径**: `POST /posts/{postId}/like`
- **功能**: 对帖子点赞
- **认证**: 需要
- **路径参数**:
  - `postId` (long, 必需): 帖子ID

- **返回值** (HTTP 200):
```json
{
  "likesCount": 16,
  "isLiked": true
}
```

- **错误情况**:
  - HTTP 401: 未登录
  - HTTP 404: 帖子不存在

---

### 9. 取消点赞
- **接口名称**: 取消点赞帖子
- **请求路径**: `DELETE /posts/{postId}/like`
- **功能**: 取消对帖子的点赞
- **认证**: 需要
- **路径参数**:
  - `postId` (long, 必需): 帖子ID

- **返回值** (HTTP 200):
```json
{
  "likesCount": 15,
  "isLiked": false
}
```

---

### 10. 收藏帖子
- **接口名称**: 收藏帖子
- **请求路径**: `POST /posts/{postId}/favorite`
- **功能**: 收藏帖子
- **认证**: 需要
- **路径参数**:
  - `postId` (long, 必需): 帖子ID

- **返回值** (HTTP 200):
```json
{
  "favoritesCount": 11,
  "isSaved": true
}
```

---

### 11. 取消收藏
- **接口名称**: 取消收藏帖子
- **请求路径**: `DELETE /posts/{postId}/favorite`
- **功能**: 取消收藏帖子
- **认证**: 需要
- **路径参数**:
  - `postId` (long, 必需): 帖子ID

- **返回值** (HTTP 200):
```json
{
  "favoritesCount": 10,
  "isSaved": false
}
```

---

### 12. 搜索帖子
- **接口名称**: 搜索帖子
- **请求路径**: `GET /posts/search`
- **功能**: 按关键词或标签搜索帖子
- **查询参数**:
  - `q` (string, 必需): 搜索关键词
  - `type` (string, 默认"keyword"): 搜索类型（keyword-关键词搜索，tag-标签搜索）
  - `sort` (string, 默认"hot"): 排序方式（hot-热度排序，new-最新排序）
  - `page` (int, 默认1): 页码
  - `pageSize` (int, 默认20): 每页数量

- **返回值** (HTTP 200): 同帖子列表格式

---

### 13. 获取草稿列表
- **接口名称**: 获取用户草稿列表
- **请求路径**: `GET /posts/drafts`
- **功能**: 获取当前用户保存的所有草稿
- **认证**: 需要
- **查询参数**:
  - `page` (int, 默认1): 页码
  - `pageSize` (int, 默认20): 每页数量

- **返回值** (HTTP 200): 同帖子列表格式
- **错误情况**:
  - HTTP 401: 未登录

---

### 14. 保存为草稿
- **接口名称**: 保存帖子为草稿
- **请求路径**: `POST /posts/{postId}/save-draft`
- **功能**: 将帖子状态改为草稿
- **认证**: 需要
- **路径参数**:
  - `postId` (long, 必需): 帖子ID

- **返回值** (HTTP 200):
```json
{
  "message": "已保存为草稿",
  "postId": 1,
  "status": "DRAFT"
}
```

- **错误情况**:
  - HTTP 401: 未登录
  - HTTP 403: 非帖子作者
  - HTTP 404: 帖子不存在

---

### 15. 删除帖子
- **接口名称**: 删除帖子
- **请求路径**: `DELETE /posts/{postId}`
- **功能**: 删除已发布的帖子（仅作者可删除）
- **认证**: 需要
- **路径参数**:
  - `postId` (long, 必需): 帖子ID

- **返回值** (HTTP 204): 无内容
- **错误情况**:
  - HTTP 401: 未登录
  - HTTP 403: 非帖子作者
  - HTTP 404: 帖子不存在

---

### 16. 上传媒体文件
- **接口名称**: 上传媒体文件
- **请求路径**: `POST /posts/upload`
- **功能**: 上传图片或PDF文件
- **请求参数**:
  - `file` (multipart/form-data, 必需): 图片或PDF文件

- **返回值** (HTTP 200):
```json
{
  "message": "文件上传成功",
  "url": "https://example.com/file_url",
  "fileName": "1609459200000_image.jpg"
}
```

- **错误情况**:
  - HTTP 400: 不支持的文件类型
  - HTTP 500: 上传失败

---

### 17. 举报帖子（通过PostController）
- **接口名称**: 举报帖子
- **请求路径**: `POST /posts/{postId}/report`
- **功能**: 举报违规帖子（通过帖子API）
- **认证**: 需要
- **路径参数**:
  - `postId` (long, 必需): 帖子ID
- **请求体**:
```json
{
  "description": "包含不当内容"
}
```
- **请求参数说明**:
  - `description` (string, 必需): 举报原因说明

- **返回值** (HTTP 200):
```json
{
  "success": true,
  "message": "举报成功，我们会尽快处理",
  "reportId": 1
}
```

- **错误情况**:
  - HTTP 401: 未登录
  - HTTP 400: 举报描述为空

---

## 评论相关接口

### 1. 获取评论列表
- **接口名称**: 获取帖子评论列表
- **请求路径**: `GET /posts/{postId}/comments`
- **功能**: 获取帖子的所有评论（包含回复）
- **路径参数**:
  - `postId` (long, 必需): 帖子ID
- **查询参数**:
  - `page` (int, 默认1): 页码
  - `pageSize` (int, 默认20): 每页数量
  - `sort` (string, 默认"time"): 排序方式（time 或 hot）

- **返回值** (HTTP 200):
```json
{
  "comments": [
    {
      "id": "1",
      "author": {
        "id": 2,
        "email": "user2@example.com",
        "name": "李四",
        "avatar": "https://example.com/avatar2.jpg",
        "affiliation": "北京大学"
      },
      "content": "这篇论文很有意思",
      "parentId": null,
      "replyTo": null,
      "likesCount": 5,
      "isLiked": false,
      "createdAt": "2025-01-01T12:00:00Z",
      "replies": [
        {
          "id": "2",
          "author": {
            "id": 1,
            "email": "user@example.com",
            "name": "张三",
            "avatar": "https://example.com/avatar.jpg",
            "affiliation": "清华大学"
          },
          "content": "@李四 很高兴你也喜欢",
          "parentId": "1",
          "replyTo": {
            "id": 2,
            "name": "李四"
          },
          "likesCount": 2,
          "isLiked": false,
          "createdAt": "2025-01-01T13:00:00Z",
          "replies": [],
          "mentions": []
        }
      ],
      "mentions": []
    }
  ],
  "total": 10,
  "page": 1,
  "pageSize": 20
}
```

---

### 2. 创建评论
- **接口名称**: 创建评论/回复
- **请求路径**: `POST /posts/{postId}/comments`
- **功能**: 创建新评论或回复
- **认证**: 需要
- **路径参数**:
  - `postId` (long, 必需): 帖子ID
- **请求体**:
```json
{
  "content": "这篇论文很有启发",
  "parentId": null,
  "replyToId": null,
  "mentionIds": [2, 3]
}
```
- **请求参数说明**:
  - `content` (string, 必需): 评论内容
  - `parentId` (long, 可选): 父评论ID（为null则为顶级评论）
  - `replyToId` (long, 可选): 被回复用户的ID
  - `mentionIds` (array, 可选): 被@的用户ID列表

- **返回值** (HTTP 201): 同评论对象格式
- **错误情况**:
  - HTTP 401: 未登录
  - HTTP 404: 帖子不存在

---

### 3. 更新评论
- **接口名称**: 编辑评论
- **请求路径**: `PUT /posts/{postId}/comments/{commentId}`
- **功能**: 编辑已发布的评论（仅作者可编辑）
- **认证**: 需要
- **路径参数**:
  - `postId` (long, 必需): 帖子ID
  - `commentId` (long, 必需): 评论ID
- **请求体**:
```json
{
  "content": "修改后的评论内容"
}
```

- **返回值** (HTTP 200): 同评论对象格式
- **错误情况**:
  - HTTP 401: 未登录
  - HTTP 403: 非评论作者
  - HTTP 404: 评论不存在

---

### 4. 删除评论
- **接口名称**: 删除评论
- **请求路径**: `DELETE /posts/{postId}/comments/{commentId}`
- **功能**: 删除评论及其所有回复
- **认证**: 需要
- **路径参数**:
  - `postId` (long, 必需): 帖子ID
  - `commentId` (long, 必需): 评论ID

- **返回值** (HTTP 204): 无内容
- **错误情况**:
  - HTTP 401: 未登录
  - HTTP 403: 非评论作者
  - HTTP 404: 评论不存在

---

### 5. 点赞评论
- **接口名称**: 点赞评论
- **请求路径**: `POST /posts/{postId}/comments/{commentId}/like`
- **功能**: 对评论点赞
- **认证**: 需要
- **路径参数**:
  - `postId` (long, 必需): 帖子ID
  - `commentId` (long, 必需): 评论ID

- **返回值** (HTTP 200):
```json
{
  "likesCount": 6,
  "isLiked": true
}
```

---

### 6. 取消点赞评论
- **接口名称**: 取消点赞评论
- **请求路径**: `DELETE /posts/{postId}/comments/{commentId}/like`
- **功能**: 取消对评论的点赞
- **认证**: 需要
- **路径参数**:
  - `postId` (long, 必需): 帖子ID
  - `commentId` (long, 必需): 评论ID

- **返回值** (HTTP 200):
```json
{
  "likesCount": 5,
  "isLiked": false
}
```

---

## 聊天相关接口

### 1. 获取会话列表
- **接口名称**: 获取当前用户的所有会话
- **请求路径**: `GET /api/conversations`
- **功能**: 获取当前登录用户的所有私聊会话列表
- **认证**: 需要
- **返回值** (HTTP 200):
```json
[
  {
    "id": 1,
    "displayName": "李四",
    "lastMessage": "好的，明天见",
    "unreadCount": 2,
    "avatar": "https://example.com/avatar2.jpg",
    "isOnline": true
  }
]
```

- **错误情况**:
  - HTTP 400: 未通过认证

---

### 2. 创建或获取私聊会话
- **接口名称**: 创建或获取私聊会话
- **请求路径**: `POST /api/conversations`
- **功能**: 与指定用户创建或获取私聊会话
- **认证**: 需要
- **请求体**:
```json
{
  "targetUserId": 2
}
```
- **请求参数说明**:
  - `targetUserId` (long, 必需): 目标用户ID

- **返回值** (HTTP 200):
```json
{
  "id": 1,
  "displayName": "李四",
  "lastMessage": null,
  "unreadCount": 0,
  "avatar": "https://example.com/avatar2.jpg",
  "isOnline": false
}
```

- **错误情况**:
  - HTTP 400: 目标用户不存在或未通过认证

---

### 3. 上传聊天文件
- **接口名称**: 上传聊天文件
- **请求路径**: `POST /api/upload/chat-file`
- **功能**: 上传聊天中使用的文件（图片、视频、文档等）
- **认证**: 需要
- **请求参数**:
  - `file` (multipart/form-data, 必需): 文件

- **返回值** (HTTP 200):
```json
{
  "url": "https://example.com/chat-files/uuid.jpg",
  "fileName": "image.jpg",
  "fileSize": 102400,
  "message": "文件上传成功"
}
```

- **支持的文件类型**: jpg, jpeg, png, gif, mp3, wav, mp4, pdf, doc, docx, txt, zip, rar, ppt, pptx, xls, xlsx, csv, 7z, exe, m4a, ogg, aac, webm

- **文件大小限制**: 50MB

- **错误情况**:
  - HTTP 401: 未登录
  - HTTP 400: 文件为空或不支持的文件类型
  - HTTP 413: 文件过大

---

## 通知相关接口

### 1. 获取未读通知数量
- **接口名称**: 获取未读通知数量
- **请求路径**: `GET /notifications/unread-count`
- **功能**: 获取各类型未读通知的数量
- **认证**: 需要
- **返回值** (HTTP 200):
```json
{
  "likes": 5,
  "follows": 2,
  "comments": 3
}
```

---

### 2. 获取赞和收藏通知
- **接口名称**: 获取赞和收藏通知
- **请求路径**: `GET /notifications/likes`
- **功能**: 获取点赞和收藏通知列表
- **认证**: 需要
- **查询参数**:
  - `page` (int, 默认0): 页码
  - `pageSize` (int, 默认20): 每页数量

- **返回值** (HTTP 200):
```json
{
  "notifications": [
    {
      "id": 1,
      "type": "LIKE",
      "actor": {
        "id": 2,
        "name": "李四",
        "avatar": "https://example.com/avatar2.jpg"
      },
      "targetType": "POST",
      "targetId": 10,
      "targetTitle": "深度学习论文分析",
      "createdAt": "2025-01-01T12:00:00Z"
    }
  ],
  "total": 5,
  "page": 0,
  "pageSize": 20
}
```

---

### 3. 获取关注通知
- **接口名称**: 获取关注通知
- **请求路径**: `GET /notifications/follows`
- **功能**: 获取新增粉丝通知列表
- **认证**: 需要
- **查询参数**:
  - `page` (int, 默认0): 页码
  - `pageSize` (int, 默认20): 每页数量

- **返回值** (HTTP 200):
```json
{
  "notifications": [
    {
      "id": 2,
      "type": "FOLLOW",
      "actor": {
        "id": 3,
        "name": "王五",
        "avatar": "https://example.com/avatar3.jpg"
      },
      "targetType": "USER",
      "targetId": 1,
      "targetTitle": null,
      "createdAt": "2025-01-01T11:00:00Z"
    }
  ],
  "total": 2,
  "page": 0,
  "pageSize": 20
}
```

---

## 举报相关接口

### 1. 举报帖子
- **接口名称**: 举报不良帖子
- **请求路径**: `POST /api/report/post`
- **功能**: 举报违规帖子
- **认证**: 需要
- **请求体**:
```json
{
  "postId": 10,
  "description": "包含不当内容"
}
```
- **请求参数说明**:
  - `postId` (long, 必需): 帖子ID
  - `description` (string, 必需): 举报原因说明

- **返回值** (HTTP 200):
```json
{
  "id": 1,
  "reporterId": 1,
  "reporterName": "张三",
  "postId": 10,
  "postTitle": "违规帖子",
  "description": "包含不当内容",
  "status": "PENDING",
  "reportTime": "2025-01-01T12:00:00Z",
  "message": "举报成功，我们会尽快处理"
}
```

---

### 2. 获取帖子详情（举报相关）
- **接口名称**: 获取帖子详情
- **请求路径**: `GET /api/post/{id}`
- **功能**: 获取帖子详情（根据状态返回不同内容）
- **路径参数**:
  - `id` (long, 必需): 帖子ID

- **返回值** (HTTP 200):
```json
{
  "id": 10,
  "title": "默认展示帖子",
  "content": "帖子内容",
  "media": [],
  "tags": [],
  "authorId": 1,
  "authorName": "张三",
  "status": "NORMAL",
  "hiddenReason": null,
  "isVisible": true,
  "isCanEdit": true,
  "message": "帖子正常",
  "createdAt": "2025-01-01T12:00:00Z",
  "updatedAt": "2025-01-01T12:00:00Z"
}
```

---

### 3. 举报用户
- **接口名称**: 举报不良用户
- **请求路径**: `POST /api/report/user/{userId}`
- **功能**: 举报违规用户
- **认证**: 需要
- **路径参数**:
  - `userId` (long, 必需): 被举报用户ID
- **请求体**:
```json
{
  "reason": "恶意骚扰"
}
```

- **返回值** (HTTP 200):
```json
{
  "success": true,
  "message": "举报成功"
}
```

- **错误情况**:
  - HTTP 400: 不能举报管理员、不能举报自己或已先前举报
  - HTTP 404: 用户不存在

---

## 管理员相关接口

### 1. 搜索用户（管理员）
- **接口名称**: 管理员查询用户列表
- **请求路径**: `GET /admin/users`
- **功能**: 管理员查询和过滤用户
- **认证**: 需要（管理员权限）
- **查询参数**:
  - `q` (string, 可选): 搜索关键词（用户名）
  - `status` (string, 可选): 状态过滤（NORMAL, BANNED, MUTED, AUDIT, NON_NORMAL）
  - `page` (int, 默认0): 页码
  - `pageSize` (int, 默认20): 每页数量

- **返回值** (HTTP 200):
```json
{
  "users": [
    {
      "id": 1,
      "email": "user@example.com",
      "name": "张三",
      "role": "USER",
      "status": "NORMAL"
    }
  ],
  "total": 100,
  "page": 0,
  "pageSize": 20
}
```

- **错误情况**:
  - HTTP 403: 不是管理员

---

### 2. 封禁用户
- **接口名称**: 封禁用户
- **请求路径**: `POST /admin/users/{userId}/ban`
- **功能**: 管理员封禁用户账户
- **认证**: 需要（管理员权限）
- **路径参数**:
  - `userId` (long, 必需): 用户ID

- **返回值** (HTTP 200):
```json
{
  "message": "用户已封禁"
}
```

---

### 3. 解除封禁
- **接口名称**: 解除用户封禁
- **请求路径**: `POST /admin/users/{userId}/unban`
- **功能**: 管理员解除用户封禁
- **认证**: 需要（管理员权限）
- **路径参数**:
  - `userId` (long, 必需): 用户ID

- **返回值** (HTTP 200):
```json
{
  "message": "已解除封禁"
}
```

---

### 4. 禁言用户
- **接口名称**: 禁言用户
- **请求路径**: `POST /admin/users/{userId}/mute`
- **功能**: 管理员禁言用户
- **认证**: 需要（管理员权限）
- **路径参数**:
  - `userId` (long, 必需): 用户ID
- **查询参数**:
  - `duration` (int, 必需): 禁言时长
  - `unit` (string, 必需): 时间单位（HOURS, DAYS, WEEKS）

- **返回值** (HTTP 200):
```json
{
  "message": "用户已禁言"
}
```

- **错误情况**:
  - HTTP 400: 禁言时长必须大于0

---

### 5. 查看所有举报
- **接口名称**: 查看帖子举报列表
- **请求路径**: `GET /api/admin/report/posts`
- **功能**: 管理员查看帖子举报列表
- **认证**: 需要（管理员权限）
- **查询参数**:
  - `status` (string, 可选): 举报状态过滤（PENDING, APPROVED, REJECTED）
  - `page` (int, 默认0): 页码
  - `pageSize` (int, 默认20): 每页数量

- **返回值** (HTTP 200):
```json
{
  "reports": [
    {
      "id": 1,
      "reporterId": 1,
      "reporterName": "张三",
      "reporterEmail": "user@example.com",
      "postId": 10,
      "postTitle": "违规帖子",
      "postAuthorId": 2,
      "postAuthorName": "李四",
      "description": "包含不当内容",
      "status": "PENDING",
      "reportTime": "2025-01-01T12:00:00Z",
      "adminId": null,
      "adminName": null,
      "handleTime": null,
      "handleResult": null,
      "postStatus": "NORMAL"
    }
  ],
  "total": 5,
  "page": 0,
  "pageSize": 20
}
```

- **错误情况**:
  - HTTP 403: 不是管理员

---

## 搜索历史接口

### 1. 获取搜索历史
- **接口名称**: 获取用户搜索历史
- **请求路径**: `GET /search-history`
- **功能**: 获取当前用户最近的搜索记录
- **认证**: 需要
- **查询参数**:
  - `limit` (int, 可选): 返回数量，默认最近20条

- **返回值** (HTTP 200):
```json
{
  "items": [
    {
      "id": 1,
      "keyword": "深度学习",
      "searchType": "keyword",
      "searchCount": 5,
      "createdAt": "2025-01-01T12:00:00Z",
      "updatedAt": "2025-01-01T12:05:00Z"
    }
  ],
  "count": 1,
  "total": 10,
  "timestamp": "2025-01-01T12:05:00Z"
}
```

---

### 2. 记录搜索
- **接口名称**: 记录搜索行为
- **请求路径**: `POST /search-history`
- **功能**: 记录一次搜索操作
- **认证**: 需要
- **请求体**:
```json
{
  "keyword": "深度学习",
  "searchType": "keyword"
}
```
- **请求参数说明**:
  - `keyword` (string, 必需): 搜索关键词
  - `searchType` (string, 必需): 搜索类型（keyword, tag, author）

- **返回值** (HTTP 200):
```json
{
  "message": "搜索记录已保存"
}
```

---

## 浏览历史接口

### 1. 获取浏览历史
- **接口名称**: 获取用户浏览历史
- **请求路径**: `GET /browse-history`
- **功能**: 获取当前用户最近浏览的帖子
- **认证**: 需要
- **查询参数**:
  - `limit` (int, 默认50): 返回数量

- **返回值** (HTTP 200):
```json
{
  "items": [
    {
      "postId": 10,
      "title": "深度学习论文",
      "viewedAt": "2025-01-01T12:00:00Z"
    }
  ],
  "count": 1,
  "timestamp": "2025-01-01T12:05:00Z"
}
```

---

### 2. 记录浏览
- **接口名称**: 记录浏览行为
- **请求路径**: `POST /browse-history`
- **功能**: 记录用户浏览帖子
- **认证**: 需要
- **请求体**:
```json
{
  "postId": 10,
  "title": "深度学习论文"
}
```
- **请求参数说明**:
  - `postId` (long, 必需): 帖子ID
  - `title` (string, 可选): 帖子标题

- **返回值** (HTTP 200):
```json
{
  "message": "ok"
}
```

---

## 热搜接口

### 1. 获取热搜榜单
- **接口名称**: 获取热搜榜单
- **请求路径**: `GET /hot-searches`
- **功能**: 获取最新的热搜榜单
- **查询参数**:
  - `limit` (int, 默认20): 返回数量，最大50
  - `type` (string, 可选): 搜索类型筛选（keyword, tag, author）

- **返回值** (HTTP 200):
```json
{
  "items": [
    {
      "rank": 1,
      "keyword": "深度学习",
      "searchType": "keyword",
      "heat": 125.6,
      "tag": "热",
      "searchCount": 150,
      "uniqueUsers": 45,
      "growthRate": 1.8
    }
  ],
  "count": 20,
  "periodEnd": "2025-01-01T12:00:00Z",
  "timestamp": "2025-01-01T12:05:00Z"
}
```
- **返回值说明**:
  - `rank` (int): 排名
  - `keyword` (string): 搜索关键词
  - `searchType` (string): 搜索类型
  - `heat` (double): 热度值
  - `tag` (string): 标签（如"热"、"新"）
  - `searchCount` (int): 搜索总数
  - `uniqueUsers` (int): 搜索用户数
  - `growthRate` (double): 增长率

---

## arXiv接口

### 1. 获取arXiv论文元数据
- **接口名称**: 查询arXiv论文
- **请求路径**: `GET /arxiv`
- **功能**: 通过arXiv ID查询论文元数据
- **查询参数**:
  - `id` (string, 必需): arXiv ID（格式如：1512.03385或2301.12345）

- **返回值** (HTTP 200):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>ArXiv Query Results</title>
  <entry>
    <id>http://arxiv.org/abs/1512.03385v1</id>
    <title>ResNet: Deep Residual Learning for Image Recognition</title>
    <author>
      <name>Kaiming He</name>
    </author>
    <published>2015-12-10T18:37:48Z</published>
    <summary>Deep residual networks...</summary>
  </entry>
</feed>
```

- **错误情况**:
  - HTTP 400: arXiv ID不能为空

---

## 文件上传接口

### 帖子文件上传
- **接口名称**: 上传帖子中的媒体文件
- **请求路径**: `POST /posts/upload`
- **功能**: 上传图片或PDF文件到帖子
- **请求参数**:
  - `file` (multipart/form-data, 必需): 图片或PDF文件

- **支持的文件类型**: jpg, jpeg, png, gif, pdf

- **返回值** (HTTP 200):
```json
{
  "message": "文件上传成功",
  "url": "https://example.com/file_url",
  "fileName": "1609459200000_image.jpg"
}
```

---

## 通用错误响应

所有接口都可能返回以下错误：

### 401 Unauthorized（未认证）
```json
{
  "message": "未认证，请先登录"
}
```

### 403 Forbidden（无权限）
```json
{
  "message": "仅管理员可访问"
}
```

### 404 Not Found（资源不存在）
```json
{
  "message": "资源不存在"
}
```

### 500 Internal Server Error（服务器错误）
```json
{
  "message": "服务器内部错误"
}
```

---

## 认证方式

### 使用JWT Token
所有需要认证的接口都需要在请求头中包含：
```
Authorization: Bearer <token>
```

其中 `<token>` 是登录接口返回的 Access Token。

### Token刷新流程
1. 当 Access Token 过期时，使用 Refresh Token 调用 `/auth/refresh` 接口
2. 获取新的 Access Token 和 Refresh Token
3. 继续使用新的 Token 进行后续请求

---

## 数据分页

大多数列表接口都支持分页，分页参数如下：
- `page` (int): 页码（有些从1开始，有些从0开始，具体见各接口文档）
- `pageSize` (int): 每页数量

分页返回结果格式：
```json
{
  "data": [...],
  "total": 100,
  "page": 1,
  "pageSize": 20
}
```

---

## 注意事项

1. **时间格式**: 所有时间戳均为ISO 8601格式（如 `2025-01-01T12:00:00Z`）
2. **用户ID**: 用户系统中ID为 Long 类型
3. **帖子ID**: 在响应中通常以字符串形式返回（如 `"id": "1"`）
4. **CORS**: 大多数接口已配置CORS，允许跨域请求
5. **文件上传**: 使用 `multipart/form-data` 格式，文件参数名为 `file`
6. **隐私控制**: 用户的关注列表、粉丝列表、收藏等受其隐私设置影响
7. **WebSocket**: 聊天、评论等功能支持实时推送，使用WebSocket连接

---

# 重构指南

## 后端重构建议

### 1. 数据库设计
确保以下表结构完整：
- `users` - 用户表
- `posts` - 帖子表
- `comments` - 评论表
- `likes` - 点赞关系表
- `favorites` - 收藏关系表
- `user_follows` - 关注关系表
- `conversations` - 聊天会话表
- `notifications` - 通知表
- `reports` - 举报表
- `search_history` - 搜索历史表
- `browse_history` - 浏览历史表
- `hot_searches` - 热搜表

### 2. API分层架构
```
Controller -> Service -> Repository
   ↓           ↓            ↓
 处理HTTP    业务逻辑     数据访问
```

### 3. 异常处理
统一异常处理，返回标准错误响应

### 4. 验证和授权
- 使用JWT进行令牌认证
- 在Controller层进行权限校验
- 使用Spring Security进行角色管理

---

## 重构检查清单

在重构后端时，请确保以下功能完整实现：

- [ ] 用户认证和授权系统
- [ ] JWT Token生成和验证
- [ ] 帖子的CRUD操作及草稿管理
- [ ] 评论系统（包括回复、提及和嵌套显示）
- [ ] 点赞和收藏功能（帖子和评论）
- [ ] 用户关注系统（关注、粉丝、互相关注）
- [ ] 通知系统（赞、关注、评论通知）
- [ ] 搜索功能（关键词和标签搜索）
- [ ] 文件上传（到对象存储OBS）
- [ ] 隐私控制（关注列表、粉丝列表、收藏公开性）
- [ ] 管理员功能（用户管理、举报处理、用户封禁禁言）
- [ ] 聊天系统（会话管理、文件上传）
- [ ] 搜索和浏览历史记录
- [ ] 热搜榜单计算
- [ ] arXiv集成（查询论文元数据）
- [ ] 错误处理和日志记录
- [ ] 数据验证和清理
- [ ] 事务管理
- [ ] WebSocket实时推送
- [ ] 推荐算法（个性化帖子推荐）

---

## 应用场景和常见用户路径

### 1. 用户注册和登录流程
```
1. POST /auth/register 注册账户
   ↓ 发送验证邮件
2. POST /auth/verify 验证邮箱
3. POST /auth/login 登录获取Token
4. POST /auth/refresh 当Token过期时刷新
```

### 2. 帖子发布工作流
```
1. POST /posts/upload 上传媒体文件（可选）
2. POST /posts 创建并发布帖子
3. PUT /posts/{postId} 编辑帖子内容（可选）
4. POST /posts/{postId}/save-draft 保存为草稿（可选）
5. GET /posts/drafts 查看草稿列表
```

### 3. 社区互动流程
```
1. GET /posts 浏览首页帖子
2. GET /posts/{postId} 查看帖子详情
3. POST /posts/{postId}/comments 发布评论
4. POST /posts/{postId}/comments/{commentId}/like 点赞评论
5. POST /posts/{postId}/like 点赞帖子
6. POST /posts/{postId}/favorite 收藏帖子
7. POST /posts/{postId}/report 举报帖子（可选）
```

### 4. 用户关注和个人主页
```
1. GET /users/{userId} 查看用户主页
2. POST /users/{userId}/follow 关注用户
3. GET /users/{userId}/following 查看用户关注列表
4. GET /users/{userId}/followers 查看用户粉丝列表
5. GET /users/{userId}/favorites 查看用户收藏
6. GET /users/{userId}/posts 查看用户发布的帖子
```

### 5. 通知系统
```
1. GET /notifications/unread-count 获取未读通知数
2. GET /notifications/likes 查看点赞和收藏通知
3. GET /notifications/follows 查看关注通知
```

### 6. 搜索和发现
```
1. GET /posts/search 搜索帖子
2. GET /hot-searches 查看热搜榜单
3. POST /search-history 记录搜索
4. GET /search-history 查看搜索历史
5. POST /browse-history 记录浏览
6. GET /browse-history 查看浏览历史
```

---

## API权限和访问控制矩阵

| 接口 | 认证需求 | 权限要求 | 说明 |
|------|--------|--------|------|
| 注册/登录/验证邮箱 | 无 | - | 所有人可访问 |
| 获取帖子列表/详情 | 无 | - | 所有人可访问 |
| 创建/编辑/删除帖子 | 需要 | 作者本人 | 仅作者可操作 |
| 点赞/收藏/评论 | 需要 | - | 已登录用户可操作 |
| 关注/取消关注 | 需要 | - | 已登录用户可操作 |
| 更新个人资料 | 需要 | 本人 | 仅本人可操作 |
| 上传头像/背景 | 需要 | 本人 | 仅本人可操作 |
| 管理员查询用户 | 需要 | 管理员 | 仅管理员可操作 |
| 管理员封禁/禁言 | 需要 | 管理员 | 仅管理员可操作 |
| 查看举报列表 | 需要 | 管理员 | 仅管理员可操作 |

---

## HTTP状态码说明

| 状态码 | 说明 | 常见场景 |
|--------|------|---------|
| 200 | OK | 请求成功 |
| 201 | Created | 创建资源成功（POST） |
| 204 | No Content | 删除成功，无返回内容（DELETE） |
| 400 | Bad Request | 请求参数错误 |
| 401 | Unauthorized | 未登录或Token无效 |
| 403 | Forbidden | 无权限操作 |
| 404 | Not Found | 资源不存在 |
| 409 | Conflict | 冲突（如重复注册） |
| 500 | Internal Server Error | 服务器错误 |

---

## 常用的请求头

```
Authorization: Bearer <token>          # JWT认证令牌
Content-Type: application/json         # 请求体数据格式
Accept: application/json               # 期望响应数据格式
```

---

## 文件上传限制和支持

| 项目 | 限制和说明 |
|------|----------|
| **头像最大尺寸** | 10MB |
| **背景图最大尺寸** | 10MB |
| **帖子媒体最大尺寸** | 50MB |
| **聊天文件最大尺寸** | 50MB |
| **图片格式** | jpg, jpeg, png, gif |
| **文档格式** | pdf, doc, docx, txt, ppt, pptx, xls, xlsx, csv |
| **媒体格式** | mp3, wav, mp4, m4a, ogg, aac, webm |
| **压缩格式** | zip, rar, 7z |
| **其他** | exe（用于聊天文件） |

---

## 数据库主要表结构说明

### users 表
- **主键**: id (Long)
- **字段**: email, password_hash, name, avatar, bio, created_at, updated_at
- **枚举**: role (USER, ADMIN, SUPER_ADMIN), status (NORMAL, BANNED, MUTED, AUDIT)
- **额外字段**: profile_background, research_directions, hide_following, hide_followers, public_favorites

### posts 表
- **主键**: id (Long)
- **字段**: title, content, author_id, created_at, updated_at
- **JSON字段**: media, sub_tags, external_links, arxiv_authors, arxiv_categories
- **计数字段**: likes_count, comments_count, favorites_count, views_count
- **论文相关**: doi, journal, year, arxiv_id, arxiv_published_date
- **其他**: status (NORMAL, DRAFT, HIDDEN), hidden_reason, references (JSON)

### comments 表
- **主键**: id (Long)
- **字段**: post_id, author_id, content, created_at, updated_at
- **层级**: parent_id, reply_to_id
- **其他**: mention_ids (JSON), likes_count

### likes 表
- **主键**: id (Long)
- **字段**: user_id, post_id, created_at
- **关系**: comment_id (可选，区分是否为评论点赞)

### favorites 表
- **主键**: id (Long)
- **字段**: user_id, post_id, created_at

### user_follows 表
- **主键**: id (Long)
- **字段**: follower_id, following_id, created_at

### notifications 表
- **主键**: id (Long)
- **字段**: recipient_id, type, actor_id, target_type, target_id, created_at
- **枚举**: type (LIKE, FOLLOW, COMMENT)

### conversations 表
- **主键**: id (Long)
- **字段**: participant1_id, participant2_id, created_at, updated_at, last_message, unread_count

### reports 表
- **主键**: id (Long)
- **字段**: reporter_id, reported_user_id/post_id, reason, created_at, admin_id, handle_time, handle_result
- **枚举**: status (PENDING, APPROVED, REJECTED), target_type (USER, POST)

---

## 前后端交互最佳实践

### 1. 错误处理策略
前端应根据HTTP状态码和返回的错误消息进行相应处理：
```javascript
// 错误处理示例
if (response.status === 401) {
  // 重定向到登录页面
  window.location.href = '/login';
} else if (response.status === 403) {
  // 显示"没有权限"提示
  showAlert('您没有权限执行此操作');
} else if (response.status === 404) {
  // 显示"资源不存在"提示
  showAlert('请求的资源不存在');
} else if (response.status === 500) {
  // 显示"服务器错误"提示
  showAlert('服务器出错，请稍后重试');
}
```

### 2. Token管理最佳实践
- 登录后保存token到本地存储或加密的Cookie中
- 每个请求都在Authorization请求头中携带token
- 当收到401响应时，自动使用refresh token获取新的access token
- 避免频繁刷新token，建议在快过期时主动刷新

### 3. 分页处理
- 记录当前页码和每页数量
- 在用户"加载更多"时，获取下一页数据并追加到现有列表
- 对于无限滚动列表，每次增加页码并追加到现有列表
- 避免在页码无效时的多余请求

### 4. WebSocket连接管理
- 登录成功后建立WebSocket连接
- 实现心跳机制保持连接活跃
- 连接断开自动重连（指数退避策略）
- 评论和聊天功能使用WebSocket推送

### 5. 文件上传优化
- 上传前进行本地验证（类型和大小）
- 显示上传进度条
- 支持断点续传（可选）
- 上传失败时自动重试

---

## 性能优化建议

### 1. 缓存策略
- **用户信息**: 可在本地缓存，修改时更新
- **热搜榜单**: 定期刷新（5-30分钟一次）
- **帖子列表**: 使用分页，避免一次加载过多
- **搜索历史**: 可本地缓存最近搜索

### 2. 请求优化
- 使用分页而不是一次加载所有数据
- 上传文件前进行本地验证
- 对于列表接口，合理设置pageSize（推荐20-50）
- 使用图片懒加载

### 3. 并发限制和防护
- 避免在短时间内发送大量相同请求
- 点赞和收藏应防止重复提交
- 搜索请求应有防抖处理（延迟300-500ms）
- 评论、回复应有频率限制

### 4. 数据库优化
- 为常查询字段建立索引
- 使用连接池管理数据库连接
- 考虑使用缓存中间件(如Redis)for热点数据
- 定期清理过期数据（如临时会话）

---

## 联系和支持

如有任何问题或需要进一步的API文档信息，请参考前端代码中的API调用实现或查看各个Controller类的源代码。

本文档最后更新时间：2025年3月23日  
文档版本：v1.0  
适用系统：PaperHub学术社交平台  


