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
const String baseUrl = 'http://124.70.87.106:8080';

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

  /// 获取帖子的评论列表
  /// @param postId 帖子 ID
  /// @param page 分页页码（从 1 开始）
  /// @param pageSize 每页数量，默认 20
  /// @param sort 排序方式，支持 'time'（时间）和 'hot'（热度），默认按时间
  static Future<Map<String, dynamic>> getComments(
    String postId, {
    int page = 1,
    int pageSize = 20,
    String sort = 'time',
  }) async {
    final headers = _buildHeaders();
    final uri = Uri.parse('$baseUrl/posts/$postId/comments').replace(
      queryParameters: {
        'page': page.toString(),
        'pageSize': pageSize.toString(),
        'sort': sort,
      },
    );
    final resp = await http.get(uri, headers: headers);
    return _parseResponse(resp);
  }

  /// 发布评论
  /// @param postId 帖子 ID
  /// @param content 评论内容
  /// @param parentId 回复的父评论 ID（可选，用于嵌套回复）
  /// @param replyToId 被回复用户 ID（可选，用于 @ 通知）
  static Future<Map<String, dynamic>> createComment(
    String postId,
    String content, {
    String? parentId,
    String? replyToId,
  }) async {
    final headers = _buildHeaders();
    final resp = await http.post(
      Uri.parse('$baseUrl/posts/$postId/comments'),
      headers: headers,
      body: jsonEncode({
        'content': content,
        if (parentId != null) 'parentId': parentId,
        if (replyToId != null) 'replyToId': replyToId,
      }),
    );
    return _parseResponse(resp);
  }

  /// 更新评论（仅评论作者可操作）
  static Future<Map<String, dynamic>> updateComment(
    String postId,
    String commentId,
    String content,
  ) async {
    final headers = _buildHeaders();
    final resp = await http.put(
      Uri.parse('$baseUrl/posts/$postId/comments/$commentId'),
      headers: headers,
      body: jsonEncode({'content': content}),
    );
    return _parseResponse(resp);
  }

  /// 删除评论（仅评论作者或帖子作者可操作）
  static Future<Map<String, dynamic>> deleteComment(
    String postId,
    String commentId,
  ) async {
    final headers = _buildHeaders();
    final resp = await http.delete(
      Uri.parse('$baseUrl/posts/$postId/comments/$commentId'),
      headers: headers,
    );
    return _parseResponse(resp);
  }

  /// 举报评论
  static Future<Map<String, dynamic>> reportComment(
    String postId,
    String commentId,
    String reason,
  ) async {
    final headers = _buildHeaders();
    final resp = await http.post(
      Uri.parse('$baseUrl/posts/$postId/comments/$commentId/report'),
      headers: headers,
      body: jsonEncode({'reason': reason}),
    );
    return _parseResponse(resp);
  }

  /// 获取帖子列表
  /// @param page 页码，从1开始
  /// @param pageSize 每页数量，默认20
  static Future<Map<String, dynamic>> getPosts({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final headers = _buildHeaders();
      final uri = Uri.parse('$baseUrl/posts').replace(
        queryParameters: {
          'page': page.toString(),
          'pageSize': pageSize.toString(),
        },
      );
      print('请求帖子列表: $uri'); // 调试日志
      final resp = await http.get(uri, headers: headers).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('请求超时，请检查后端服务是否启动');
        },
      );
      print('响应状态码: ${resp.statusCode}'); // 调试日志
      print('响应内容: ${resp.body}'); // 调试日志
      return _parseResponse(resp);
    } catch (e) {
      print('API请求异常: $e'); // 调试日志
      rethrow;
    }
  }

  /// 获取帖子详情
  /// @param postId 帖子ID
  static Future<Map<String, dynamic>> getPost(String postId) async {
    final headers = _buildHeaders();
    final resp = await http.get(Uri.parse('$baseUrl/posts/$postId'), headers: headers);
    return _parseResponse(resp);
  }

  /// 创建帖子
  /// @param title 标题
  /// @param content 内容
  /// @param media 图片URL列表
  /// @param tags 标签列表
  /// @param doi DOI（可选）
  /// @param journal 期刊（可选）
  /// @param year 年份（可选）
  static Future<Map<String, dynamic>> createPost({
    required String title,
    String? content,
    List<String>? media,
    List<String>? tags,
    String? doi,
    String? journal,
    int? year,
  }) async {
    final headers = _buildHeaders();
    final resp = await http.post(
      Uri.parse('$baseUrl/posts'),
      headers: headers,
      body: jsonEncode({
        'title': title,
        if (content != null) 'content': content,
        if (media != null) 'media': media,
        if (tags != null) 'tags': tags,
        if (doi != null) 'doi': doi,
        if (journal != null) 'journal': journal,
        if (year != null) 'year': year,
      }),
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
