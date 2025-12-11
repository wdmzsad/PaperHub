import 'dart:convert';

import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/local_storage.dart';
import '../services/notification_websocket_service.dart';
import '../widgets/animated_title_background.dart';
import '../constants/app_colors.dart';
import '../utils/font_utils.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  String email = '';
  String password = '';
  bool loading = false;
  String? errorText;
  bool _obscurePassword = true;

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _cacheCurrentUserProfile() async {
    try {
      final resp = await ApiService.getCurrentUserProfile();
      if (resp['statusCode'] == 200) {
        final body = resp['body'] as Map<String, dynamic>;
        await LocalStorage.instance.write('currentUser', jsonEncode(body));
        final id = body['id'];
        if (id != null) {
          await LocalStorage.instance.write('userId', id.toString());
        }
      } else {
        print('获取当前用户信息失败: ${resp['body']}');
      }
    } catch (e) {
      print('获取当前用户信息异常: $e');
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      loading = true;
      errorText = null;
    });
    final res = await ApiService.login(email.trim(), password);
    setState(() {
      loading = false;
    });
    if (res['statusCode'] == 200) {
      final token = res['body']['token'] ?? '';
      final refreshToken = res['body']['refreshToken'] ?? '';
      // 保存双Token
      await LocalStorage.instance.write('accessToken', token);
      await LocalStorage.instance.write('refreshToken', refreshToken);
      await _cacheCurrentUserProfile();
      _showSnack(res['body']['message'] ?? '登录成功');

      // 登录成功后连接WebSocket接收实时通知
      try {
        await NotificationWebSocketService.instance.connect();
      } catch (e) {
        print('WebSocket连接失败: $e');
      }

      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      _showSnack(res['body']['message'] ?? '登录失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedTitleBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.24), // 下移卡片
                  // 半透明登录卡片，居中靠下
                  Container(
                    constraints: BoxConstraints(maxWidth: 720),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.blueLight1,
                        width: 1,
                      ),
                      boxShadow: [AppColors.cardShadow],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '登录',
                              style: FontUtils.textStyle(
                                text: '登录',
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 24),
                            TextFormField(
                              decoration: InputDecoration(
                                labelText: '邮箱',
                                labelStyle: FontUtils.textStyle(text: '邮箱'),
                                filled: true,
                                fillColor: AppColors.primaryLighter.withOpacity(0.6),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: AppColors.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: AppColors.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: AppColors.borderFocused, width: 2),
                                ),
                              ),
                              style: FontUtils.textStyle(text: email),
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return '请输入邮箱';
                                if (!EmailValidator.validate(v.trim()))
                                  return '邮箱格式不正确';
                                return null;
                              },
                              onChanged: (v) => email = v,
                            ),
                            SizedBox(height: 16),
                            TextFormField(
                              decoration: InputDecoration(
                                labelText: '密码',
                                labelStyle: FontUtils.textStyle(text: '密码'),
                                filled: true,
                                fillColor: AppColors.primaryLighter.withOpacity(0.6),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: AppColors.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: AppColors.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: AppColors.borderFocused, width: 2),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                    color: AppColors.primary,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              style: FontUtils.textStyle(text: password),
                              obscureText: _obscurePassword,
                              validator: (v) {
                                if (v == null || v.isEmpty) return '请输入密码';
                                return null;
                              },
                              onChanged: (v) => password = v,
                            ),
                            SizedBox(height: 24),
                            loading
                                ? Center(
                                    child: CircularProgressIndicator(
                                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                                    ),
                                  )
                                : ElevatedButton(
                                    onPressed: _login,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: AppColors.textOnPrimary,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      elevation: 6,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ).copyWith(
                                      backgroundColor: MaterialStateProperty.resolveWith<Color>(
                                        (Set<MaterialState> states) {
                                          if (states.contains(MaterialState.pressed)) {
                                            return AppColors.primaryPressed;
                                          }
                                          return AppColors.primary;
                                        },
                                      ),
                                    ),
                                    child: Text(
                                      '登录',
                                      style: FontUtils.textStyle(text: '登录', fontSize: 16),
                                    ),
                                  ),
                            SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pushNamed('/register'),
                                  child: Text(
                                    '注册',
                                    style: FontUtils.textStyle(text: '注册', color: AppColors.primary),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pushNamed('/forgot'),
                                  child: Text(
                                    '忘记密码？',
                                    style: FontUtils.textStyle(text: '忘记密码？', color: AppColors.primary),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
