import 'package:flutter/material.dart';
import 'package:email_validator/email_validator.dart';
import '../services/api_service.dart';
import '../widgets/video_background.dart';

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  String email = '';
  String password = '';
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

  void _showSnack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => loading = true);
    final res = await ApiService.register(email.trim(), password);
    setState(() => loading = false);
    if (res['statusCode'] == 201) {
      _showSnack(res['body']['message'] ?? '注册成功');
      Navigator.of(context).pushReplacementNamed('/verify', arguments: {'email': email.trim()});
    } else {
      _showSnack(res['body']['message'] ?? '注册失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: VideoBackground(
        videoPath: 'assets/Title_07.mp4',
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.4), // 下移卡片
                  // 半透明注册卡片，居中靠下
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
                              '注册',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 24),
                            TextFormField(
                              decoration: InputDecoration(
                                labelText: '邮箱',
                                filled: true,
                                fillColor: Color(0xFFF7FBFF).withOpacity(0.6),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Color(0xFFCBD5E1)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Color(0xFFCBD5E1)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Color(0xFF2563EB), width: 2),
                                ),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return '请输入邮箱';
                                if (!EmailValidator.validate(v.trim())) return '邮箱格式不正确';
                                return null;
                              },
                              onChanged: (v) => email = v,
                            ),
                            SizedBox(height: 16),
                            TextFormField(
                              decoration: InputDecoration(
                                labelText: '密码 (至少8位，包含字母和数字)',
                                filled: true,
                                fillColor: Color(0xFFF7FBFF).withOpacity(0.6),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Color(0xFFCBD5E1)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Color(0xFFCBD5E1)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Color(0xFF2563EB), width: 2),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                    color: Color(0xFF2563EB), // 主蓝
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              obscureText: _obscurePassword,
                              onChanged: (v) => password = v,
                              validator: (v) {
                                if (v == null || v.isEmpty) return '请输入密码';
                                if (!_validPassword(v)) return '密码至少8位并包含字母和数字';
                                return null;
                              },
                            ),
                            SizedBox(height: 16),
                            TextFormField(
                              decoration: InputDecoration(
                                labelText: '确认密码',
                                filled: true,
                                fillColor: Color(0xFFF7FBFF).withOpacity(0.6),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Color(0xFFCBD5E1)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Color(0xFFCBD5E1)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Color(0xFF2563EB), width: 2),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                                    color: Color(0xFF2563EB), // 主蓝
                                  ),
                                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                ),
                              ),
                              obscureText: _obscureConfirm,
                              onChanged: (v) => confirm = v,
                              validator: (v) {
                                if (v == null || v.isEmpty) return '请确认密码';
                                if (v != password) return '两次密码不一致';
                                return null;
                              },
                            ),
                            SizedBox(height: 24),
                            loading
                                ? Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                                    ),
                                  )
                                : ElevatedButton(
                                    onPressed: _submit,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Color(0xFF2563EB), // 主蓝
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
                                            return Color(0xFF1D4ED8); // 按下时变为 #1D4ED8
                                          }
                                          return Color(0xFF2563EB); // 默认主蓝
                                        },
                                      ),
                                    ),
                                    child: Text('注册', style: TextStyle(fontSize: 16)),
                                  ),
                            SizedBox(height: 12),
                            TextButton(
                              onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
                              child: Text('已有账号？去登录', style: TextStyle(color: Color(0xFF2563EB))),
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
