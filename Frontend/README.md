关于paperhub前端的说明文件

一、项目架构
 paperhub/                        # 项目根目录
└── Frontend/                     # 前端（Flutter）工程根目录
    ├── lib/                      # Dart 源代码（主要业务逻辑）
    │   ├── main.dart             # 应用入口与路由表
    │   ├── pages/                # 认证/密码相关页面
    │   ├── screens/              # 业务主页面
    │   ├── services/             # 服务层（网络、本地存储等）
    │   ├── models/               # 数据模型与模拟数据
    │   └── widgets/              # 可复用组件
    ├── web/                      # Flutter Web 资源（仅 Web 构建/运行使用）
    ├── android/                  # Android 平台工程（Gradle 配置等）
    │   └── app/
    ├── ios/                      # iOS 平台工程（Xcode 工程文件）
    ├── windows/                  # Windows 平台工程
    ├── linux/                    # Linux 平台工程
    ├── macos/                    # macOS 平台工程
    └── build/                    # 构建输出目录（运行/打包后生成，通常被忽略）


二、源代码功能简述
关于前端所有文件功能的说明。
 paperhub/                        # 项目根目录
└── Frontend/                     # 前端（Flutter）工程根目录
    ├── pubspec.yaml              # Flutter 依赖与资源配置（第三方包、资源、版本等）
    ├── .metadata                 # Flutter 工程元数据（自动生成，勿手动修改）
    ├── lib/                      # Dart 源代码（主要业务逻辑）
    │   ├── main.dart             # 应用入口与路由表
    │   ├── pages/                # 认证/密码相关页面
    │   │   ├── login_page.dart
    │   │   ├── register_page.dart
    │   │   ├── verify_email_page.dart
    │   │   ├── forgot_password_page.dart
    │   │   └── reset_password_page.dart
    │   ├── screens/              # 业务主页面
    │   │   ├── home_screen.dart          # 首页（发现/分区+瀑布流）
    │   │   ├── post_detail_screen.dart   # 帖子/论文详情
    │   │   ├── search_screen.dart        # 搜索与历史
    │   │   ├── message_screen.dart       # 消息（占位）
    │   │   └── profile_screen.dart       # 个人主页
    │   ├── services/             # 服务层（网络、本地存储等）
    │   │   ├── api_service.dart           # HTTP 接口封装（baseUrl 在此配置）
    │   │   ├── local_storage.dart         # 演示用内存存储（登录态示例）
    │   │   └── search_history_service.dart# 搜索历史的本地持久化
    │   ├── models/               # 数据模型与模拟数据
    │   │   ├── post_model.dart            # Post/Author/Attachment + mockPosts
    │   │   └── search_model.dart          # 热搜/历史模型 + mockHotSearches
    │   └── widgets/              # 可复用组件
    │       ├── post_card.dart            # 瀑布流笔记卡片
    │       └── bottom_navigation.dart    # 底部导航栏
    ├── web/                      # Flutter Web 资源（仅 Web 构建/运行使用）
    │   ├── index.html            # Web 入口 HTML
    │   └── manifest.json         # PWA manifest
    ├── android/                  # Android 平台工程（Gradle 配置等）
    │   └── app/
    │       └── build.gradle.kts  # Android 构建配置（KTS）
    ├── ios/                      # iOS 平台工程（Xcode 工程文件）
    ├── windows/                  # Windows 平台工程
    ├── linux/                    # Linux 平台工程
    ├── macos/                    # macOS 平台工程
    └── build/                    # 构建输出目录（运行/打包后生成，通常被忽略）

三、使用说明
1. 网页打开：终端输入命令行flutter run -d chrome
2. Android Studio运行：
    ①点击右侧边栏从上往下第二个按钮“device manager”，使用初始自带的“Medium Phone API 36.1”或者新建一个虚拟机；
    ②先点击运行虚拟机，然后运行项目（上方绿色按钮）。
    ③注意需要几个配置：左上角file->settings->language&frameworks->android sdk和dart和flutter这几个配置。android sdk注意sdk location，和sdk tools里是否勾选了所需的tools。dart页面需要勾选“enable dart support...”。flutter页面注意flutter sdk path的路径。
    ④几个可能有用的在terminal输入的命令行：flutter run，如果虚拟机没有运行的话，会提示可用的运行的网页；若虚拟机运行了，且gradle配置正确，会直接连到虚拟机。