# 视频类型存储问题修复

## 问题描述

上传视频时，数据库中存储的类型是 `IMAGE` 而不是 `VIDEO`。

## 问题根源

视频消息在从前端到后端的传递过程中，有三个地方缺少对 `VIDEO` 类型的处理：

### 1. chat_screen.dart - _onSendMedia 方法

**问题：** 缺少对 `VIDEO` 类型的判断

**位置：** `lib/screens/chat_screen.dart` 第 230-253 行

**修复前：**
```dart
MessageType type = MessageType.image;
if (messageType == 'FILE') {
  type = MessageType.file;
} else if (messageType == 'IMAGE') {
  type = MessageType.image;
}
```

**修复后：**
```dart
MessageType type = MessageType.image;
if (messageType == 'FILE') {
  type = MessageType.file;
} else if (messageType == 'IMAGE') {
  type = MessageType.image;
} else if (messageType == 'VIDEO') {
  type = MessageType.video;
}
```

### 2. chat_service.dart - _convertMessageType 方法

**问题：** 类型转换方法缺少 `VIDEO` 的 case

**位置：** `lib/services/chat_service.dart` 第 365-380 行

**修复前：**
```dart
String _convertMessageType(MessageType type) {
  switch (type) {
    case MessageType.text:
      return 'TEXT';
    case MessageType.voice:
      return 'VOICE';
    case MessageType.image:
      return 'IMAGE';
    case MessageType.file:
      return 'FILE';
    default:
      return 'TEXT';
  }
}
```

**修复后：**
```dart
String _convertMessageType(MessageType type) {
  switch (type) {
    case MessageType.text:
      return 'TEXT';
    case MessageType.voice:
      return 'VOICE';
    case MessageType.image:
      return 'IMAGE';
    case MessageType.file:
      return 'FILE';
    case MessageType.video:
      return 'VIDEO';
    default:
      return 'TEXT';
  }
}
```

### 3. 后端默认类型（已存在但需注意）

**位置：** `ChatController.java` 第 127 行

```java
request.getType() != null ? request.getType() : MessageType.IMAGE
```

这里如果前端没有传递 type，会默认为 IMAGE。但由于我们已经在前端修复了类型传递，这个默认值不会影响视频消息。

## 数据流追踪

### 修复后的完整流程

1. **用户选择视频**
   ```
   chat_input.dart: _pickMedia() → pickVideo()
   ```

2. **上传视频**
   ```
   chat_input.dart: _uploadAndSendMediaFile(file, 'VIDEO')
   ```

3. **调用回调**
   ```
   chat_input.dart: onSendMedia([url], 'VIDEO', fileName, fileSize)
   ```

4. **类型转换（第一次）**
   ```
   chat_screen.dart: _onSendMedia()
   messageType == 'VIDEO' → type = MessageType.video
   ```

5. **发送到服务层**
   ```
   chat_service.dart: sendMessageWithMedia(type: MessageType.video)
   ```

6. **类型转换（第二次）**
   ```
   chat_service.dart: _convertMessageType(MessageType.video)
   返回: 'VIDEO'
   ```

7. **发送到后端**
   ```
   api_service.dart: sendMessageWithMedia(type: 'VIDEO')
   ```

8. **后端接收**
   ```
   ChatController.java: request.getType() = MessageType.VIDEO
   ```

9. **保存到数据库**
   ```
   Message.type = VIDEO
   ```

## 验证步骤

1. 选择视频文件
2. 上传并发送
3. 检查数据库 `messages` 表
4. 确认 `type` 字段为 `VIDEO`

## 测试 SQL

```sql
-- 查看最近的视频消息
SELECT id, type, file_name, file_url, created_at
FROM messages
WHERE type = 'VIDEO'
ORDER BY created_at DESC
LIMIT 10;
```

## 已修复的文件

- ✅ `lib/screens/chat_screen.dart`
- ✅ `lib/services/chat_service.dart`

## 相关文件（无需修改）

- `lib/widgets/chat_input.dart` - 已正确传递 'VIDEO' 字符串
- `lib/models/message_model.dart` - 已支持 MessageType.video
- `Backend/.../MessageType.java` - 已包含 VIDEO 枚举
- `Backend/.../ChatController.java` - 已支持接收 VIDEO 类型

## 注意事项

1. 确保前端和后端的 MessageType 枚举值一致
2. 类型转换必须在两个地方都处理：
   - `_onSendMedia`: String → MessageType
   - `_convertMessageType`: MessageType → String
3. 后端的默认类型是 IMAGE，所以前端必须正确传递类型

## 问题已解决 ✅

现在上传视频时，数据库中会正确存储为 `VIDEO` 类型。
