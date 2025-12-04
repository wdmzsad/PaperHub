# PaperHub

PaperHub 是一个服务高校师生与研究人员的学术社区。用户可以在平台上发布灵感笔记、浏览学科分区内容、关注学者、收藏/评论/点赞笔记，并通过即时通讯与通知系统保持交流。项目采用 **Flutter** 打造跨平台前端，后端基于 **Spring Boot + MySQL**，并实现 Access/Refresh Token 的安全认证与自动刷新机制。

---

## 核心特性

- 🧱 **瀑布流发现页**：两列 Masonry 卡片展示最新/热门帖子，支持懒加载。
- 👥 **关注信息流**：仅显示已关注作者的动态，未读帖子以红点标识。
- 🏷️ **学科分区**：按主学科标签获取帖子，切换即刷新。
- 💬 **互动体验**：点赞、收藏、评论（含 @ 功能）、私信聊天与多种通知。
- 🪪 **账号体系**：注册、邮箱验证、登录、忘记密码、隐私设置与关注列表。
- 🧰 **管理员能力（逐步完善）**：举报处理、帖子审核、公告管理等。
- 🛡️ **安全认证**：JWT Access Token（30 分钟）+ Refresh Token（7 天）自动续签。

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

- 默认访问地址：`http://localhost:8080`
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

`main()` 启动时会初始化 `SharedPreferences` 并检查本地 token：若未过期则直接进入首页，否则跳转登录；收到 401 会自动调用 `/auth/refresh` 更新 token 并重放原请求。

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
- `Backend/paperhub/VIDEO_SUPPORT_SUMMARY.md` / `VIDEO_TYPE_FIX.md`：多媒体支持记录
- 其他 `*_SUMMARY.md` 文件：特性实现或 Bug 修复的详细说明

---

## License & Status

本仓库为课程项目，默认遵从教学要求，暂未指定开源许可证。 
当前功能持续开发中
# PaperHub



## Getting started

To make it easy for you to get started with GitLab, here's a list of recommended next steps.

Already a pro? Just edit this README.md and make it your own. Want to make it easy? [Use the template at the bottom](#editing-this-readme)!

## Add your files

- [ ] [Create](https://docs.gitlab.com/ee/user/project/repository/web_editor.html#create-a-file) or [upload](https://docs.gitlab.com/ee/user/project/repository/web_editor.html#upload-a-file) files
- [ ] [Add files using the command line](https://docs.gitlab.com/topics/git/add_files/#add-files-to-a-git-repository) or push an existing Git repository with the following command:

```
cd existing_repo
git remote add origin https://gitlab.com/tj-cs-swe/CS10102302-2025/group8/paperhub.git
git branch -M main
git push -uf origin main
```

## Integrate with your tools

- [ ] [Set up project integrations](https://gitlab.com/tj-cs-swe/CS10102302-2025/group8/paperhub/-/settings/integrations)

## Collaborate with your team

- [ ] [Invite team members and collaborators](https://docs.gitlab.com/ee/user/project/members/)
- [ ] [Create a new merge request](https://docs.gitlab.com/ee/user/project/merge_requests/creating_merge_requests.html)
- [ ] [Automatically close issues from merge requests](https://docs.gitlab.com/ee/user/project/issues/managing_issues.html#closing-issues-automatically)
- [ ] [Enable merge request approvals](https://docs.gitlab.com/ee/user/project/merge_requests/approvals/)
- [ ] [Set auto-merge](https://docs.gitlab.com/user/project/merge_requests/auto_merge/)

## Test and Deploy

Use the built-in continuous integration in GitLab.

- [ ] [Get started with GitLab CI/CD](https://docs.gitlab.com/ee/ci/quick_start/)
- [ ] [Analyze your code for known vulnerabilities with Static Application Security Testing (SAST)](https://docs.gitlab.com/ee/user/application_security/sast/)
- [ ] [Deploy to Kubernetes, Amazon EC2, or Amazon ECS using Auto Deploy](https://docs.gitlab.com/ee/topics/autodevops/requirements.html)
- [ ] [Use pull-based deployments for improved Kubernetes management](https://docs.gitlab.com/ee/user/clusters/agent/)
- [ ] [Set up protected environments](https://docs.gitlab.com/ee/ci/environments/protected_environments.html)

***

# Editing this README

When you're ready to make this README your own, just edit this file and use the handy template below (or feel free to structure it however you want - this is just a starting point!). Thanks to [makeareadme.com](https://www.makeareadme.com/) for this template.

## Suggestions for a good README

Every project is different, so consider which of these sections apply to yours. The sections used in the template are suggestions for most open source projects. Also keep in mind that while a README can be too long and detailed, too long is better than too short. If you think your README is too long, consider utilizing another form of documentation rather than cutting out information.

## Name
Choose a self-explaining name for your project.

## Description
Let people know what your project can do specifically. Provide context and add a link to any reference visitors might be unfamiliar with. A list of Features or a Background subsection can also be added here. If there are alternatives to your project, this is a good place to list differentiating factors.

## Badges
On some READMEs, you may see small images that convey metadata, such as whether or not all the tests are passing for the project. You can use Shields to add some to your README. Many services also have instructions for adding a badge.

## Visuals
Depending on what you are making, it can be a good idea to include screenshots or even a video (you'll frequently see GIFs rather than actual videos). Tools like ttygif can help, but check out Asciinema for a more sophisticated method.

## Installation
Within a particular ecosystem, there may be a common way of installing things, such as using Yarn, NuGet, or Homebrew. However, consider the possibility that whoever is reading your README is a novice and would like more guidance. Listing specific steps helps remove ambiguity and gets people to using your project as quickly as possible. If it only runs in a specific context like a particular programming language version or operating system or has dependencies that have to be installed manually, also add a Requirements subsection.

## Usage
Use examples liberally, and show the expected output if you can. It's helpful to have inline the smallest example of usage that you can demonstrate, while providing links to more sophisticated examples if they are too long to reasonably include in the README.

## Support
Tell people where they can go to for help. It can be any combination of an issue tracker, a chat room, an email address, etc.

## Roadmap
If you have ideas for releases in the future, it is a good idea to list them in the README.

## Contributing
State if you are open to contributions and what your requirements are for accepting them.

For people who want to make changes to your project, it's helpful to have some documentation on how to get started. Perhaps there is a script that they should run or some environment variables that they need to set. Make these steps explicit. These instructions could also be useful to your future self.

You can also document commands to lint the code or run tests. These steps help to ensure high code quality and reduce the likelihood that the changes inadvertently break something. Having instructions for running tests is especially helpful if it requires external setup, such as starting a Selenium server for testing in a browser.

## Authors and acknowledgment
Show your appreciation to those who have contributed to the project.

## License
For open source projects, say how it is licensed.

## Project status
If you have run out of energy or time for your project, put a note at the top of the README saying that development has slowed down or stopped completely. Someone may choose to fork your project or volunteer to step in as a maintainer or owner, allowing your project to keep going. You can also make an explicit request for maintainers.
