# 视频背景设置说明

## 问题
在 Flutter Web 平台上，`VideoPlayerController.asset()` 可能无法正确加载视频文件，导致 404 错误或格式不支持错误。

## 解决方案

### 方法 1：将视频文件放到 web 目录（推荐）

1. **复制视频文件到 web 目录**：
   ```bash
   # Windows PowerShell
   copy Frontend\assets\Title_07.mp4 Frontend\web\Title_07.mp4
   
   # 或者手动复制文件
   # 将 `Frontend/assets/Title_07.mp4` 复制到 `Frontend/web/Title_07.mp4`
   ```

2. **修改代码中的路径**（如果使用方法 1）：
   - 在 `login_page.dart` 和 `register_page.dart` 中，将路径改为 `'/Title_07.mp4'`

### 方法 2：使用 Flutter 构建后的 assets 路径

Flutter Web 构建时会将 `pubspec.yaml` 中声明的 assets 复制到构建输出目录。

构建后的路径通常是：`/assets/Title_07.mp4`

当前代码已经支持这个路径（自动将 `assets/Title_07.mp4` 转换为 `/assets/Title_07.mp4`）。

### 视频格式要求

**重要**：MP4 文件必须使用浏览器支持的编码格式：
- **视频编码**：H.264 (AVC)
- **音频编码**：AAC
- **容器格式**：MP4

如果你的视频文件格式不正确，可以使用 FFmpeg 转换：

```bash
ffmpeg -i Title_07.mp4 -c:v libx264 -c:a aac -strict experimental Title_07_web.mp4
```

## 当前实现

代码已经更新为：
- **Web 平台**：使用 `VideoPlayerController.networkUrl()` 加载 `/assets/Title_07.mp4`
- **移动端平台**：使用 `VideoPlayerController.asset()` 加载 `assets/Title_07.mp4`

## 调试步骤

1. 运行 `flutter build web`
2. 检查构建输出目录中的 `assets/Title_07.mp4` 是否存在
3. 在浏览器中直接访问 `http://localhost:port/assets/Title_07.mp4` 测试视频是否可以播放
4. 查看浏览器控制台的错误信息

## 如果仍然失败

如果视频仍然无法加载，可以：
1. 将视频文件放到 `web/` 目录，使用路径 `/Title_07.mp4`
2. 或者将视频转换为 WebM 格式（浏览器兼容性更好）
3. 或者使用网络 URL（如果视频托管在其他服务器上）

