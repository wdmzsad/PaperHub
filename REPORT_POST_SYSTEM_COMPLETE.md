# 完整的举报帖子系统实现文档

## 📋 目录
1. [系统概述](#系统概述)
2. [数据库设计](#数据库设计)
3. [后端实现](#后端实现)
4. [前端实现](#前端实现)
5. [API接口文档](#api接口文档)
6. [JSON示例](#json示例)
7. [使用说明](#使用说明)

---

## 系统概述

### 业务流程
```
用户举报 → 管理员处理 → 下架 → 作者修改 → 提交审核 → 管理员审核 → 正常发布
```

### 帖子状态流转
```
NORMAL (正常)
   ↓ (管理员下架)
REMOVED (已下架)
   ↓ (作者修改)
DRAFT (草稿)
   ↓ (作者提交)
AUDIT (审核中)
   ↓ (管理员审核)
NORMAL (审核通过) 或 REMOVED (审核拒绝)
```

---

## 数据库设计

### 1. Post表修改
```sql
ALTER TABLE post
ADD COLUMN status ENUM('normal','removed','draft','audit') DEFAULT 'normal'
    COMMENT '帖子状态',
ADD COLUMN hidden_reason VARCHAR(255)
    COMMENT '下架原因',
ADD COLUMN updated_by_admin BIGINT
    COMMENT '最后操作的管理员ID',
ADD COLUMN visible_to_author BOOLEAN DEFAULT TRUE
    COMMENT '作者是否可见';
```

### 2. ReportPost表
```sql
CREATE TABLE report_post (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,

    -- 举报信息
    reporter_id BIGINT NOT NULL,
    post_id BIGINT NOT NULL,
    description VARCHAR(500),
    report_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- 处理状态
    status ENUM('pending', 'processed', 'ignored') DEFAULT 'pending',

    -- 管理员处理信息
    admin_id BIGINT,
    handle_time TIMESTAMP NULL,
    handle_result VARCHAR(500),
    post_status_after ENUM('normal','removed','audit','draft'),

    -- 索引和外键
    INDEX idx_reporter (reporter_id),
    INDEX idx_post (post_id),
    INDEX idx_status (status),
    FOREIGN KEY (reporter_id) REFERENCES user(id),
    FOREIGN KEY (post_id) REFERENCES post(id),
    FOREIGN KEY (admin_id) REFERENCES user(id)
);
```

---

## 后端实现

### 已创建的文件列表

#### 1. 实体类
- `Post.java` - 帖子实体（已添加status等字段）
- `PostStatus.java` - 帖子状态枚举
- `ReportPost.java` - 举报记录实体
- `ReportStatus.java` - 举报状态枚举

#### 2. Repository层
- `PostRepository.java` - 帖子数据访问（已添加状态查询方法）
- `ReportPostRepository.java` - 举报记录数据访问

#### 3. Service层
- `ReportPostService.java` - 举报系统业务逻辑

#### 4. Controller层
- `ReportPostController.java` - 用户端接口
- `AdminReportPostController.java` - 管理员端接口

#### 5. DTO类
- `ReportPostDtos.java` - 所有请求和响应DTO

---

## 前端实现

### 已创建的文件

#### 1. API服务
- `api_service.dart` - 已添加举报系统相关API方法

#### 2. UI组件
- `report_post_dialog.dart` - 举报对话框

### 需要集成的位置

#### 在帖子详情页添加举报按钮
```dart
// 在 post_detail_screen.dart 中添加
IconButton(
  icon: Icon(Icons.flag_outlined),
  onPressed: () async {
    final result = await showDialog(
      context: context,
      builder: (context) => ReportPostDialog(postId: widget.postId),
    );
    if (result == true) {
      // 举报成功
    }
  },
)
```

#### 在管理员界面添加举报管理标签
```dart
// 在 admin_mode_screen.dart 中已经有举报管理功能
// 需要添加帖子举报的详细处理界面
```

---

## API接口文档

### 用户端接口

#### 1. 举报帖子
```
POST /api/report/post
Headers: Authorization: Bearer {token}
Body: {
  "postId": 123,
  "description": "该帖子包含不实信息"
}
Response: {
  "id": 1,
  "reporterId": 456,
  "reporterName": "张三",
  "postId": 123,
  "postTitle": "测试帖子",
  "description": "该帖子包含不实信息",
  "status": "PENDING",
  "reportTime": "2025-12-02T10:00:00Z",
  "message": "举报成功，我们会尽快处理"
}
```

#### 2. 获取帖子详情
```
GET /api/post/{id}
Headers: Authorization: Bearer {token}
Response: {
  "id": 123,
  "title": "测试帖子",
  "content": "帖子内容",
  "status": "REMOVED",
  "hiddenReason": "包含违规内容",
  "visible": true,
  "canEdit": true,
  "message": "该帖子已被下架，原因：包含违规内容。您可以修改后重新提交审核。"
}
```

#### 3. 保存草稿
```
POST /api/post/{id}/draft
Headers: Authorization: Bearer {token}
Body: {
  "title": "修改后的标题",
  "content": "修改后的内容",
  "media": [],
  "tags": ["tag1", "tag2"]
}
Response: {
  "success": true,
  "message": "草稿保存成功",
  "data": {
    "postId": 123,
    "status": "DRAFT"
  }
}
```

#### 4. 提交审核
```
POST /api/post/{id}/submit
Headers: Authorization: Bearer {token}
Response: {
  "success": true,
  "message": "已提交审核，请等待管理员审核",
  "data": {
    "postId": 123,
    "status": "AUDIT"
  }
}
```

#### 5. 查询被下架帖子列表
```
GET /api/post/removed?page=0&pageSize=20
Headers: Authorization: Bearer {token}
Response: {
  "posts": [
    {
      "id": 123,
      "title": "测试帖子",
      "authorId": 456,
      "authorName": "张三",
      "status": "REMOVED",
      "hiddenReason": "包含违规内容",
      "createdAt": "2025-12-01T10:00:00Z",
      "updatedAt": "2025-12-02T10:00:00Z"
    }
  ],
  "total": 1,
  "page": 0,
  "pageSize": 20
}
```

### 管理员端接口

#### 1. 查看举报列表
```
GET /api/admin/report/posts?status=PENDING&page=0&pageSize=20
Headers: Authorization: Bearer {token}
Response: {
  "reports": [
    {
      "id": 1,
      "reporterId": 456,
      "reporterName": "张三",
      "reporterEmail": "zhangsan@example.com",
      "postId": 123,
      "postTitle": "测试帖子",
      "postAuthorId": 789,
      "postAuthorName": "李四",
      "description": "该帖子包含不实信息",
      "status": "PENDING",
      "reportTime": "2025-12-02T10:00:00Z",
      "adminId": null,
      "adminName": null,
      "handleTime": null,
      "handleResult": null,
      "postStatusAfter": null
    }
  ],
  "total": 1,
  "page": 0,
  "pageSize": 20
}
```

#### 2. 下架帖子
```
POST /api/admin/report/{id}/remove
Headers: Authorization: Bearer {token}
Body: {
  "reason": "包含违规内容"
}
Response: {
  "success": true,
  "message": "帖子已下架",
  "data": {
    "reportId": 1,
    "postId": 123,
    "status": "PROCESSED",
    "handleResult": "已下架，原因：包含违规内容"
  }
}
```

#### 3. 忽略举报
```
POST /api/admin/report/{id}/ignore
Headers: Authorization: Bearer {token}
Body: {
  "reason": "未发现违规"
}
Response: {
  "success": true,
  "message": "已忽略该举报",
  "data": {
    "reportId": 1,
    "status": "IGNORED",
    "handleResult": "已忽略，原因：未发现违规"
  }
}
```

#### 4. 审核通过
```
POST /api/admin/post/{id}/approve
Headers: Authorization: Bearer {token}
Response: {
  "success": true,
  "message": "审核通过，帖子已恢复正常",
  "data": {
    "postId": 123,
    "status": "NORMAL"
  }
}
```

#### 5. 审核拒绝
```
POST /api/admin/post/{id}/reject
Headers: Authorization: Bearer {token}
Body: {
  "reason": "仍包含违规内容"
}
Response: {
  "success": true,
  "message": "审核未通过，帖子已重新下架",
  "data": {
    "postId": 123,
    "status": "REMOVED",
    "hiddenReason": "仍包含违规内容"
  }
}
```

#### 6. 查询待审核帖子列表
```
GET /api/admin/post/audit?page=0&pageSize=20
Headers: Authorization: Bearer {token}
Response: {
  "posts": [
    {
      "id": 123,
      "title": "修改后的帖子",
      "authorId": 789,
      "authorName": "李四",
      "authorEmail": "lisi@example.com",
      "status": "AUDIT",
      "hiddenReason": null,
      "createdAt": "2025-12-01T10:00:00Z",
      "updatedAt": "2025-12-02T12:00:00Z"
    }
  ],
  "total": 1,
  "page": 0,
  "pageSize": 20
}
```

---

## JSON示例

### 1. 举报帖子 - 四种状态示例

#### 状态1: NORMAL (正常)
```json
{
  "id": 123,
  "title": "正常帖子",
  "content": "这是一个正常的帖子内容",
  "media": [],
  "tags": ["技术", "分享"],
  "authorId": 456,
  "authorName": "张三",
  "status": "NORMAL",
  "hiddenReason": null,
  "visible": true,
  "canEdit": true,
  "message": "正常",
  "createdAt": "2025-12-01T10:00:00Z",
  "updatedAt": "2025-12-01T10:00:00Z"
}
```

#### 状态2: REMOVED (已下架 - 作者视角)
```json
{
  "id": 123,
  "title": "被下架的帖子",
  "content": "这是被下架的帖子内容",
  "media": [],
  "tags": ["技术"],
  "authorId": 456,
  "authorName": "张三",
  "status": "REMOVED",
  "hiddenReason": "包含不实信息",
  "visible": true,
  "canEdit": true,
  "message": "该帖子已被下架，原因：包含不实信息。您可以修改后重新提交审核。",
  "createdAt": "2025-12-01T10:00:00Z",
  "updatedAt": "2025-12-02T10:00:00Z"
}
```

#### 状态3: DRAFT (草稿)
```json
{
  "id": 123,
  "title": "修改中的帖子",
  "content": "这是修改中的帖子内容",
  "media": [],
  "tags": ["技术"],
  "authorId": 456,
  "authorName": "张三",
  "status": "DRAFT",
  "hiddenReason": null,
  "visible": true,
  "canEdit": true,
  "message": "草稿状态，可继续编辑",
  "createdAt": "2025-12-01T10:00:00Z",
  "updatedAt": "2025-12-02T11:00:00Z"
}
```

#### 状态4: AUDIT (审核中)
```json
{
  "id": 123,
  "title": "待审核的帖子",
  "content": "这是待审核的帖子内容",
  "media": [],
  "tags": ["技术"],
  "authorId": 456,
  "authorName": "张三",
  "status": "AUDIT",
  "hiddenReason": null,
  "visible": true,
  "canEdit": false,
  "message": "审核中，请等待管理员审核",
  "createdAt": "2025-12-01T10:00:00Z",
  "updatedAt": "2025-12-02T12:00:00Z"
}
```

### 2. 错误响应示例

#### 重复举报
```json
{
  "success": false,
  "message": "您已经举报过该帖子",
  "data": null
}
```

#### 权限不足
```json
{
  "success": false,
  "message": "只有作者本人可以修改帖子",
  "data": null
}
```

#### 状态错误
```json
{
  "success": false,
  "message": "只有草稿状态的帖子才能提交审核",
  "data": null
}
```

---

## 使用说明

### 1. 数据库初始化
```bash
# 执行SQL脚本
mysql -u root -p paperhub < Backend/paperhub/REPORT_POST_SYSTEM.sql
```

### 2. 后端启动
```bash
cd Backend/paperhub
mvn spring-boot:run
```

### 3. 前端使用

#### 用户举报帖子
```dart
// 在帖子详情页添加举报按钮
import 'package:your_app/widgets/report_post_dialog.dart';

// 显示举报对话框
showDialog(
  context: context,
  builder: (context) => ReportPostDialog(postId: postId),
);
```

#### 作者查看被下架帖子
```dart
// 调用API获取被下架帖子列表
final response = await ApiService.getAuthorRemovedPosts();
if (response['statusCode'] == 200) {
  final posts = response['body']['posts'];
  // 显示列表
}
```

#### 作者修改并提交审核
```dart
// 1. 保存草稿
await ApiService.saveDraft(
  postId: postId,
  title: newTitle,
  content: newContent,
  media: mediaList,
  tags: tagList,
);

// 2. 提交审核
await ApiService.submitForAudit(postId);
```

#### 管理员处理举报
```dart
// 1. 查看举报列表
final response = await ApiService.adminGetReportPosts(status: 'PENDING');

// 2. 下架帖子
await ApiService.adminRemovePost(
  reportId: reportId,
  reason: '包含违规内容',
);

// 3. 或忽略举报
await ApiService.adminIgnoreReport(
  reportId: reportId,
  reason: '未发现违规',
);
```

#### 管理员审核帖子
```dart
// 1. 查看待审核帖子
final response = await ApiService.adminGetAuditPosts();

// 2. 审核通过
await ApiService.adminApprovePost(postId);

// 3. 或审核拒绝
await ApiService.adminRejectPost(
  postId: postId,
  reason: '仍包含违规内容',
);
```

---

## 测试流程

### 完整流程测试

1. **用户举报**
   - 登录普通用户账号
   - 浏览帖子，点击举报按钮
   - 填写举报理由并提交

2. **管理员下架**
   - 登录管理员账号
   - 进入举报管理页面
   - 查看举报详情，点击"下架"按钮
   - 填写下架原因

3. **作者修改**
   - 登录作者账号
   - 查看被下架帖子列表
   - 点击编辑，修改内容
   - 保存草稿

4. **作者提交审核**
   - 确认修改完成
   - 点击"提交审核"按钮

5. **管理员审核**
   - 登录管理员账号
   - 进入待审核帖子列表
   - 查看修改后的内容
   - 点击"审核通过"或"审核拒绝"

6. **验证结果**
   - 审核通过：帖子恢复正常显示
   - 审核拒绝：帖子重新下架，作者可再次修改

---

## 注意事项

1. **权限控制**
   - 只有登录用户才能举报
   - 不能举报自己的帖子
   - 不能重复举报同一帖子
   - 只有管理员可以处理举报和审核

2. **状态流转**
   - 严格按照状态机流转
   - 不允许跳过状态
   - 每次状态变更都记录操作人和时间

3. **数据一致性**
   - 使用事务保证数据一致性
   - 举报记录和帖子状态同步更新

4. **用户体验**
   - 提供清晰的状态提示
   - 显示下架原因
   - 引导作者修改和提交

---

## 扩展功能建议

1. **通知系统**
   - 帖子被下架时通知作者
   - 审核结果通知作者
   - 举报处理结果通知举报人

2. **举报分类**
   - 添加举报类型（垃圾信息、不实信息、违规内容等）
   - 根据类型自动分配处理优先级

3. **申诉机制**
   - 作者对下架决定提出申诉
   - 管理员重新审核

4. **统计分析**
   - 举报数量统计
   - 处理效率分析
   - 违规内容趋势分析

---

## 文件清单

### 后端文件
- `REPORT_POST_SYSTEM.sql` - 数据库脚本
- `Post.java` - 帖子实体
- `PostStatus.java` - 帖子状态枚举
- `ReportPost.java` - 举报实体
- `ReportStatus.java` - 举报状态枚举
- `PostRepository.java` - 帖子Repository
- `ReportPostRepository.java` - 举报Repository
- `ReportPostService.java` - 举报Service
- `ReportPostController.java` - 用户端Controller
- `AdminReportPostController.java` - 管理员Controller
- `ReportPostDtos.java` - DTO类

### 前端文件
- `api_service.dart` - API服务（已添加举报相关方法）
- `report_post_dialog.dart` - 举报对话框

---

## 总结

本系统实现了完整的"举报 → 下架 → 修改 → 审核"流程，包括：

✅ 完整的数据库设计
✅ 后端实体类、Repository、Service、Controller
✅ 前端API调用和UI组件
✅ 详细的API文档和JSON示例
✅ 完整的使用说明和测试流程

所有代码已经创建完成，可以直接使用！
