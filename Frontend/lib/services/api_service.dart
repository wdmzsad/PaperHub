import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/app_env.dart';
import 'local_storage.dart';

/*
  ApiService 说明：

  - 自动注入 Authorization header：
    本模块在每次发起 HTTP 请求前会调用 `_buildHeaders()`，
    它会从 `LocalStorage.instance.read('accessToken')` 读取 token（如果存在），
    并将其放到请求头 `Authorization: Bearer <token>` 中。这样前端发起的请求
    会自动携带当前登录用户的凭证，后端可以在请求中对该 header 进行校验。
    
  - 自动刷新Token机制：
    当API请求返回401错误时，会自动使用refreshToken刷新accessToken，然后重试原请求。
    如果刷新失败，会清除所有token，调用方需要处理401错误并引导用户重新登录。

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
final String baseUrl = AppEnv.apiBaseUrl;

class ApiService {
  // 标记是否正在刷新，避免并发请求时多次刷新
  static bool _isRefreshing = false;
  // 存储等待刷新的请求队列
  static final List<Completer<Map<String, dynamic>>> _refreshQueue = [];

  static Map<String, String> _buildHeaders({
    bool json = true,
    bool skipAuth = false,
  }) {
    final headers = <String, String>{};
    if (json) headers['Content-Type'] = 'application/json';
    if (!skipAuth) {
      try {
        final token = LocalStorage.instance.read('accessToken');
        if (token != null && token.isNotEmpty)
          headers['Authorization'] = 'Bearer $token';
      } catch (e) {
        // ignore - LocalStorage read should normally be available
      }
    }
    return headers;
  }

  /// 刷新Token
  static Future<Map<String, dynamic>> refreshToken() async {
    final refreshToken = LocalStorage.instance.read('refreshToken');
    if (refreshToken == null || refreshToken.isEmpty) {
      throw Exception('没有refreshToken，请重新登录');
    }

    final headers = <String, String>{'Content-Type': 'application/json'};
    final resp = await http.post(
      Uri.parse('$baseUrl/auth/refresh'),
      headers: headers,
      body: jsonEncode({'refreshToken': refreshToken}),
    );
    return _parseResponse(resp);
  }

  /// 处理队列中等待的请求
  static void _processRefreshQueue(
    Map<String, dynamic>? refreshResult,
    Exception? error,
  ) {
    for (var completer in _refreshQueue) {
      if (error != null) {
        completer.completeError(error);
      } else if (refreshResult != null) {
        completer.complete(refreshResult);
      }
    }
    _refreshQueue.clear();
  }

  /// 使用刷新Token重试请求
  static Future<Map<String, dynamic>> _retryWithRefresh(
    Future<http.Response> Function() requestFn,
    String requestPath,
  ) async {
    if (_isRefreshing) {
      // 如果正在刷新，等待刷新完成
      final completer = Completer<Map<String, dynamic>>();
      _refreshQueue.add(completer);
      final refreshResult = await completer.future;

      if (refreshResult['statusCode'] == 200) {
        // 刷新成功，重试原请求
        final retryResp = await requestFn();
        return _parseResponse(retryResp);
      } else {
        return refreshResult;
      }
    }

    _isRefreshing = true;

    try {
      final refreshResult = await refreshToken();

      if (refreshResult['statusCode'] == 200) {
        final newToken = refreshResult['body']['token'] ?? '';
        final newRefreshToken = refreshResult['body']['refreshToken'] ?? '';

        // 更新本地存储
        await LocalStorage.instance.write('accessToken', newToken);
        await LocalStorage.instance.write('refreshToken', newRefreshToken);

        // 处理队列
        _processRefreshQueue(refreshResult, null);

        // 重试原请求
        final retryResp = await requestFn();
        return _parseResponse(retryResp);
      } else {
        // 刷新失败，清除token并抛出错误
        await _clearTokens();
        _processRefreshQueue(null, Exception('刷新Token失败'));
        return refreshResult;
      }
    } catch (e) {
      // 刷新失败，清除token
      await _clearTokens();
      _processRefreshQueue(null, e as Exception);
      return {
        'statusCode': 401,
        'body': {'message': '刷新Token失败，请重新登录'},
      };
    } finally {
      _isRefreshing = false;
    }
  }

  /// 清除所有Token
  static Future<void> _clearTokens() async {
    await LocalStorage.instance.delete('accessToken');
    await LocalStorage.instance.delete('refreshToken');
  }

  /// 退出登录（清除所有Token）
  static Future<void> logout() async {
    await _clearTokens();
  }

  /// 包装HTTP请求，自动处理401错误
  static Future<Map<String, dynamic>> _makeRequest(
    Future<http.Response> Function() requestFn,
    String requestPath,
  ) async {
    try {
      final resp = await requestFn();
      final result = _parseResponse(resp);

      // 如果是401错误，尝试刷新Token
      if (result['statusCode'] == 401 &&
          !requestPath.contains('/auth/refresh')) {
        return await _retryWithRefresh(requestFn, requestPath);
      }

      return result;
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> register(
    String email,
    String password,
  ) async {
    final headers = _buildHeaders();
    final resp = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _parseResponse(resp);
  }

  static Future<Map<String, dynamic>> sendVerification(String email) async {
    final headers = _buildHeaders();
    final resp = await http.post(
      Uri.parse('$baseUrl/auth/send-verification'),
      headers: headers,
      body: jsonEncode({'email': email}),
    );
    return _parseResponse(resp);
  }

  static Future<Map<String, dynamic>> verifyCode(
    String email,
    String code,
  ) async {
    final headers = _buildHeaders();
    final resp = await http.post(
      Uri.parse('$baseUrl/auth/verify'),
      headers: headers,
      body: jsonEncode({'email': email, 'code': code}),
    );
    return _parseResponse(resp);
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final headers = _buildHeaders();
    final resp = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _parseResponse(resp);
  }

  static Future<Map<String, dynamic>> getCurrentUserProfile() async {
    return await _makeRequest(
      () => http.get(Uri.parse('$baseUrl/users/me'), headers: _buildHeaders()),
      '/users/me',
    );
  }

  static Future<Map<String, dynamic>> getUserProfile(String userId) async {
    return await _makeRequest(
      () => http.get(
        Uri.parse('$baseUrl/users/$userId'),
        headers: _buildHeaders(),
      ),
      '/users/$userId',
    );
  }

  static Future<Map<String, dynamic>> updateProfile({
    required String displayName,
    String? bio,
    List<String>? researchDirections,
    String? avatarUrl,
    String? backgroundImage,
  }) async {
    final payload = <String, dynamic>{
      'name': displayName,
      if (bio != null) 'bio': bio,
      if (researchDirections != null) 'researchDirections': researchDirections,
      if (avatarUrl != null) 'avatar': avatarUrl,
      if (backgroundImage != null) 'backgroundImage': backgroundImage,
    };

    final resp = await http.put(
      Uri.parse('$baseUrl/users/me'),
      headers: _buildHeaders(),
      body: jsonEncode(payload),
    );
    return _parseResponse(resp);
  }

  static Future<Map<String, dynamic>> uploadAvatarBytes(
    Uint8List data,
    String fileName,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/users/me/avatar'),
    );
    request.headers.addAll(_buildHeaders(json: false));
    request.files.add(
      http.MultipartFile.fromBytes('file', data, filename: fileName),
    );
    final streamedResp = await request.send();
    final resp = await http.Response.fromStream(streamedResp);
    return _parseResponse(resp);
  }

  static Future<Map<String, dynamic>> uploadBackgroundBytes(
    Uint8List data,
    String fileName,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/users/me/background'),
    );
    request.headers.addAll(_buildHeaders(json: false));
    request.files.add(
      http.MultipartFile.fromBytes('file', data, filename: fileName),
    );
    final streamedResp = await request.send();
    final resp = await http.Response.fromStream(streamedResp);
    return _parseResponse(resp);
  }

  static Future<Map<String, dynamic>> followUser(String userId) async {
    return await _makeRequest(
      () => http.post(
        Uri.parse('$baseUrl/users/$userId/follow'),
        headers: _buildHeaders(),
      ),
      '/users/$userId/follow',
    );
  }

  static Future<Map<String, dynamic>> unfollowUser(String userId) async {
    return await _makeRequest(
      () => http.delete(
        Uri.parse('$baseUrl/users/$userId/follow'),
        headers: _buildHeaders(),
      ),
      '/users/$userId/follow',
    );
  }

  static Future<Map<String, dynamic>> getFollowers(
    String userId, {
    int page = 0,
    int pageSize = 20,
  }) async {
    final uri = Uri.parse('$baseUrl/users/$userId/followers').replace(
      queryParameters: {
        'page': page.toString(),
        'pageSize': pageSize.toString(),
      },
    );
    return await _makeRequest(
      () => http.get(uri, headers: _buildHeaders()),
      '/users/$userId/followers',
    );
  }

  static Future<Map<String, dynamic>> getFollowing(
    String userId, {
    int page = 0,
    int pageSize = 20,
  }) async {
    final uri = Uri.parse('$baseUrl/users/$userId/following').replace(
      queryParameters: {
        'page': page.toString(),
        'pageSize': pageSize.toString(),
      },
    );
    return await _makeRequest(
      () => http.get(uri, headers: _buildHeaders()),
      '/users/$userId/following',
    );
  }

  static Future<Map<String, dynamic>> getUserPosts(
    String userId, {
    int page = 1,
    int pageSize = 10,
  }) async {
    final uri = Uri.parse('$baseUrl/users/$userId/posts').replace(
      queryParameters: {
        'page': page.toString(),
        'pageSize': pageSize.toString(),
      },
    );
    return await _makeRequest(
      () => http.get(uri, headers: _buildHeaders()),
      '/users/$userId/posts',
    );
  }

  static Future<Map<String, dynamic>> getUserFavorites(
    String userId, {
    int page = 1,
    int pageSize = 10,
  }) async {
    final uri = Uri.parse('$baseUrl/users/$userId/favorites').replace(
      queryParameters: {
        'page': page.toString(),
        'pageSize': pageSize.toString(),
      },
    );
    return await _makeRequest(
      () => http.get(uri, headers: _buildHeaders()),
      '/users/$userId/favorites',
    );
  }

  static Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    final headers = _buildHeaders();
    final resp = await http.post(
      Uri.parse('$baseUrl/auth/request-reset'),
      headers: headers,
      body: jsonEncode({'email': email}),
    );
    return _parseResponse(resp);
  }

  /// 点赞帖子 (临时模拟实现)
  /// 返回的 body 推荐包含最新的 likesCount 和 isLiked（由后端返回以保证正确性）
  static Future<Map<String, dynamic>> likePost(
    String postId, {
    String? authToken,
  }) async {
    try {
      return await _makeRequest(
        () => http
            .post(
              Uri.parse('$baseUrl/posts/$postId/like'),
              headers: _buildHeaders(),
            )
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw Exception('请求超时，请稍后重试');
              },
            ),
        '/posts/$postId/like',
      );
    } catch (e) {
      print('点赞帖子请求异常: $e');
      rethrow;
    }
  }

  /// 取消点赞帖子 (临时模拟实现)
  static Future<Map<String, dynamic>> unlikePost(
    String postId, {
    String? authToken,
  }) async {
    try {
      return await _makeRequest(
        () => http
            .delete(
              Uri.parse('$baseUrl/posts/$postId/like'),
              headers: _buildHeaders(),
            )
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw Exception('请求超时，请稍后重试');
              },
            ),
        '/posts/$postId/like',
      );
    } catch (e) {
      print('取消点赞请求异常: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> favoritePost(String postId) async {
    try {
      return await _makeRequest(
        () => http.post(
          Uri.parse('$baseUrl/posts/$postId/favorite'),
          headers: _buildHeaders(),
        ),
        '/posts/$postId/favorite',
      );
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> unfavoritePost(String postId) async {
    try {
      return await _makeRequest(
        () => http.delete(
          Uri.parse('$baseUrl/posts/$postId/favorite'),
          headers: _buildHeaders(),
        ),
        '/posts/$postId/favorite',
      );
    } catch (e) {
      rethrow;
    }
  }

  /// 点赞评论 (临时模拟实现)
  static Future<Map<String, dynamic>> likeComment(
    String postId,
    String commentId, {
    String? authToken,
  }) async {
    try {
      return await _makeRequest(
        () => http
            .post(
              Uri.parse('$baseUrl/posts/$postId/comments/$commentId/like'),
              headers: _buildHeaders(),
            )
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw Exception('请求超时，请稍后重试');
              },
            ),
        '/posts/$postId/comments/$commentId/like',
      );
    } catch (e) {
      print('点赞评论请求异常: $e');
      rethrow;
    }
  }

  /// 取消点赞评论 (临时模拟实现)
  static Future<Map<String, dynamic>> unlikeComment(
    String postId,
    String commentId, {
    String? authToken,
  }) async {
    try {
      return await _makeRequest(
        () => http
            .delete(
              Uri.parse('$baseUrl/posts/$postId/comments/$commentId/like'),
              headers: _buildHeaders(),
            )
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw Exception('请求超时，请稍后重试');
              },
            ),
        '/posts/$postId/comments/$commentId/like',
      );
    } catch (e) {
      print('取消点赞评论请求异常: $e');
      rethrow;
    }
  }

  /// 可选：请求后端创建/触发通知（多数后端会在 like 接口内部处理通知，这里提供独立接口以备后端需要前端主动调用）
  /// 获取未读通知数量
  /// GET /notifications/unread-count
  static Future<Map<String, dynamic>> getUnreadNotificationCount() async {
    return await _makeRequest(
      () => http.get(
        Uri.parse('$baseUrl/notifications/unread-count'),
        headers: _buildHeaders(),
      ),
      '/notifications/unread-count',
    );
  }

  /// 获取赞和收藏通知
  /// GET /notifications/likes?page=0&pageSize=20
  static Future<Map<String, dynamic>> getLikesAndFavorites({
    int page = 0,
    int pageSize = 20,
  }) async {
    final uri = Uri.parse('$baseUrl/notifications/likes').replace(
      queryParameters: {
        'page': page.toString(),
        'pageSize': pageSize.toString(),
      },
    );
    return await _makeRequest(
      () => http.get(uri, headers: _buildHeaders()),
      '/notifications/likes',
    );
  }

  /// 获取关注通知
  /// GET /notifications/follows?page=0&pageSize=20
  static Future<Map<String, dynamic>> getFollows({
    int page = 0,
    int pageSize = 20,
  }) async {
    final uri = Uri.parse('$baseUrl/notifications/follows').replace(
      queryParameters: {
        'page': page.toString(),
        'pageSize': pageSize.toString(),
      },
    );
    return await _makeRequest(
      () => http.get(uri, headers: _buildHeaders()),
      '/notifications/follows',
    );
  }

  /// 获取评论和@通知
  /// GET /notifications/comments?page=0&pageSize=20
  static Future<Map<String, dynamic>> getCommentsAndMentions({
    int page = 0,
    int pageSize = 20,
  }) async {
    final uri = Uri.parse('$baseUrl/notifications/comments').replace(
      queryParameters: {
        'page': page.toString(),
        'pageSize': pageSize.toString(),
      },
    );
    return await _makeRequest(
      () => http.get(uri, headers: _buildHeaders()),
      '/notifications/comments',
    );
  }

  /// 标记通知为已读
  /// PUT /notifications/{id}/read
  static Future<Map<String, dynamic>> markNotificationAsRead(String notificationId) async {
    return await _makeRequest(
      () => http.put(
        Uri.parse('$baseUrl/notifications/$notificationId/read'),
        headers: _buildHeaders(),
      ),
      '/notifications/$notificationId/read',
    );
  }

  /// 批量标记指定类型的所有未读通知为已读
  /// PUT /notifications/mark-all-read?types=POST_LIKE,POST_FAVORITE
  static Future<Map<String, dynamic>> markAllNotificationsAsReadByTypes(List<String> types) async {
    final typesParam = types.join(',');
    return await _makeRequest(
      () => http.put(
        Uri.parse('$baseUrl/notifications/mark-all-read?types=$typesParam'),
        headers: _buildHeaders(),
      ),
      '/notifications/mark-all-read',
    );
  }

  static Future<Map<String, dynamic>> createNotification(
    Map<String, dynamic> payload, {
    String? authToken,
  }) async {
    return await _makeRequest(
      () => http.post(
        Uri.parse('$baseUrl/notifications'),
        headers: _buildHeaders(),
        body: jsonEncode(payload),
      ),
      '/notifications',
    );
  }

  static Future<Map<String, dynamic>> resetPassword(
    String email,
    String code,
    String newPassword,
  ) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/auth/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'code': code,
        'newPassword': newPassword,
      }),
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
    final uri = Uri.parse('$baseUrl/posts/$postId/comments').replace(
      queryParameters: {
        'page': page.toString(),
        'pageSize': pageSize.toString(),
        'sort': sort,
      },
    );
    return await _makeRequest(
      () => http.get(uri, headers: _buildHeaders()),
      '/posts/$postId/comments',
    );
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
    try {
      return await _makeRequest(
        () => http
            .post(
              Uri.parse('$baseUrl/posts/$postId/comments'),
              headers: _buildHeaders(),
              body: jsonEncode({
                'content': content,
                if (parentId != null) 'parentId': parentId,
                if (replyToId != null) 'replyToId': replyToId,
              }),
            )
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw Exception('请求超时，请稍后重试');
              },
            ),
        '/posts/$postId/comments',
      );
    } catch (e) {
      print('创建评论请求异常: $e');
      rethrow;
    }
  }

  /// 更新评论（仅评论作者可操作）
  static Future<Map<String, dynamic>> updateComment(
    String postId,
    String commentId,
    String content,
  ) async {
    return await _makeRequest(
      () => http.put(
        Uri.parse('$baseUrl/posts/$postId/comments/$commentId'),
        headers: _buildHeaders(),
        body: jsonEncode({'content': content}),
      ),
      '/posts/$postId/comments/$commentId',
    );
  }

  /// 删除评论（仅评论作者或帖子作者可操作）
  static Future<Map<String, dynamic>> deleteComment(
    String postId,
    String commentId,
  ) async {
    return await _makeRequest(
      () => http.delete(
        Uri.parse('$baseUrl/posts/$postId/comments/$commentId'),
        headers: _buildHeaders(),
      ),
      '/posts/$postId/comments/$commentId',
    );
  }

  /// 举报评论
  static Future<Map<String, dynamic>> reportComment(
    String postId,
    String commentId,
    String reason,
  ) async {
    return await _makeRequest(
      () => http.post(
        Uri.parse('$baseUrl/posts/$postId/comments/$commentId/report'),
        headers: _buildHeaders(),
        body: jsonEncode({'reason': reason}),
      ),
      '/posts/$postId/comments/$commentId/report',
    );
  }

  /// 获取帖子列表
  /// @param page 页码，从1开始
  /// @param pageSize 每页数量，默认20
  static Future<Map<String, dynamic>> getPosts({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/posts').replace(
        queryParameters: {
          'page': page.toString(),
          'pageSize': pageSize.toString(),
        },
      );
      print('请求帖子列表: $uri'); // 调试日志
      final result = await _makeRequest(
        () => http
            .get(uri, headers: _buildHeaders())
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw Exception('请求超时，请检查后端服务是否启动');
              },
            ),
        '/posts',
      );
      print('响应状态码: ${result['statusCode']}'); // 调试日志
      return result;
    } catch (e) {
      print('API请求异常: $e'); // 调试日志
      rethrow;
    }
  }

  /// 获取帖子详情
  /// @param postId 帖子ID
  static Future<Map<String, dynamic>> getPost(String postId) async {
    return await _makeRequest(
      () => http.get(
        Uri.parse('$baseUrl/posts/$postId'),
        headers: _buildHeaders(),
      ),
      '/posts/$postId',
    );
  }

  /// 创建帖子
  /// @param title 标题
  /// @param content 内容
  /// @param media 图片URL列表
  /// @param tags 标签列表
  /// @param doi DOI（可选）
  /// @param journal 期刊（可选）
  /// @param year 年份（可选）
  /// @param externalLinks 外部链接列表（可选）
  /// @param arxivId arXiv ID（可选）
  /// @param arxivAuthors arXiv 作者列表（可选）
  /// @param arxivPublishedDate arXiv 发布日期（可选）
  /// @param arxivCategories arXiv 分类列表（可选）
  static Future<Map<String, dynamic>> createPost({
    required String title,
    String? content,
    List<String>? media,
    List<String>? tags,
    String? doi,
    String? journal,
    int? year,
    List<String>? externalLinks,
    String? arxivId,
    List<String>? arxivAuthors,
    String? arxivPublishedDate,
    List<String>? arxivCategories,
  }) async {
    return await _makeRequest(
      () => http.post(
        Uri.parse('$baseUrl/posts'),
        headers: _buildHeaders(),
        body: jsonEncode({
          'title': title,
          if (content != null) 'content': content,
          if (media != null) 'media': media,
          if (tags != null) 'tags': tags,
          if (doi != null) 'doi': doi,
          if (journal != null) 'journal': journal,
          if (year != null) 'year': year,
          if (externalLinks != null) 'externalLinks': externalLinks,
          if (arxivId != null) 'arxivId': arxivId,
          if (arxivAuthors != null && arxivAuthors.isNotEmpty) 'arxivAuthors': arxivAuthors,
          if (arxivPublishedDate != null) 'arxivPublishedDate': arxivPublishedDate,
          if (arxivCategories != null && arxivCategories.isNotEmpty) 'arxivCategories': arxivCategories,
        }),
      ),
      '/posts',
    );
  }

  /// 删除帖子
  static Future<Map<String, dynamic>> deletePost(String postId) async {
    return await _makeRequest(
      () => http.delete(
        Uri.parse('$baseUrl/posts/$postId'),
        headers: _buildHeaders(),
      ),
      '/posts/$postId',
    );
  }

  // ==================== 聊天相关API ====================

  /// 获取会话列表
  /// GET /api/conversations
  static Future<Map<String, dynamic>> getConversations() async {
    final uri = Uri.parse('$baseUrl/api/conversations');
    return await _makeRequest(
      () => http.get(
        uri,
        headers: _buildHeaders(),
      ),
      '/api/conversations',
    );
  }

  /// 创建或获取私聊会话
  /// POST /api/conversations
  static Future<Map<String, dynamic>> createOrGetConversation(String targetUserId) async {
    final uri = Uri.parse('$baseUrl/api/conversations');
    return await _makeRequest(
      () => http.post(
        uri,
        headers: _buildHeaders(),
        body: jsonEncode({'targetUserId': int.tryParse(targetUserId) ?? 0}),
      ),
      '/api/conversations',
    );
  }

  /// 获取会话消息列表
  /// GET /api/conversations/{conversationId}/messages
  static Future<Map<String, dynamic>> getConversationMessages(
    String conversationId, {
    int page = 0,
    int pageSize = 20,
  }) async {
    final uri = Uri.parse('$baseUrl/api/conversations/$conversationId/messages').replace(
      queryParameters: {
        'page': page.toString(),
        'size': pageSize.toString(),
      },
    );
    return await _makeRequest(
      () => http.get(uri, headers: _buildHeaders()),
      '/api/conversations/$conversationId/messages',
    );
  }

  /// 发送消息
  /// POST /api/conversations/{conversationId}/messages
  static Future<Map<String, dynamic>> sendMessage(
    String conversationId,
    String content, {
    String type = 'TEXT',
    String? fileUrl,
    String? fileName,
    int? fileSize,
  }) async {
    final uri = Uri.parse('$baseUrl/api/conversations/$conversationId/messages');
    return await _makeRequest(
      () => http.post(
        uri,
        headers: _buildHeaders(),
        body: jsonEncode({
          'content': content,
          'type': type,
          if (fileUrl != null) 'fileUrl': fileUrl,
          if (fileName != null) 'fileName': fileName,
          if (fileSize != null) 'fileSize': fileSize,
        }),
      ),
      '/api/conversations/$conversationId/messages',
    );
  }

  /// 标记会话为已读
  /// PUT /api/conversations/{conversationId}/read
  static Future<Map<String, dynamic>> markConversationAsRead(String conversationId) async {
    final uri = Uri.parse('$baseUrl/api/conversations/$conversationId/read');
    return await _makeRequest(
      () => http.put(
        uri,
        headers: _buildHeaders(),
      ),
      '/api/conversations/$conversationId/read',
    );
  }

  /// 上传聊天文件
  /// POST /api/upload/chat-file
  static Future<Map<String, dynamic>> uploadChatFile(
    List<int> fileBytes,
    String fileName,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/upload/chat-file'),
    );
    request.headers.addAll(_buildHeaders(json: false));
    request.files.add(
      http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
    );
    final streamedResp = await request.send();
    final resp = await http.Response.fromStream(streamedResp);
    return _parseResponse(resp);
  }

  static Map<String, dynamic> _parseResponse(http.Response resp) {
    try {
      // 处理空响应体
      if (resp.body.isEmpty || resp.body.trim().isEmpty) {
        print('警告: 服务器返回空响应体，状态码: ${resp.statusCode}');
        // 对于 204 No Content，这是正常的
        if (resp.statusCode == 204) {
          return {
            'statusCode': resp.statusCode,
            'body': {'message': '操作成功'},
          };
        }
        // 对于 403 Forbidden，返回友好的错误消息
        if (resp.statusCode == 403) {
          return {
            'statusCode': resp.statusCode,
            'body': {'message': '权限不足，请先登录'},
          };
        }
        // 对于 401 Unauthorized，返回友好的错误消息
        if (resp.statusCode == 401) {
          return {
            'statusCode': resp.statusCode,
            'body': {'message': '未认证，请先登录'},
          };
        }
        // 其他情况返回错误
        return {
          'statusCode': resp.statusCode,
          'body': {'message': '服务器返回空响应，请稍后重试'},
        };
      }

      final body = jsonDecode(resp.body);
      return {'statusCode': resp.statusCode, 'body': body};
    } catch (e) {
      // 记录解析错误详情
      print('JSON解析失败: $e');
      print('响应状态码: ${resp.statusCode}');
      print('响应内容长度: ${resp.body.length}');
      print(
        '响应内容前100字符: ${resp.body.length > 100 ? resp.body.substring(0, 100) : resp.body}',
      );

      return {
        'statusCode': resp.statusCode,
        'body': {
          'message': resp.body.isNotEmpty
              ? '服务器响应格式错误: ${resp.body.substring(0, resp.body.length > 100 ? 100 : resp.body.length)}'
              : 'Invalid response from server',
        },
      };
    }
  }

}
