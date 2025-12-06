import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/animated_title_background.dart';
import '../constants/app_colors.dart';
import '../utils/font_utils.dart';

class ResetPasswordPage extends StatefulWidget {
  @override
  _ResetPasswordPageState createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  String email = '';
  String code = '';
  String newPassword = '';
  String confirm = '';
  bool loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  bool _validPassword(String p) {
    if (p.length < 8) return false;
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(p);
    final hasNumber = RegExp(r'\d').hasMatch(p);
    return hasLetter && hasNumber;
  }

  void _showSnack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['email'] != null) email = args['email'];
  }

  Future<void> _reset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => loading = true);
    final res = await ApiService.resetPassword(email.trim(), code.trim(), newPassword);
    setState(() => loading = false);
    _showSnack(res['body']['message'] ?? '操作完成');
    if (res['statusCode'] == 200) {
      Navigator.of(context).pushReplacementNamed('/login');
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
                  SizedBox(height: MediaQuery.of(context).size.height * 0.32), // 下移卡片
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
                              '重置密码',
                              style: FontUtils.textStyle(
                                text: '重置密码',
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 24),
                            Text(
                              '输入邮件里的重置验证码与新密码。',
                              style: FontUtils.textStyle(
                                text: '输入邮件里的重置验证码与新密码。',
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
                              onChanged: (v) => email = v,
                            ),
                            SizedBox(height: 16),
                            TextFormField(
                              decoration: InputDecoration(
                                labelText: '重置验证码',
                                labelStyle: FontUtils.textStyle(text: '重置验证码'),
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
                              onChanged: (v) => code = v,
                              validator: (v) {
                                if (v == null || v.isEmpty) return '请输入验证码';
                                return null;
                              },
                            ),
                            SizedBox(height: 16),
                            TextFormField(
                              decoration: InputDecoration(
                                labelText: '新密码 (至少8位，含字母和数字)',
                                labelStyle: FontUtils.textStyle(text: '新密码 (至少8位，含字母和数字)'),
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
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                    color: AppColors.primary, // 主蓝
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              obscureText: _obscurePassword,
                              onChanged: (v) => newPassword = v,
                              validator: (v) {
                                if (v == null || v.isEmpty) return '请输入新密码';
                                if (!_validPassword(v)) return '密码至少8位并包含字母和数字';
                                return null;
                              },
                            ),
                            SizedBox(height: 16),
                            TextFormField(
                              decoration: InputDecoration(
                                labelText: '确认新密码',
                                labelStyle: FontUtils.textStyle(text: '确认新密码'),
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
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                                    color: AppColors.primary, // 主蓝
                                  ),
                                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                ),
                              ),
                              obscureText: _obscureConfirm,
                              onChanged: (v) => confirm = v,
                              validator: (v) {
                                if (v == null || v.isEmpty) return '请确认密码';
                                if (v != newPassword) return '两次密码不一致';
                                return null;
                              },
                            ),
                            SizedBox(height: 24),
                            loading
                                ? Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                                    ),
                                  )
                                : ElevatedButton(
                                    onPressed: _reset,
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
                                      '更新密码',
                                      style: FontUtils.textStyle(text: '更新密码', fontSize: 16),
                                    ),
                                  ),
                            SizedBox(height: 12),
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
