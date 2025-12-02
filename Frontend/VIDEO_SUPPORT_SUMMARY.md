# 图片+视频上传和播放功能实现总结

## 已完成的修改

### 1. 依赖添加 (`pubspec.yaml`)
```yaml
video_player: ^2.8.2  # 视频播放器
```

### 2. 后端修改

#### MessageType 枚举 (`MessageType.java`)
```java
public enum MessageType {
    TEXT, VOICE, IMAGE, FILE, VIDEO  // 新增 VIDEO
}
```

### 3. 前端模型修改

#### Message 模型 (`message_model.dart`)
- 添加 `MessageType.video` 枚举值
- 在 `fromJson` 中添加 `VIDEO` 类型解析

### 4. 文件选择器修改 (`chat_input.dart`)

#### 更新选项名称和功能
- 第一个选项从"图片"改为"图片和视频"
- 点击后弹出二级选择对话框：
  - 图片：使用 `picker.pickImage()`
  - 视频：使用 `picker.pickVideo()`

#### 新增方法
```dart
Future<void> _pickMedia() async {
  // 显示图片/视频选择对话框
  // 分别调用 pickImage 或 pickVideo
  // 上传时设置正确的 messageType: 'IMAGE' 或 'VIDEO'
}
```

### 5. 视频播放器组件 (`video_message_player.dart`)

**新建文件**，包含：
- 视频初始化和加载
- 播放/暂停控制
- 错误处理
- 加载状态显示
- 点击播放/暂停交互

**特性：**
- 固定尺寸：250x200
- 圆角边框
- 播放按钮覆盖层
- 自动适配视频宽高比

### 6. 消息气泡修改 (`message_bubble.dart`)

#### 结构变更
- 从 `StatelessWidget` 改为 `StatefulWidget`
- 添加 `VideoPlayerController` 管理
- 添加 `dispose()` 方法清理资源

#### 新增视频消息处理
```dart
case MessageType.video:
  content = _buildVideoMessage(context);
  break;
```

#### 新增方法
```dart
Widget _buildVideoMessage(BuildContext context) {
  // 从 fileUrl 或 mediaUrls 获取视频 URL
  // 返回 VideoMessagePlayer 组件
}
```

## 使用流程

### 用户操作流程

1. **选择视频**
   - 点击聊天输入框的附件按钮（➕）
   - 选择"图片和视频"
   - 在弹出对话框中选择"视频"
   - 从相册选择视频文件

2. **上传视频**
   - 自动上传到 `/api/upload/chat-file`
   - 后端保存到 OBS
   - 返回视频 URL

3. **发送消息**
   - 调用 `onSendMedia([url], 'VIDEO', fileName, fileSize)`
   - 后端创建 `MessageType.VIDEO` 消息
   - 保存到数据库

4. **显示视频**
   - 消息列表加载视频消息
   - 显示视频播放器（250x200）
   - 点击播放/暂停

### 数据流

```
用户选择视频
    ↓
picker.pickVideo()
    ↓
上传到 OBS (/api/upload/chat-file)
    ↓
获取视频 URL
    ↓
发送消息 (type: VIDEO, fileUrl: xxx)
    ↓
保存到 Message 表
    ↓
前端加载消息
    ↓
渲染 VideoMessagePlayer
    ↓
用户点击播放
```

## 数据库字段

Message 表已有字段（无需修改）：
- `type` - 消息类型（TEXT/IMAGE/VIDEO/FILE）
- `file_url` - 视频 URL
- `file_name` - 视频文件名
- `file_size` - 视频文件大小

## API 接口

### 上传视频
```
POST /api/upload/chat-file
Content-Type: multipart/form-data

file: [视频文件]
```

**响应：**
```json
{
  "url": "https://bucket.obs.xxx.com/chat-files/xxx.mp4",
  "fileName": "video.mp4",
  "fileSize": 5242880,
  "message": "文件上传成功"
}
```

### 发送视频消息
```
POST /api/conversations/{conversationId}/messages

{
  "content": "",
  "type": "VIDEO",
  "mediaUrls": ["https://..."],
  "fileName": "video.mp4",
  "fileSize": 5242880
}
```

## 支持的文件类型

### 图片
- JPG, JPEG, PNG, GIF

### 视频
- MP4

### 文档
- PDF, DOC, DOCX, PPT, PPTX, XLS, XLSX, TXT, CSV

### 压缩包
- ZIP, RAR, 7Z

### 其他
- EXE

## 注意事项

1. **视频大小限制**：50MB（后端配置）
2. **视频格式**：建议使用 MP4（H.264 编码）
3. **播放器状态**：每个视频消息独立管理播放状态
4. **内存管理**：VideoPlayerController 在 dispose 时自动释放
5. **网络视频**：使用 `VideoPlayerController.networkUrl()`
6. **错误处理**：视频加载失败时显示错误提示

## 测试清单

- [ ] 选择视频文件
- [ ] 上传视频到 OBS
- [ ] 发送视频消息
- [ ] 接收视频消息
- [ ] 播放视频
- [ ] 暂停视频
- [ ] 视频加载失败处理
- [ ] 多个视频同时存在
- [ ] 滚动时视频状态保持
- [ ] 返回聊天界面后视频正常显示

## 已知限制

1. 视频播放器固定尺寸（250x200）
2. 不支持视频进度条拖动
3. 不支持音量控制
4. 不支持全屏播放
5. Web 平台视频播放依赖浏览器支持

## 未来改进

- [ ] 添加视频进度条
- [ ] 添加音量控制
- [ ] 支持全屏播放
- [ ] 视频缩略图生成
- [ ] 视频压缩
- [ ] 多视频选择
- [ ] 视频编辑功能
