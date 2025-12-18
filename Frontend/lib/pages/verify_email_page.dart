import 'package:flutter/material.dart';
import 'package:email_validator/email_validator.dart';
import '../constants/app_colors.dart';
import '../utils/font_utils.dart';
import '../services/api_service.dart';
import '../widgets/animated_title_background.dart';

class VerifyEmailPage extends StatefulWidget {
  @override
  _VerifyEmailPageState createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  final _formKey = GlobalKey<FormState>();
  String email = '';
  String code = '';
  bool loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['email'] != null) email = args['email'];
  }

  void _showSnack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _sendAgain() async {
    if (!EmailValidator.validate(email)) {
      _showSnack('请先输入有效邮箱后再次发送');
      return;
    }
    setState(() => loading = true);
    final res = await ApiService.sendVerification(email);
    setState(() => loading = false);
    _showSnack(res['body']['message'] ?? '发送完成');
  }

  Future<void> _verify() async {
    if (email.trim().isEmpty || code.trim().isEmpty) {
      _showSnack('请输入邮箱和验证码');
      return;
    }
    setState(() => loading = true);
    final res = await ApiService.verifyCode(email.trim(), code.trim());
    setState(() => loading = false);
    if (res['statusCode'] == 200) {
      _showSnack(res['body']['message'] ?? '验证成功');
      Navigator.of(context).pushReplacementNamed('/login');
    } else {
      _showSnack(res['body']['message'] ?? '验证失败');
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
                  // 半透明验证卡片，居中靠下
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
                              '邮箱验证',
                              style: FontUtils.textStyle(
                                text: '邮箱验证',
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 16),
                            Text(
                              '请输入注册时收到的验证码',
                              style: FontUtils.textStyle(
                                text: '请输入注册时收到的验证码',
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 24),
                            TextFormField(
                              initialValue: email,
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
                              style: FontUtils.textStyle(
                                text: email,
                                color: AppColors.textPrimary,
                              ),
                              enabled: false, // 锁定邮箱输入，防止在验证码步骤修改
                            ),
                            SizedBox(height: 16),
                            TextFormField(
                              decoration: InputDecoration(
                                labelText: '验证码',
                                labelStyle: FontUtils.textStyle(text: '验证码'),
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
                              style: FontUtils.textStyle(
                                text: code,
                                color: AppColors.textPrimary,
                              ),
                              onChanged: (v) => code = v,
                            ),
                            SizedBox(height: 24),
                            loading
                                ? Center(
                                    child: CircularProgressIndicator(
                                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                                    ),
                                  )
                                : ElevatedButton(
                                    onPressed: _verify,
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
                                      '确认验证',
                                      style: FontUtils.textStyle(text: '确认验证', fontSize: 16),
                                    ),
                                  ),
                            SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
                                  child: Text(
                                    '返回登录',
                                    style: FontUtils.textStyle(text: '返回登录', color: AppColors.primary),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _sendAgain,
                                  child: Text(
                                    '重新发送验证邮件',
                                    style: FontUtils.textStyle(text: '重新发送验证邮件', color: AppColors.primary),
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
