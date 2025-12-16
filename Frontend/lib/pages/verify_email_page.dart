import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../utils/font_utils.dart';
import '../services/api_service.dart';
import 'package:email_validator/email_validator.dart';

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
      _showSnack('请输入邮箱和验证码或点击邮件中的链接');
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
      appBar: AppBar(title: const Text('邮箱验证')),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Card(
            elevation: 6,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('请输入注册时收到的验证码。'),
                SizedBox(height: 12),
                TextFormField(
                  initialValue: email,
                  decoration: InputDecoration(labelText: '邮箱'),
                  style: FontUtils.textStyle(text: email, color: AppColors.textPrimary),
                  onChanged: (v) => email = v,
                ),
                SizedBox(height: 12),
                TextFormField(
                  decoration: InputDecoration(labelText: '验证码'),
                  style: FontUtils.textStyle(text: code, color: AppColors.textPrimary),
                  onChanged: (v) => code = v,
                ),
                SizedBox(height: 12),
                ElevatedButton(onPressed: _verify, child: Text('确认验证')),
                SizedBox(height: 8),
                TextButton(onPressed: _sendAgain, child: Text('重新发送验证邮件')),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
