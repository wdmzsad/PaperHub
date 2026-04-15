# PaperHub

PaperHub 是一个服务高校师生与研究人员的学术社区。用户可以在平台上发布灵感笔记、浏览学科分区内容、关注学者、收藏/评论/点赞笔记，并通过即时通讯与通知系统保持交流。项目采用 **Flutter** 打造跨平台前端，后端基于 **Spring Boot + MySQL**，并实现 Access/Refresh Token 的安全认证与自动刷新机制。

---

## 核心特性

- **瀑布流发现页**：两列 Masonry 卡片展示最新/热门帖子，支持懒加载和分页。
- **关注信息流**：仅显示已关注作者的动态，未读帖子以红点标识。
- **学科分区**：按主学科标签获取帖子，支持标签过滤，切换即刷新。
- **互动体验**：点赞、收藏、评论（含 @ 功能）、私信聊天与多种通知。
- **多媒体支持**：支持图片、视频上传与播放，以及多种文档类型（PDF、Word、Excel、PPT 等）。
- **举报与审核系统**：完整的帖子举报流程，支持管理员下架、作者修改、审核通过/拒绝。
- **账号体系**：注册、邮箱验证、登录、忘记密码、隐私设置与关注列表。
- **管理员能力**：举报处理、帖子审核、公告管理等。
- **安全认证**：JWT Access Token（30 分钟）+ Refresh Token（7 天）自动续签。

---

## 项目结构

```
paperhub/
├── Backend/paperhub/            # Spring Boot 服务
│   ├── src/main/java/com/example/paperhub/...
│   ├── src/main/resources/application.properties
│   └── 各类实现说明（JWT、刷新、视频等）
├── Frontend/                    # Flutter 前端（Android/iOS/Web/Desktop）
│   ├── lib/                     # 页面、组件、数据模型、服务层
│   ├── assets/                  # 图片与字体
│   ├── android / ios / web ...  # 对应平台工程
│   └── pubspec.yaml
└── README.md                    # 当前文件
```

---

## 环境依赖

| 依赖            | 版本建议                                 |
| --------------- | ---------------------------------------- |
| Flutter SDK     | 3.9.x（参见 `Frontend/pubspec.yaml`）    |
| Dart SDK        | 与 Flutter 版本自带                      |
| Java            | JDK 17（推荐）                           |
| Maven           | 3.8+                                     |
| MySQL           | 8.x（需配置 `application.properties`）   |
| Redis（可选）   | 6.x                                      |

> ⚠️ 请在 `Backend/paperhub/src/main/resources/application.properties` 中配置实际的数据库、邮件、OBS 等账号信息。示例配置（含默认密码）仅供本地演示。

---

## 快速启动

### 1. 后端

```bash
cd Backend/paperhub

# 运行
mvn clean spring-boot:run

# 或打包
mvn clean package
java -jar target/paperhub-*.jar
```

- 本地运行默认访问地址：`http://localhost:8080`
- 主要接口：
  - `POST /auth/login`：登录，返回 accessToken + refreshToken
  - `POST /auth/refresh`：刷新 token
  - `GET /posts`：发现页列表（匿名可访问）
  - `GET /posts/following`：关注流（需登录）
  - 其他接口详见 `Backend/paperhub/src/main/java/com/example/paperhub`

### 2. 前端

```bash
cd Frontend
flutter pub get              # 安装依赖
flutter run -d chrome        # Web 调试
```

`main()` 启动时会初始化 `SharedPreferences` 并检查本地 token：若未过期则直接进入首页，否则跳转登录；收到 401 会自动调用 `/auth/refresh` 更新 token 并重放原请求。

---

## 功能

### 用户注册与登录

1. **注册账号**
   - 访问注册页面，填写邮箱、用户名、密码等信息
   - 系统将发送验证邮件至您的邮箱
   - 点击邮件中的验证链接完成注册

2. **登录系统**
   - 使用注册的邮箱和密码登录
   - 系统会自动保存登录状态（通过 Refresh Token）
   - 登录后自动跳转到首页

3. **忘记密码**
   - 在登录页点击"忘记密码"
   - 输入注册邮箱，系统将发送重置密码链接
   - 通过邮件链接重置密码

### 内容发布与管理

1. **发布笔记**
   - 点击首页的"+"按钮创建新笔记
   - 支持添加标题、正文、图片、视频、音频、PDF 附件等
   - 可选择学科标签，设置可见性
   - 支持保存为草稿，稍后继续编辑

2. **编辑与删除**
   - 编辑自己发布的笔记
   - 删除不需要的笔记
   - 草稿管理：查看、编辑、发布草稿

3. **草稿功能**
   - 保存未完成的笔记为草稿
   - 在个人中心查看草稿列表
   - 继续编辑草稿并发布

### 内容浏览

1. **发现页**
   - 查看所有公开笔记，支持按热门/最新排序
   - 两列瀑布流展示，支持懒加载和分页

2. **关注流**
   - 仅显示已关注用户的动态
   - 未读帖子以红点标识

3. **学科分区**
   - 按学科标签筛选内容
   - 支持标签过滤，切换即刷新

4. **搜索功能**
   - **关键词搜索**：搜索笔记、论文标题
   - **标签搜索**：按领域标签搜索
   - **作者搜索**：搜索作者名称
   - **搜索历史**：自动保存搜索记录（本地+云端同步）
   - **热搜榜单**：查看热门搜索，带"新"、"热"标签

### 互动功能

1. **点赞与收藏**
   - 点赞笔记或评论
   - 收藏感兴趣的笔记
   - 查看自己的收藏列表

2. **评论系统**
   - 在笔记下方发表评论
   - 支持 @ 其他用户
   - 点赞评论
   - 编辑和删除自己的评论

3. **关注与粉丝**
   - 关注感兴趣的作者
   - 查看关注列表和粉丝列表
   - 取消关注

4. **私信聊天**
   - 点击用户头像进入私信聊天
   - 支持文字、图片、视频、文件等多种消息类型
   - 实时消息推送（WebSocket）

### 举报与审核

1. **举报功能**
   - 举报违规帖子
   - 举报违规用户
   - 填写举报理由

2. **审核流程**（针对被举报的帖子）
   - 管理员下架违规帖子
   - 作者修改被下架的帖子
   - 作者提交审核
   - 管理员审核通过或拒绝

### 个人中心

1. **个人资料**
   - 查看和编辑个人资料
   - 修改头像、昵称等信息
   - 隐私设置

2. **内容管理**
   - 查看自己发布的笔记
   - 查看收藏的内容
   - 查看草稿列表
   - 查看被下架的帖子

3. **社交功能**
   - 管理关注列表
   - 查看粉丝列表
   - 查看系统通知

### 管理员功能

1. **用户管理**（超级管理员）
   - 查看用户列表
   - 用户状态管理（正常/封禁等）
   - 审核用户申请

2. **帖子管理**（超级管理员）
   - 查看所有帖子
   - 下架/恢复帖子
   - 审核待审核的帖子

3. **举报管理**
   - **用户举报管理**：处理用户举报
   - **帖子举报管理**：处理帖子举报
   - 下架违规内容或忽略举报

4. **公告管理**
   - 发布系统公告
   - 编辑和删除公告

5. **权限管理**（超级管理员）
   - 管理员申请审核
   - 管理员权限管理
   - 管理员推荐功能

---

## 关键配置

- **JWT & Refresh Token**
  ```properties
  jwt.secret=change-this-to-strong-secret-change
  jwt.expires-in-seconds=1800           # Access Token 30 分钟
  jwt.refresh-expires-in-seconds=604800 # Refresh Token 7 天
  ```
- **刷新机制**：详见 `Backend/paperhub/前端刷新令牌机制实现说明.md`，前端在 `ApiService` 中统一处理 401 → 刷新 → 重试。
- **本地存储**：`lib/services/local_storage.dart` 使用 `SharedPreferences`；`main()` 中 `LocalStorage.instance.init()` 确保刷新页面后仍可读取 token / 用户信息。

---

## 常用脚本

| 目标                   | 命令                                                         |
| ---------------------- | ------------------------------------------------------------ |
| 后端单元测试           | `cd Backend/paperhub && mvn test`                            |
| 后端运行               | `mvn spring-boot:run`                                        |
| Flutter 分析           | `cd Frontend && flutter analyze`                             |
| Flutter 单元测试       | `cd Frontend && flutter test`                                |
| 打包 Android APK       | `cd Frontend && flutter build apk --release`                 |
| 构建 Web 版本          | `cd Frontend && flutter build web`                           |
| 代码格式化（前端）     | `flutter format lib`（或 `dart format lib`）                 |

---

## 贡献指南

1. `git checkout -b feature/xxx` 新建分支。
2. 代码遵循：Java 使用 IDE 自动格式化；Flutter 提交前运行 `flutter analyze` & `dart format`.
3. 提交前确保必要的接口/页面经过自测，可在 README 或 MR 描述中附带截图。
4. 如果修改了数据库/配置文件，务必在文档中说明，避免队友无法启动。

欢迎通过 Issue/MR 报告 Bug、提建议或补充文档。涉及敏感配置（账号、密钥）需转移到环境变量或 `.env`，避免泄露。

---

## 参考文档

- `Backend/paperhub/JWT_TOKEN_FIX.md`：JWT 配置、permitAll 策略与常见问题
- `Backend/paperhub/前端刷新令牌机制实现说明.md`：双 Token 刷新流程
- `Frontend/VIDEO_SUPPORT_SUMMARY.md`：视频上传与播放功能实现
- `Backend/paperhub/FILE_TYPES_SUPPORT.md`：支持的文件类型列表
- `REPORT_POST_SYSTEM_COMPLETE.md`：完整的举报帖子系统实现文档
- `TAG_FILTER_COMPLETE_IMPLEMENTATION.md`：标签过滤功能实现说明
- 其他 `*_SUMMARY.md` 文件：特性实现或 Bug 修复的详细说明

---

## 部署指南

### 华为云云端部署流程

#### 1. 清理并克隆代码仓库

```bash
rm -rf ~/paperhub

git clone https://<账户名>:<可以访问main分支的token>@gitlab.com/tj-cs-swe/CS10102302-2025/group8/paperhub.git
```

#### 2. 前端部署

```bash
cd ~/paperhub/Frontend

flutter clean

flutter pub get

flutter build web

sudo rm -rf /var/www/html/*

sudo cp -r build/web/* /var/www/html/

sudo systemctl restart nginx
```

#### 3. 后端部署

```bash
# 停止现有 Java 进程
chmod +x ~/paperhub/Backend/paperhub/mvnw

ps -ef | grep java

# 根据输出找到 Java 进程的 PID，然后执行（替换 <PID> 为实际进程 ID）
kill -9 <PID>

# 确认进程已停止
ps -ef | grep java

# 构建后端
cd ~/paperhub/Backend/paperhub

./mvnw clean package -DskipTests

# 验证构建产物
ls -l target/

# 创建日志目录并启动服务
mkdir -p logs

nohup java -jar target/paperhub-0.0.1-SNAPSHOT.jar > logs/spring.log 2>&1 &

# 验证服务已启动
ps -ef | grep java
```

> ⚠️ **安全提示**：上述命令中包含 GitLab 访问令牌，请妥善保管，避免泄露。建议在生产环境中使用环境变量或密钥管理服务。

---

## License & Status

本仓库为课程项目，默认遵从教学要求，暂未指定开源许可证。  
当前功能持续开发中。
