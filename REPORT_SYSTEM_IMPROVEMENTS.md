# 用户举报系统完善总结

## 完成的功能

### 1. 通知系统集成 ✅

#### 后端改动
- **NotificationType.java**: 添加了3个新的通知类型
  - `POST_REMOVED`: 帖子被下架
  - `POST_APPROVED`: 帖子审核通过
  - `POST_REJECTED`: 帖子审核拒绝

- **NotificationService.java**: 添加了3个新的通知方法
  - `createPostRemovedNotification()`: 创建帖子被下架通知
  - `createPostApprovedNotification()`: 创建帖子审核通过通知
  - `createPostRejectedNotification()`: 创建帖子审核拒绝通知

- **ReportPostService.java**: 集成通知功能
  - 在`removePost()`方法中，下架帖子时发送通知给作者
  - 在`approvePost()`方法中，审核通过时发送通知给作者
  - 在`rejectPost()`方法中，审核拒绝时发送通知给作者

### 2. 帖子列表过滤逻辑 ✅

#### 后端改动
- **PostRepository.java**: 添加了新的查询方法
  - `findByStatusOrderByCreatedAtDesc()`: 按状态查询帖子
  - `findByAuthorIdAndStatusOrderByCreatedAtDesc()`: 按作者和状态查询帖子
  - 修改搜索查询，添加`AND p.status = 'NORMAL'`过滤条件

- **PostService.java**: 修改了帖子列表方法
  - `getPosts()`: 只返回NORMAL状态的帖子
  - `getPostsByAuthor()`: 只返回作者的NORMAL状态帖子
  - 搜索功能自动过滤非NORMAL状态的帖子

### 3. 前端举报对话框集成 ✅

#### 前端改动
- **post_detail_screen.dart**:
  - 添加了`import '../widgets/report_post_dialog.dart'`
  - 修改举报按钮的`onTap`事件，调用`ReportPostDialog`
  - 显示举报成功的提示信息

- **report_post_dialog.dart**: 已存在，功能完整
  - 提供举报理由输入框
  - 调用`ApiService.reportPost()`提交举报
  - 显示成功/失败提示

### 4. 管理员界面的举报处理功能 ✅

#### 前端改动
- **admin_mode_screen.dart**:
  - 修改`_loadReports()`方法，使用`ApiService.adminGetReportPosts()`
  - 修改举报列表显示，使用正确的字段名（reporterName, postTitle等）
  - 添加`_showPostReportDialog()`方法，显示举报处理对话框
  - 添加`_handleRemovePost()`方法，处理下架帖子操作
  - 添加`_handleIgnoreReport()`方法，处理忽略举报操作
  - 只有PENDING状态的举报才能处理

## 系统架构

### 完整的举报流程

```
用户举报 → 管理员处理 → 下架 → 作者修改 → 提交审核 → 管理员审核 → 正常发布
```

### 帖子状态流转

```
NORMAL (正常)
   ↓ (管理员下架)
REMOVED (已下架) + 通知作者
   ↓ (作者修改)
DRAFT (草稿)
   ↓ (作者提交)
AUDIT (审核中)
   ↓ (管理员审核)
NORMAL (审核通过) + 通知作者 或 REMOVED (审核拒绝) + 通知作者
```

## API接口

### 用户端接口
- `POST /api/report/post` - 举报帖子
- `GET /api/post/{id}` - 获取帖子详情（根据状态返回不同内容）
- `POST /api/post/{id}/draft` - 保存草稿
- `POST /api/post/{id}/submit` - 提交审核
- `GET /api/post/removed` - 查询被下架帖子列表

### 管理员端接口
- `GET /api/admin/report/posts` - 查看举报列表
- `POST /api/admin/report/{id}/remove` - 下架帖子
- `POST /api/admin/report/{id}/ignore` - 忽略举报
- `POST /api/admin/post/{id}/approve` - 审核通过
- `POST /api/admin/post/{id}/reject` - 审核拒绝
- `GET /api/admin/post/audit` - 查询待审核帖子列表
- `GET /api/admin/report/count` - 统计待处理举报数量

## 核心特性

### 1. 权限控制
- 只有登录用户才能举报
- 不能举报自己的帖子
- 不能重复举报同一帖子
- 只有管理员可以处理举报和审核

### 2. 状态管理
- 严格按照状态机流转
- 不允许跳过状态
- 每次状态变更都记录操作人和时间

### 3. 通知机制
- 帖子被下架时通知作者
- 审核结果通知作者
- 提供清晰的下架原因

### 4. 用户体验
- 提供清晰的状态提示
- 显示下架原因
- 引导作者修改和提交
- 只显示正常状态的帖子给普通用户

## 数据库设计

### Post表新增字段
- `status`: 帖子状态（NORMAL, REMOVED, DRAFT, AUDIT）
- `hidden_reason`: 下架原因
- `updated_by_admin`: 最后操作的管理员ID
- `visible_to_author`: 作者是否可见

### ReportPost表
- 举报信息：reporter_id, post_id, description, report_time
- 处理状态：status (PENDING, PROCESSED, IGNORED)
- 管理员处理信息：admin_id, handle_time, handle_result
- 帖子处理后的状态：post_status_after

## 文件清单

### 后端文件（已修改）
- `NotificationType.java` - 添加举报相关通知类型
- `NotificationService.java` - 添加举报通知方法
- `ReportPostService.java` - 集成通知功能
- `PostRepository.java` - 添加状态过滤查询
- `PostService.java` - 修改列表方法只返回NORMAL状态

### 前端文件（已修改）
- `post_detail_screen.dart` - 集成举报对话框
- `admin_mode_screen.dart` - 实现举报处理功能

### 已存在的文件（无需修改）
- `Post.java` - 帖子实体
- `PostStatus.java` - 帖子状态枚举
- `ReportPost.java` - 举报实体
- `ReportStatus.java` - 举报状态枚举
- `ReportPostRepository.java` - 举报Repository
- `ReportPostController.java` - 用户端Controller
- `AdminReportPostController.java` - 管理员Controller
- `report_post_dialog.dart` - 举报对话框
- `api_service.dart` - API服务（已包含举报相关方法）

## 测试建议

### 完整流程测试

1. **用户举报**
   - 登录普通用户账号
   - 浏览帖子，点击举报按钮
   - 填写举报理由并提交

2. **管理员下架**
   - 登录管理员账号
   - 进入"帖子举报管理"页面
   - 查看举报详情，点击"处理"按钮
   - 选择"下架帖子"，填写下架原因

3. **作者收到通知**
   - 登录作者账号
   - 查看通知，看到帖子被下架的通知

4. **作者修改**
   - 查看被下架帖子列表
   - 点击编辑，修改内容
   - 保存草稿

5. **作者提交审核**
   - 确认修改完成
   - 点击"提交审核"按钮

6. **管理员审核**
   - 登录管理员账号
   - 进入待审核帖子列表
   - 查看修改后的内容
   - 点击"审核通过"或"审核拒绝"

7. **作者收到审核结果通知**
   - 登录作者账号
   - 查看通知，看到审核结果

8. **验证结果**
   - 审核通过：帖子恢复正常显示
   - 审核拒绝：帖子重新下架，作者可再次修改

## 注意事项

1. **数据库迁移**
   - 需要执行`REPORT_POST_SYSTEM.sql`脚本
   - 确保所有表和字段都已创建

2. **前端状态同步**
   - 举报成功后刷新列表
   - 处理举报后刷新管理员界面

3. **错误处理**
   - 所有API调用都有try-catch
   - 显示友好的错误提示

4. **性能优化**
   - 使用分页查询
   - 添加了数据库索引

## 扩展功能建议

1. **举报分类**
   - 添加举报类型（垃圾信息、不实信息、违规内容等）
   - 根据类型自动分配处理优先级

2. **申诉机制**
   - 作者对下架决定提出申诉
   - 管理员重新审核

3. **统计分析**
   - 举报数量统计
   - 处理效率分析
   - 违规内容趋势分析

4. **批量操作**
   - 批量处理举报
   - 批量审核帖子

## 总结

本次完善实现了完整的用户举报系统核心功能：

✅ 通知系统集成 - 作者能及时收到帖子状态变更通知
✅ 帖子列表过滤 - 普通用户只能看到正常状态的帖子
✅ 前端举报对话框 - 用户可以方便地举报违规帖子
✅ 管理员处理界面 - 管理员可以高效处理举报

所有功能都已实现并集成到现有系统中，可以直接使用！
