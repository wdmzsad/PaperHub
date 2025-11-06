import 'dart:convert';
import 'package:http/http.dart' as http;
import 'local_storage.dart';

/*
  ApiService 说明：

  - 自动注入 Authorization header：
    本模块在每次发起 HTTP 请求前会调用 `_buildHeaders()`，
    它会从 `LocalStorage.instance.read('auth_token')` 读取 token（如果存在），
    并将其放到请求头 `Authorization: Bearer <token>` 中。这样前端发起的请求
    会自动携带当前登录用户的凭证，后端可以在请求中对该 header 进行校验。

    注意：当前 `LocalStorage` 是一个内存存储（同步读取），如果你的实现改为
    异步（例如 SharedPreferences），需要将 `_buildHeaders` 改为异步并调整调用处。

  - baseUrl：顶部常量 `baseUrl` 指定了后端地址。请与后端确认 API 前缀与端点格式
   （例如 `/posts/{postId}/like`、`/posts/{postId}/comments/{commentId}/like`）一致。

  - 返回协议：本项目中 `ApiService._parseResponse` 将 HTTP 响应解析成
    {'statusCode': int, 'body': Map<String, dynamic>} 的形式。后端返回的 JSON
    建议包含 `message` 字段用于错误描述，成功时可选包含 `likesCount` 和 `isLiked`
    等字段以便前端做最终校准。前端在没有后端返回 `likesCount` 时会保留乐观更新的值。

  - 示例：点赞帖子
    Request: POST /posts/{postId}/like
      Headers: Authorization: Bearer <token>
      Body: none
    Response (200): {"likesCount": 123, "isLiked": true, "message": "ok"}
*/

/// TODO: 把 baseUrl 换成你后端的地址
const String baseUrl = 'http://localhost:8080';

class ApiService {
  static Map<String, String> _buildHeaders({bool json = true}) {
    final headers = <String, String>{};
    if (json) headers['Content-Type'] = 'application/json';
    try {
      final token = LocalStorage.instance.read('auth_token');
      if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';
    } catch (e) {
      // ignore - LocalStorage read should normally be available
    }
    return headers;
  }
  static Future<Map<String, dynamic>> register(String email, String password) async {
    final headers = _buildHeaders();
    final resp = await http.post(Uri.parse('$baseUrl/auth/register'), headers: headers, body: jsonEncode({'email': email, 'password': password}));
    return _parseResponse(resp);
  }

  static Future<Map<String, dynamic>> sendVerification(String email) async {
    final headers = _buildHeaders();
    final resp = await http.post(Uri.parse('$baseUrl/auth/send-verification'), headers: headers, body: jsonEncode({'email': email}));
    return _parseResponse(resp);
  }

  static Future<Map<String, dynamic>> verifyCode(String email, String code) async {
    final headers = _buildHeaders();
    final resp = await http.post(Uri.parse('$baseUrl/auth/verify'), headers: headers, body: jsonEncode({'email': email, 'code': code}));
    return _parseResponse(resp);
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final headers = _buildHeaders();
    final resp = await http.post(Uri.parse('$baseUrl/auth/login'), headers: headers, body: jsonEncode({'email': email, 'password': password}));
    return _parseResponse(resp);
  }

  static Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    final headers = _buildHeaders();
    final resp = await http.post(Uri.parse('$baseUrl/auth/request-reset'), headers: headers, body: jsonEncode({'email': email}));
    return _parseResponse(resp);
  }

  /// 点赞帖子 (临时模拟实现)
  /// 返回的 body 推荐包含最新的 likesCount 和 isLiked（由后端返回以保证正确性）
  static Future<Map<String, dynamic>> likePost(String postId, {String? authToken}) async {
    final headers = _buildHeaders();
    final resp = await http.post(Uri.parse('$baseUrl/posts/$postId/like'), headers: headers);
    return _parseResponse(resp);
  }

  /// 取消点赞帖子 (临时模拟实现)
  static Future<Map<String, dynamic>> unlikePost(String postId, {String? authToken}) async {
    final headers = _buildHeaders();
    final resp = await http.delete(Uri.parse('$baseUrl/posts/$postId/like'), headers: headers);
    return _parseResponse(resp);
  }

  /// 点赞评论 (临时模拟实现)
  static Future<Map<String, dynamic>> likeComment(String postId, String commentId, {String? authToken}) async {
    final headers = _buildHeaders();
    final resp = await http.post(Uri.parse('$baseUrl/posts/$postId/comments/$commentId/like'), headers: headers);
    return _parseResponse(resp);
  }

  /// 取消点赞评论 (临时模拟实现)
  static Future<Map<String, dynamic>> unlikeComment(String postId, String commentId, {String? authToken}) async {
    final headers = _buildHeaders();
    final resp = await http.delete(Uri.parse('$baseUrl/posts/$postId/comments/$commentId/like'), headers: headers);
    return _parseResponse(resp);
  }

  /// 可选：请求后端创建/触发通知（多数后端会在 like 接口内部处理通知，这里提供独立接口以备后端需要前端主动调用）
  static Future<Map<String, dynamic>> createNotification(Map<String, dynamic> payload, {String? authToken}) async {
    final headers = _buildHeaders();
    final resp = await http.post(Uri.parse('$baseUrl/notifications'), headers: headers, body: jsonEncode(payload));
    return _parseResponse(resp);
  }

  static Future<Map<String, dynamic>> resetPassword(String email, String code, String newPassword) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/auth/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'code': code, 'newPassword': newPassword}),
    );
    return _parseResponse(resp);
  }

  static Map<String, dynamic> _parseResponse(http.Response resp) {
    try {
      final body = jsonDecode(resp.body);
      return {
        'statusCode': resp.statusCode,
        'body': body,
      };
    } catch (e) {
      return {
        'statusCode': resp.statusCode,
        'body': {'message': 'Invalid response from server'},
      };
    }
  }
}
