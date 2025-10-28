import 'package:flutter/material.dart';
import '../services/local_storage.dart';

class HomePage extends StatelessWidget {
  Future<void> _logout(BuildContext context) async {
    await LocalStorage.instance.delete('auth_token');
    Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('PaperHub (Demo)'),
        actions: [
          IconButton(onPressed: () => _logout(context), icon: Icon(Icons.logout)),
        ],
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('欢迎来到 PaperHub（演示版）', style: TextStyle(fontSize: 18)),
            SizedBox(height: 12),
            Text('说明：注册/验证/重置流程均由本地 MockApiService 模拟，验证码会在响应消息中回显以便演示。'),
            SizedBox(height: 20),
            ElevatedButton(onPressed: () => Navigator.of(context).pushReplacementNamed('/login'), child: Text('返回登录（模拟登出）')),
          ]),
        ),
      ),
    );
  }
}
