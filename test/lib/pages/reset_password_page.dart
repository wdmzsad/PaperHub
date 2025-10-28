import 'package:flutter/material.dart';
import '../services/mock_api_service.dart';

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
    final res = await MockApiService.instance.resetPassword(email.trim(), code.trim(), newPassword);
    setState(() => loading = false);
    _showSnack(res.body['message'] ?? '操作完成（模拟）');
    if (res.statusCode == 200) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('重置密码（模拟）')),
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
                  Text('输入邮件里的重置验证码与新密码（演示中验证码会在之前请求时被返回）。'),
                  SizedBox(height: 12),
                  TextFormField(
                    initialValue: email,
                    decoration: InputDecoration(labelText: '邮箱'),
                    onChanged: (v) => email = v,
                  ),
                  SizedBox(height: 12),
                  TextFormField(
                    decoration: InputDecoration(labelText: '重置验证码'),
                    onChanged: (v) => code = v,
                    validator: (v) {
                      if (v == null || v.isEmpty) return '请输入验证码';
                      return null;
                    },
                  ),
                  SizedBox(height: 12),
                  TextFormField(
                    decoration: InputDecoration(labelText: '新密码 (至少8位，含字母和数字)'),
                    obscureText: true,
                    onChanged: (v) => newPassword = v,
                    validator: (v) {
                      if (v == null || v.isEmpty) return '请输入新密码';
                      if (!_validPassword(v)) return '密码至少8位并包含字母和数字';
                      return null;
                    },
                  ),
                  SizedBox(height: 12),
                  TextFormField(
                    decoration: InputDecoration(labelText: '确认新密码'),
                    obscureText: true,
                    onChanged: (v) => confirm = v,
                    validator: (v) {
                      if (v == null || v.isEmpty) return '请确认密码';
                      if (v != newPassword) return '两次密码不一致';
                      return null;
                    },
                  ),
                  SizedBox(height: 12),
                  loading ? CircularProgressIndicator() : ElevatedButton(onPressed: _reset, child: Text('更新密码')),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
