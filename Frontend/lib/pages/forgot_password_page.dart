import 'package:flutter/material.dart';
import 'package:email_validator/email_validator.dart';
import '../services/api_service.dart';
import '../widgets/animated_title_background.dart';
import '../constants/app_colors.dart';
import '../utils/font_utils.dart';

class ForgotPasswordPage extends StatefulWidget {
  @override
  _ForgotPasswordPageState createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  String email = '';
  bool loading = false;

  void _showSnack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _requestReset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => loading = true);
    final res = await ApiService.requestPasswordReset(email.trim());
    setState(() => loading = false);
    _showSnack(res['body']['message'] ?? '操作完成');
    if (res['statusCode'] == 200) {
      Navigator.of(context).pushNamed('/reset', arguments: {'email': email.trim()});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedTitleBackground(
        enableAnimation: false,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.24), // 下移卡片
                  // 半透明卡片，居中靠下
                  Container(
                    constraints: BoxConstraints(maxWidth: 720),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Color(0xFFE6F0FF), // 极浅冷蓝边线
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
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
                              '找回密码',
                              style: FontUtils.textStyle(
                                text: '找回密码',
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 24),
                            Text(
                              '请输入注册邮箱，我们会发送重置验证码。',
                              style: FontUtils.textStyle(
                                text: '请输入注册邮箱，我们会发送重置验证码。',
                                fontSize: 14,
                                color: AppColors.textSecondary,
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
                                  borderSide: BorderSide(color: AppColors.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: AppColors.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: AppColors.borderFocused, width: 2),
                                ),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              style: FontUtils.textStyle(
                                text: email,
                                color: AppColors.textPrimary,
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return '请输入邮箱';
                                if (!EmailValidator.validate(v.trim())) return '邮箱格式不正确';
                                return null;
                              },
                              onChanged: (v) => email = v,
                            ),
                            SizedBox(height: 24),
                            loading
                                ? Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                                    ),
                                  )
                                : ElevatedButton(
                                    onPressed: _requestReset,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary, // 主蓝
                                      foregroundColor: Colors.white, // 白字
                                      padding: EdgeInsets.symmetric(vertical: 16),
                                      elevation: 6, // 阴影
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12), // 稍大圆角
                                      ),
                                    ).copyWith(
                                      backgroundColor: MaterialStateProperty.resolveWith<Color>(
                                        (Set<MaterialState> states) {
                                          if (states.contains(MaterialState.pressed)) {
                                            return AppColors.primaryPressed; // 按下时变为 #1D4ED8
                                          }
                                          return AppColors.primary; // 默认主蓝
                                        },
                                      ),
                                    ),
                                    child: Text(
                                      '发送重置邮件',
                                      style: FontUtils.textStyle(text: '发送重置邮件', fontSize: 16),
                                    ),
                                  ),
                            SizedBox(height: 16),
                            TextButton(
                              onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
                              child: Text(
                                '返回登录',
                                style: FontUtils.textStyle(text: '返回登录', color: AppColors.primary),
                              ),
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
