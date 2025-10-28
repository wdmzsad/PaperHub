import 'dart:async';
import 'dart:math';

class MockApiResponse {
  final int statusCode;
  final Map<String, dynamic> body;
  MockApiResponse(this.statusCode, this.body);
}

class _User {
  String email;
  String password; // NOTE: 明文仅为 demo
  bool verified;
  String? verifyCode;
  DateTime? verifyExpiry;
  String? resetCode;
  DateTime? resetExpiry;

  _User(this.email, this.password, {this.verified = false});
}

class MockApiService {
  static final MockApiService instance = MockApiService._();
  final Map<String, _User> _users = {};

  MockApiService._();

  String _randCode([int len = 6]) {
    final rnd = Random();
    const chars = '0123456789';
    return List.generate(len, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  Future<MockApiResponse> register(String email, String password) async {
    await Future.delayed(Duration(milliseconds: 600)); // simulate network
    if (_users.containsKey(email)) {
      return MockApiResponse(400, {'message': '该邮箱已注册，请直接登录或找回密码'});
    }
    final user = _User(email, password, verified: false);
    user.verifyCode = _randCode();
    user.verifyExpiry = DateTime.now().add(Duration(minutes: 5)); // 验证码有效期 5 分钟
    _users[email] = user;
    return MockApiResponse(201, {
      'message': '注册成功，已发送验证邮件（模拟）。验证码:${user.verifyCode}（仅演示）',
      // 注意：真实环境绝不在响应中返回验证码
    });
  }

  Future<MockApiResponse> sendVerification(String email) async {
    await Future.delayed(Duration(milliseconds: 400));
    final u = _users[email];
    if (u == null) return MockApiResponse(404, {'message': '邮箱未注册'});
    u.verifyCode = _randCode();
    u.verifyExpiry = DateTime.now().add(Duration(minutes: 5));
    return MockApiResponse(200, {'message': '已重新发送验证邮件（模拟）。验证码:${u.verifyCode}（仅演示）'});
  }

  Future<MockApiResponse> verifyCode(String email, String code) async {
    await Future.delayed(Duration(milliseconds: 400));
    final u = _users[email];
    if (u == null) return MockApiResponse(404, {'message': '邮箱未注册'});
    if (u.verifyCode == null || u.verifyExpiry == null) return MockApiResponse(400, {'message': '无验证请求，请先注册或重新发送验证码'});
    if (DateTime.now().isAfter(u.verifyExpiry!)) return MockApiResponse(400, {'message': '验证码已过期，请重新获取验证邮件'});
    if (u.verifyCode != code) return MockApiResponse(400, {'message': '验证码不正确'});
    u.verified = true;
    u.verifyCode = null;
    u.verifyExpiry = null;
    return MockApiResponse(200, {'message': '验证成功，注册完成'});
  }

  Future<MockApiResponse> login(String email, String password) async {
    await Future.delayed(Duration(milliseconds: 500));
    final u = _users[email];
    if (u == null) return MockApiResponse(404, {'message': '邮箱未注册'});
    if (!u.verified) return MockApiResponse(403, {'message': '邮箱未验证，请先完成邮件验证'});
    if (u.password != password) return MockApiResponse(401, {'message': '密码错误'});
    final token = 'mock-token-${Random().nextInt(999999)}';
    final expiresIn = 3600; // seconds
    return MockApiResponse(200, {'message': '登录成功', 'token': token, 'expiresIn': expiresIn});
  }

  Future<MockApiResponse> requestPasswordReset(String email) async {
    await Future.delayed(Duration(milliseconds: 400));
    final u = _users[email];
    if (u == null) return MockApiResponse(404, {'message': '邮箱未注册'});
    u.resetCode = _randCode();
    u.resetExpiry = DateTime.now().add(Duration(minutes: 10)); // 重置码有效期 10 分钟
    return MockApiResponse(200, {'message': '重置邮件已发送（模拟）。验证码:${u.resetCode}（仅演示）'});
  }

  Future<MockApiResponse> resetPassword(String email, String code, String newPassword) async {
    await Future.delayed(Duration(milliseconds: 400));
    final u = _users[email];
    if (u == null) return MockApiResponse(404, {'message': '邮箱未注册'});
    if (u.resetCode == null || u.resetExpiry == null) return MockApiResponse(400, {'message': '无重置请求，请先请求重置邮件'});
    if (DateTime.now().isAfter(u.resetExpiry!)) return MockApiResponse(400, {'message': '重置验证码已过期，请重新发送'});
    if (u.resetCode != code) return MockApiResponse(400, {'message': '重置验证码不正确'});
    u.password = newPassword;
    u.resetCode = null;
    u.resetExpiry = null;
    return MockApiResponse(200, {'message': '密码已重置'});
  }
}
