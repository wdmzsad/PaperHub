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

void main() {
  runApp(PaperHubApp());
}

class PaperHubApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PaperHub (Mock Demo)',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/',
      routes: {
        '/': (ctx) => SplashOrLogin(),
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

/// 简单启动检查 token（演示用：使用内存存储）
class SplashOrLogin extends StatefulWidget {
  @override
  _SplashOrLoginState createState() => _SplashOrLoginState();
}

class _SplashOrLoginState extends State<SplashOrLogin> {
  @override
  void initState() {
    super.initState();
    _checkToken();
  }

  Future<void> _checkToken() async {
    await Future.delayed(Duration(milliseconds: 400));
    final token = LocalStorage.instance.read('accessToken');
    if (token != null && token.isNotEmpty) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
