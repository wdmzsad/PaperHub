# 聊天文件上传支持的文件类型

## 后端支持的文件扩展名

### 文档类型
- `.pdf` - PDF 文档
- `.doc` - Word 文档（旧版）
- `.docx` - Word 文档（新版）
- `.txt` - 纯文本文件
- `.csv` - CSV 表格文件

### 演示文稿
- `.ppt` - PowerPoint（旧版）
- `.pptx` - PowerPoint（新版）

### 表格
- `.xls` - Excel（旧版）
- `.xlsx` - Excel（新版）

### 压缩文件
- `.zip` - ZIP 压缩包
- `.rar` - RAR 压缩包
- `.7z` - 7-Zip 压缩包

### 可执行文件
- `.exe` - Windows 可执行文件

### 媒体文件
- `.jpg`, `.jpeg`, `.png`, `.gif` - 图片
- `.mp3`, `.wav` - 音频
- `.mp4` - 视频

## 对应的 MIME 类型

```
application/pdf                                                                      # PDF
application/msword                                                                   # DOC
application/vnd.openxmlformats-officedocument.wordprocessingml.document             # DOCX
application/vnd.ms-powerpoint                                                        # PPT
application/vnd.openxmlformats-officedocument.presentationml.presentation           # PPTX
application/vnd.ms-excel                                                             # XLS
application/vnd.openxmlformats-officedocument.spreadsheetml.sheet                   # XLSX
application/zip                                                                      # ZIP
application/x-rar-compressed                                                         # RAR
application/x-7z-compressed                                                          # 7Z
application/x-msdownload                                                             # EXE
text/plain                                                                           # TXT
text/csv                                                                             # CSV
```

## 文件大小限制

- 最大文件大小：**50MB**
- 超过限制将返回错误：`文件大小不能超过50MB`

## 前端图标映射

| 文件类型 | Flutter Icon |
|---------|-------------|
| PDF | `Icons.picture_as_pdf` |
| DOC/DOCX | `Icons.description` |
| PPT/PPTX | `Icons.slideshow` |
| XLS/XLSX/CSV | `Icons.table_chart` |
| ZIP/RAR/7Z | `Icons.folder_zip` |
| TXT | `Icons.text_snippet` |
| EXE | `Icons.settings_applications` |
| MP4 | `Icons.video_library` |
| 其他 | `Icons.insert_drive_file` |

## API 使用

### 上传文件

```http
POST /api/upload/chat-file
Content-Type: multipart/form-data

file: [文件]
```

**成功响应：**
```json
{
  "url": "https://bucket.obs.cn-north-4.myhuaweicloud.com/chat-files/xxx.pdf",
  "fileName": "document.pdf",
  "fileSize": 1024000,
  "message": "文件上传成功"
}
```

**错误响应：**
```json
{
  "message": "不支持的文件类型"
}
```

## 数据库字段

消息表已包含以下字段：

- `file_name` (VARCHAR) - 文件名
- `file_url` (VARCHAR) - 文件 URL
- `file_size` (BIGINT) - 文件大小（字节）
- `type` (ENUM) - 消息类型：TEXT / IMAGE / FILE

## 安全注意事项

1. **文件类型验证**：后端通过扩展名验证文件类型
2. **文件大小限制**：限制为 50MB 防止滥用
3. **EXE 文件警告**：虽然支持上传，但下载时应提示用户注意安全
4. **存储隔离**：所有聊天文件存储在 `chat-files/` 目录下
