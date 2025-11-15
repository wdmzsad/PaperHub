import 'package:flutter/material.dart';
import 'package:email_validator/email_validator.dart';
import '../services/mock_api_service.dart';
import '../services/local_storage.dart';
import '../services/api_service.dart';

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

  void _showSnack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { loading = true; errorText = null; });
    final res = await ApiService.login(email.trim(), password);
    setState(() { loading = false; });
    if (res['statusCode'] == 200) {
      final token = res['body']['token'] ?? '';
      final refreshToken = res['body']['refreshToken'] ?? '';
      // 保存双Token
      await LocalStorage.instance.write('accessToken', token);
      await LocalStorage.instance.write('refreshToken', refreshToken);
      _showSnack(res['body']['message'] ?? '登录成功');
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      _showSnack(res['body']['message'] ?? '登录失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PaperHub 登录')),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Card(
            elevation: 6,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(
                    decoration: InputDecoration(labelText: '邮箱'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return '请输入邮箱';
                      if (!EmailValidator.validate(v.trim())) return '邮箱格式不正确';
                      return null;
                    },
                    onChanged: (v) => email = v,
                  ),
                  SizedBox(height: 12),
                  TextFormField(
                    decoration: InputDecoration(labelText: '密码'),
                    obscureText: true,
                    validator: (v) {
                      if (v == null || v.isEmpty) return '请输入密码';
                      return null;
                    },
                    onChanged: (v) => password = v,
                  ),
                  SizedBox(height: 12),
                  loading
                      ? CircularProgressIndicator()
                      : ElevatedButton(onPressed: _login, child: SizedBox(width: double.infinity, child: Center(child: Text('登录')))),
                  SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    TextButton(onPressed: () => Navigator.of(context).pushNamed('/register'), child: Text('注册')),
                    TextButton(onPressed: () => Navigator.of(context).pushNamed('/forgot'), child: Text('忘记密码？')),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
