import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/verify_email_page.dart';
import 'pages/forgot_password_page.dart';
import 'pages/reset_password_page.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/chat_screen.dart';
import 'services/local_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  // 捕获顶层未处理错误，避免在 Web 上直接变成混淆的 Uncaught Error
  runZonedGuarded(() {
    runApp(const PaperHubApp());
  }, (error, stack) {
    debugPrint('=== TOP LEVEL ERROR ===');
    debugPrint(error.toString());
    debugPrint(stack.toString());
  });
}

class PaperHubApp extends StatelessWidget {
  const PaperHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PaperHub (Mock Demo)',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/',
      routes: {
        '/': (ctx) => const SplashOrLogin(),
        '/login': (ctx) => LoginPage(),
        '/register': (ctx) => RegisterPage(),
        '/verify': (ctx) => VerifyEmailPage(),
        '/forgot': (ctx) => ForgotPasswordPage(),
        '/reset': (ctx) => ResetPasswordPage(),
        '/home': (ctx) => const HomeScreen(),
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

