import 'package:flutter/material.dart';
import 'package:email_validator/email_validator.dart';
import '../services/api_service.dart';

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
      appBar: AppBar(title: const Text('找回密码（模拟）')),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Card(
            elevation: 6,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('请输入注册邮箱，我们会发送重置验证码（模拟）。'),
                  SizedBox(height: 12),
                  TextFormField(
                    decoration: InputDecoration(labelText: '邮箱'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return '请输入邮箱';
                      if (!EmailValidator.validate(v.trim())) return '邮箱格式不正确';
                      return null;
                    },
                    onChanged: (v) => email = v,
                  ),
                  SizedBox(height: 12),
                  loading
                      ? CircularProgressIndicator()
                      : ElevatedButton(onPressed: _requestReset, child: SizedBox(width: double.infinity, child: Center(child: Text('发送重置邮件（模拟）')))),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
