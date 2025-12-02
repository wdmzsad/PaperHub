import 'package:flutter/material.dart';
import 'package:email_validator/email_validator.dart';
import '../services/api_service.dart';

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
      appBar: AppBar(title: const Text('PaperHub 注册')),
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
                    decoration: InputDecoration(
                      labelText: '密码 (至少8位，包含字母和数字)',
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
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
                  SizedBox(height: 12),
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: '确认密码',
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
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
                  SizedBox(height: 16),
                  loading
                      ? CircularProgressIndicator()
                      : ElevatedButton(onPressed: _submit, child: SizedBox(width: double.infinity, child: Center(child: Text('注册')))),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
