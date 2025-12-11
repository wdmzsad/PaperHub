import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/verify_email_page.dart';
import 'pages/forgot_password_page.dart';
import 'pages/reset_password_page.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/chat_screen.dart';
import 'services/local_storage.dart';
import 'services/notification_websocket_service.dart';
import 'constants/app_colors.dart';
import 'utils/font_utils.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化ServicesBinding（用于应用生命周期监听）
  // 注意：ServicesBinding.instance在Flutter 3.0+中可能为null，需要检查
  try {
    // 确保ServicesBinding已初始化
    if (ServicesBinding.instance == null) {
      // 在Flutter 3.0+中，可能需要手动初始化
      // 这里使用try-catch避免崩溃
    }
  } catch (e) {
    debugPrint('ServicesBinding初始化失败: $e');
  }

  // 初始化本地存储（SharedPreferences），失败时不要让应用崩掉
  try {
    await LocalStorage.instance.init();
  } catch (e, s) {
    debugPrint('LocalStorage.init failed: $e\n$s');
  }

  // 捕获 Flutter 框架级错误（包括构建/布局阶段）
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError.onError: ${details.exception}\n${details.stack}');
  };

  // 读取主题模式（持久化）
  final storedTheme = LocalStorage.instance.read('themeMode');
  final initialThemeMode = _parseThemeMode(storedTheme);

  // 捕获顶层未处理错误，避免在 Web 上直接变成混淆的 Uncaught Error
  runZonedGuarded(() {
    runApp(PaperHubApp(initialThemeMode: initialThemeMode));
  }, (error, stack) {
    debugPrint('=== TOP LEVEL ERROR ===');
    debugPrint(error.toString());
    debugPrint(stack.toString());
  });
}

ThemeMode _parseThemeMode(String? raw) {
  switch ((raw ?? '').toLowerCase()) {
    case 'dark':
      return ThemeMode.dark;
    case 'light':
      return ThemeMode.light;
    case 'system':
    default:
      return ThemeMode.system;
  }
}

class PaperHubApp extends StatefulWidget {
  const PaperHubApp({super.key, required this.initialThemeMode});

  final ThemeMode initialThemeMode;

  @override
  State<PaperHubApp> createState() => _PaperHubAppState();
}

class _PaperHubAppState extends State<PaperHubApp> {
  late final ValueNotifier<ThemeMode> _themeModeNotifier =
      ValueNotifier(widget.initialThemeMode);

  ThemeData get _lightTheme => ThemeData(
        brightness: Brightness.light,
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.backgroundLight,
        fontFamily: 'NotoSansSC',
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontFamily: 'NotoSansSC'),
          bodyMedium: TextStyle(fontFamily: 'NotoSansSC'),
          bodySmall: TextStyle(fontFamily: 'NotoSansSC'),
          titleLarge: TextStyle(fontFamily: 'NotoSansSC'),
          titleMedium: TextStyle(fontFamily: 'NotoSansSC'),
          titleSmall: TextStyle(fontFamily: 'NotoSansSC'),
        ),
        colorScheme: ColorScheme.light(
          primary: AppColors.primary,
          secondary: AppColors.primaryLight,
          surface: AppColors.background,
          onPrimary: AppColors.textOnPrimary,
          onSurface: AppColors.textPrimary,
        ),
      );

  ThemeData get _darkTheme {
    const bg = Color(0xFF0B1220);
    const surface = Color(0xFF111827);
    const card = Color(0xFF1F2937);
    const onSurface = Color(0xFFE5E7EB);
    final base = ThemeData(
      brightness: Brightness.dark,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: bg,
      fontFamily: 'NotoSansSC',
      colorScheme: ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.primaryLight,
        surface: surface,
        background: bg,
        onPrimary: AppColors.textOnPrimary,
        onSurface: onSurface,
        onBackground: onSurface,
      ),
      cardColor: card,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: onSurface,
        displayColor: onSurface,
        fontFamily: 'NotoSansSC',
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
        iconTheme: const IconThemeData(color: onSurface),
        titleTextStyle: base.textTheme.titleLarge?.copyWith(color: onSurface),
      ),
      iconTheme: const IconThemeData(color: onSurface),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: card,
        hintStyle: TextStyle(color: onSurface.withOpacity(0.6)),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: onSurface.withOpacity(0.15)),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.primary),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      dividerColor: onSurface.withOpacity(0.12),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          side: BorderSide(color: onSurface.withOpacity(0.4)),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: card,
        labelStyle: TextStyle(color: onSurface),
        secondarySelectedColor: AppColors.primary,
      ),
    );
  }

  void _setThemeMode(ThemeMode mode) {
    _themeModeNotifier.value = mode;
    LocalStorage.instance.write('themeMode', mode.name);
  }

  void _toggleTheme() {
    final current = _themeModeNotifier.value;
    final next = current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    _setThemeMode(next);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeModeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'PaperHub (Mock Demo)',
          themeMode: mode,
          theme: _lightTheme,
          darkTheme: _darkTheme,
          initialRoute: '/',
          routes: {
            '/': (ctx) => const SplashOrLogin(),
            '/login': (ctx) => LoginPage(),
            '/register': (ctx) => RegisterPage(),
            '/verify': (ctx) => VerifyEmailPage(),
            '/forgot': (ctx) => ForgotPasswordPage(),
            '/reset': (ctx) => ResetPasswordPage(),
            '/home': (ctx) => HomeScreen(
                  themeModeNotifier: _themeModeNotifier,
                  onThemeModeChanged: _setThemeMode,
                  onThemeToggle: _toggleTheme,
                ),
            '/me': (ctx) => const ProfilePage(isMainPage: true),
          },
          onGenerateRoute: (settings) {
            final name = settings.name ?? '';
            if (name.startsWith('/user/')) {
              final userId = name.substring('/user/'.length);
              return MaterialPageRoute(
                builder: (_) => ProfilePage(userId: userId),
                settings: settings,
              );
            }
            if (name.startsWith('/chat/')) {
              final conversationId = name.substring('/chat/'.length);
              return MaterialPageRoute(
                builder: (_) => ChatScreen(conversationId: conversationId),
                settings: settings,
              );
            }
            return null;
          },
        );
      },
    );
  }
}

/// 启动页：检查本地 token 决定跳转首页还是登录页
class SplashOrLogin extends StatefulWidget {
  const SplashOrLogin({Key? key}) : super(key: key);

  @override
  _SplashOrLoginState createState() => _SplashOrLoginState();
}

class _SplashOrLoginState extends State<SplashOrLogin> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _checkToken();
    _connectWebSocket();
  }

  Future<void> _connectWebSocket() async {
    // 延迟连接WebSocket，确保其他初始化完成
    await Future.delayed(const Duration(seconds: 1));

    // 检查用户是否已登录
    final token = LocalStorage.instance.read('accessToken');
    if (token == null || token.isEmpty) {
      debugPrint('用户未登录，不连接WebSocket');
      return;
    }

    try {
      await NotificationWebSocketService.instance.connect();
    } catch (e) {
      debugPrint('WebSocket连接失败: $e');
    }
  }

  Future<void> _checkToken() async {
    try {
      // 简单的加载过渡
      await Future.delayed(const Duration(milliseconds: 400));

      // LocalStorage.read 当前是同步的 String?，这里直接读取即可
      final token = LocalStorage.instance.read('accessToken');
      debugPrint(
          'Startup: accessToken read -> ${token == null ? "null" : "present"}');

      if (!mounted) return;

      if (token != null && token.isNotEmpty) {
        _pushReplacementSafely('/home');
      } else {
        _pushReplacementSafely('/login');
      }
    } catch (e, s) {
      // 避免任何初始化异常在 Web 上冒泡成 Uncaught Error
      debugPrint('Error in _checkToken: $e\n$s');
      if (!mounted) return;
      _pushReplacementSafely('/login');
    }
  }

  void _pushReplacementSafely(String routeName) {
    if (_navigated) return;
    _navigated = true;
    Navigator.of(context).pushReplacementNamed(routeName);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

