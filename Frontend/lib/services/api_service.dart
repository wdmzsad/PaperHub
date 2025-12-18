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
  // 全局 401 错误回调（当刷新 token 失败时调用）
  static void Function()? onAuthFailed;

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
      print('刷新Token失败: 没有refreshToken');
      throw Exception('没有refreshToken，请重新登录');
    }

    print('开始刷新Token，baseUrl: $baseUrl');
    final headers = <String, String>{'Content-Type': 'application/json'};
    try {
      final resp = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: headers,
        body: jsonEncode({'refreshToken': refreshToken}),
      );
      print('刷新Token响应状态码: ${resp.statusCode}');
      final result = _parseResponse(resp);
      print('刷新Token解析结果: statusCode=${result['statusCode']}');
      return result;
    } catch (e) {
      print('刷新Token请求异常: $e');
      rethrow;
    }
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
        final body = refreshResult['body'] as Map<String, dynamic>?;
        final newToken = body?['token'] as String? ?? '';
        final newRefreshToken = body?['refreshToken'] as String? ?? '';

        // 只有在新 token 有效时才更新本地存储并重试请求
        if (newToken.isNotEmpty) {
          await LocalStorage.instance.write('accessToken', newToken);
          // 确保 refreshToken 也被保存（即使后端没有返回新的，也保留旧的）
          if (newRefreshToken.isNotEmpty) {
            await LocalStorage.instance.write('refreshToken', newRefreshToken);
            print('刷新Token成功，已保存新的refreshToken');
          } else {
            // 如果后端没有返回新的 refreshToken，尝试保留旧的
            final oldRefreshToken = LocalStorage.instance.read('refreshToken');
            if (oldRefreshToken != null && oldRefreshToken.isNotEmpty) {
              print('后端未返回新的refreshToken，保留旧的');
            } else {
              print('警告: 刷新Token成功但refreshToken为空，且本地也没有旧的refreshToken');
            }
          }

          // 处理队列
          _processRefreshQueue(refreshResult, null);

          // 重试原请求
          final retryResp = await requestFn();
          return _parseResponse(retryResp);
        } else {
          // 刷新返回的 token 为空，清除 token 并触发回调
          print('刷新Token返回空token，清除本地token');
          await _clearTokens();
          _processRefreshQueue(null, Exception('刷新Token返回空token'));
          // 触发全局回调
          if (onAuthFailed != null) {
            onAuthFailed!();
          }
          return {
            'statusCode': 401,
            'body': {'message': '刷新Token失败，请重新登录'},
          };
        }
      } else {
        // 刷新失败（401/403等），清除 token 并触发回调
        print('刷新Token失败，状态码: ${refreshResult['statusCode']}，清除本地token');
        await _clearTokens();
        _processRefreshQueue(null, Exception('刷新Token失败'));
        // 触发全局回调
        if (onAuthFailed != null) {
          onAuthFailed!();
        }
        return refreshResult;
      }
    } catch (e) {
      // 刷新异常，清除 token 并触发回调
      print('刷新Token异常: $e，清除本地token');
      await _clearTokens();
      _processRefreshQueue(null, e as Exception);
      // 触发全局回调
      if (onAuthFailed != null) {
        onAuthFailed!();
      }
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

  /// 获取当前用户的隐私设置
  static Future<Map<String, dynamic>> getPrivacySettings() async {
    return await _makeRequest(
      () => http.get(
        Uri.parse('$baseUrl/users/me/privacy'),
        headers: _buildHeaders(),
      ),
      '/users/me/privacy',
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

  /// 获取当前登录用户的浏览历史（最新在前）
  /// GET /browse-history?limit=50
  static Future<Map<String, dynamic>> getBrowseHistory({int limit = 50}) async {
    return await _makeRequest(
      () => http.get(
        Uri.parse('$baseUrl/browse-history?limit=$limit'),
        headers: _buildHeaders(),
      ),
      '/browse-history',
    );
  }

  /// 记录一条浏览历史
  /// POST /browse-history  body: { postId, title }
  static Future<Map<String, dynamic>> addBrowseHistory({
    required String postId,
    required String title,
  }) async {
    final body = {'postId': postId, 'title': title};
    return await _makeRequest(
      () => http.post(
        Uri.parse('$baseUrl/browse-history'),
        headers: _buildHeaders(),
        body: jsonEncode(body),
      ),
      '/browse-history',
    );
  }

  /// 删除一条浏览历史
  /// DELETE /browse-history/{postId}
  static Future<Map<String, dynamic>> deleteBrowseHistory(String postId) async {
    return await _makeRequest(
      () => http.delete(
        Uri.parse('$baseUrl/browse-history/$postId'),
        headers: _buildHeaders(),
      ),
      '/browse-history/$postId',
    );
  }

  /// 清空当前用户的浏览历史
  /// DELETE /browse-history
  static Future<Map<String, dynamic>> clearBrowseHistory() async {
    return await _makeRequest(
      () => http.delete(
        Uri.parse('$baseUrl/browse-history'),
        headers: _buildHeaders(),
      ),
      '/browse-history',
    );
  }

  /// 获取当前登录用户的搜索历史（最新在前）
  /// GET /search-history?limit=20
  static Future<Map<String, dynamic>> getSearchHistory({int limit = 20}) async {
    return await _makeRequest(
      () => http.get(
        Uri.parse('$baseUrl/search-history?limit=$limit'),
        headers: _buildHeaders(),
      ),
      '/search-history',
    );
  }

  /// 记录一条搜索历史
  /// POST /search-history  body: { keyword, searchType }
  static Future<Map<String, dynamic>> addSearchHistory({
    required String keyword,
    required String searchType,
  }) async {
    final body = {'keyword': keyword, 'searchType': searchType};
    return await _makeRequest(
      () => http.post(
        Uri.parse('$baseUrl/search-history'),
        headers: _buildHeaders(),
        body: jsonEncode(body),
      ),
      '/search-history',
    );
  }

  /// 删除一条搜索历史
  /// DELETE /search-history/{id}
  static Future<Map<String, dynamic>> deleteSearchHistory(String id) async {
    return await _makeRequest(
      () => http.delete(
        Uri.parse('$baseUrl/search-history/$id'),
        headers: _buildHeaders(),
      ),
      '/search-history/$id',
    );
  }

  /// 清空当前用户的搜索历史
  /// DELETE /search-history
  static Future<Map<String, dynamic>> clearSearchHistory() async {
    return await _makeRequest(
      () => http.delete(
        Uri.parse('$baseUrl/search-history'),
        headers: _buildHeaders(),
      ),
      '/search-history',
    );
  }

  /// 获取用户最近搜索的关键词（用于推荐算法）
  /// GET /search-history/recent-keywords?limit=50
  static Future<Map<String, dynamic>> getRecentSearchKeywords({
    int limit = 50,
  }) async {
    return await _makeRequest(
      () => http.get(
        Uri.parse('$baseUrl/search-history/recent-keywords?limit=$limit'),
        headers: _buildHeaders(),
      ),
      '/search-history/recent-keywords',
    );
  }

  /// 获取热搜榜单
  /// GET /hot-searches?limit=20&type=keyword|tag|author
  static Future<Map<String, dynamic>> getHotSearches({
    int limit = 20,
    String? type,
  }) async {
    final uri = Uri.parse('$baseUrl/hot-searches').replace(
      queryParameters: {
        'limit': limit.toString(),
        if (type != null && type.isNotEmpty) 'type': type,
      },
    );
    return await _makeRequest(
      () => http.get(uri, headers: _buildHeaders()),
      '/hot-searches',
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

  /// 更新当前用户的隐私设置
  static Future<Map<String, dynamic>> updatePrivacySettings({
    required bool hideFollowing,
    required bool hideFollowers,
    required bool publicFavorites,
  }) async {
    final payload = <String, dynamic>{
      'hideFollowing': hideFollowing,
      'hideFollowers': hideFollowers,
      'publicFavorites': publicFavorites,
    };
    return await _makeRequest(
      () => http.put(
        Uri.parse('$baseUrl/users/me/privacy'),
        headers: _buildHeaders(),
        body: jsonEncode(payload),
      ),
      '/users/me/privacy',
    );
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

  static Future<Map<String, dynamic>> getMutualFollowers(
    String userId, {
    int page = 0,
    int pageSize = 20,
  }) async {
    final uri = Uri.parse('$baseUrl/users/$userId/mutual').replace(
      queryParameters: {
        'page': page.toString(),
        'pageSize': pageSize.toString(),
      },
    );
    return await _makeRequest(
      () => http.get(uri, headers: _buildHeaders()),
      '/users/$userId/mutual',
    );
  }

  /// 搜索用户（用于@功能）
  /// GET /users/search?q=name&type=following|all
  static Future<Map<String, dynamic>> searchUsers({
    required String query,
    String type = 'all', // 'following' 或 'all'
    int page = 0,
    int pageSize = 20,
  }) async {
    final uri = Uri.parse('$baseUrl/users/search').replace(
      queryParameters: {
        'q': query,
        'type': type,
        'page': page.toString(),
        'pageSize': pageSize.toString(),
      },
    );
    return await _makeRequest(
      () => http.get(uri, headers: _buildHeaders()),
      '/users/search',
    );
  }

  /// 搜索帖子
  /// GET /posts/search?q=keyword&type=keyword|tag&sort=hot|new&page=1&pageSize=20
  static Future<Map<String, dynamic>> searchPosts({
    required String query,
    String type = 'keyword', // 'keyword' 或 'tag'
    String sort = 'hot', // 'hot' 或 'new'
    int page = 1,
    int pageSize = 20,
  }) async {
    final uri = Uri.parse('$baseUrl/posts/search').replace(
      queryParameters: {
        'q': query,
        'type': type,
        'sort': sort,
        'page': page.toString(),
        'pageSize': pageSize.toString(),
      },
    );
    return await _makeRequest(
      () => http.get(uri, headers: _buildHeaders()),
      '/posts/search',
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
  static Future<Map<String, dynamic>> markNotificationAsRead(
    String notificationId,
  ) async {
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
  static Future<Map<String, dynamic>> markAllNotificationsAsReadByTypes(
    List<String> types,
  ) async {
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

  // ===================== 管理员后台相关 =====================

  /// 管理员搜索用户（用于"用户管理"页面）
  /// GET /admin/users?q=...&page=&pageSize=
  static Future<Map<String, dynamic>> adminSearchUsers({
    String? query,
    String? status,
    int page = 0,
    int pageSize = 20,
  }) async {
    final uri = Uri.parse('$baseUrl/admin/users').replace(
      queryParameters: {
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
        'page': page.toString(),
        'pageSize': pageSize.toString(),
      },
    );
    return await _makeRequest(
      () => http.get(uri, headers: _buildHeaders()),
      '/admin/users',
    );
  }

  /// 获取所有待审核用户（status = AUDIT）
  /// GET /admin/users/audit-list
  static Future<Map<String, dynamic>> getAuditUsers() async {
    return await _makeRequest(
      () => http.get(
        Uri.parse('$baseUrl/admin/users/audit-list'),
        headers: _buildHeaders(),
      ),
      '/admin/users/audit-list',
    );
  }

  /// 审核通过用户
  static Future<Map<String, dynamic>> adminApproveUser(String userId) async {
    return await _makeRequest(
      () => http.post(
        Uri.parse('$baseUrl/admin/users/$userId/approve'),
        headers: _buildHeaders(),
      ),
      '/admin/users/$userId/approve',
    );
  }

  /// 审核拒绝用户
  static Future<Map<String, dynamic>> adminRejectUser(
    String userId, {
    required String action,
    String? reason,
  }) async {
    return await _makeRequest(
      () => http.post(
        Uri.parse('$baseUrl/admin/users/$userId/reject'),
        headers: _buildHeaders(),
        body: jsonEncode({
          'action': action,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
        }),
      ),
      '/admin/users/$userId/reject',
    );
  }

  /// 帖子下架（占位，下架逻辑由后端实现）
  /// POST /admin/posts/{postId}/hide
  static Future<Map<String, dynamic>> adminHidePost(String postId) async {
    return await _makeRequest(
      () => http.post(
        Uri.parse('$baseUrl/admin/posts/$postId/hide'),
        headers: _buildHeaders(),
      ),
      '/admin/posts/$postId/hide',
    );
  }

  /// 管理员搜索帖子
  /// GET /admin/posts?q=&author=&page=&pageSize=
  static Future<Map<String, dynamic>> adminSearchPosts({
    String? query,
    String? author,
    int page = 0,
    int pageSize = 20,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    };
    if (query != null && query.trim().isNotEmpty) {
      params['q'] = query.trim();
    }
    if (author != null && author.trim().isNotEmpty) {
      params['author'] = author.trim();
    }
    final uri = Uri.parse(
      '$baseUrl/admin/posts',
    ).replace(queryParameters: params);
    return await _makeRequest(
      () => http.get(uri, headers: _buildHeaders()),
      '/admin/posts',
    );
  }

  /// 获取公告列表
  /// GET /admin/notices?q=&page=&pageSize=
  static Future<Map<String, dynamic>> adminGetNotices({
    String? query,
    int page = 0,
    int pageSize = 20,
  }) async {
    final uri = Uri.parse('$baseUrl/admin/notices').replace(
      queryParameters: {
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        'page': page.toString(),
        'pageSize': pageSize.toString(),
      },
    );
    return await _makeRequest(
      () => http.get(uri, headers: _buildHeaders()),
      '/admin/notices',
    );
  }

  /// 创建公告
  static Future<Map<String, dynamic>> adminCreateNotice({
    required String title,
    String? content,
    String? attachmentsJson,
    bool published = true,
  }) async {
    final payload = <String, dynamic>{
      'title': title,
      if (content != null) 'content': content,
      if (attachmentsJson != null) 'attachments': attachmentsJson,
      'published': published,
    };
    return await _makeRequest(
      () => http.post(
        Uri.parse('$baseUrl/admin/notices'),
        headers: _buildHeaders(),
        body: jsonEncode(payload),
      ),
      '/admin/notices',
    );
  }

  /// 更新公告
  static Future<Map<String, dynamic>> adminUpdateNotice({
    required String id,
    required String title,
    String? content,
    String? attachmentsJson,
    bool published = true,
  }) async {
    final payload = <String, dynamic>{
      'title': title,
      if (content != null) 'content': content,
      if (attachmentsJson != null) 'attachments': attachmentsJson,
      'published': published,
    };
    return await _makeRequest(
      () => http.put(
        Uri.parse('$baseUrl/admin/notices/$id'),
        headers: _buildHeaders(),
        body: jsonEncode(payload),
      ),
      '/admin/notices/$id',
    );
  }

  /// 删除公告
  static Future<Map<String, dynamic>> adminDeleteNotice(String id) async {
    return await _makeRequest(
      () => http.delete(
        Uri.parse('$baseUrl/admin/notices/$id'),
        headers: _buildHeaders(),
      ),
      '/admin/notices/$id',
    );
  }

  /// 获取举报列表
  /// GET /admin/reports?q=&status=&targetType=&page=&pageSize=
  static Future<Map<String, dynamic>> adminGetReports({
    String? query,
    String? status,
    String? targetType,
    int page = 0,
    int pageSize = 20,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    };
    if (query != null && query.trim().isNotEmpty) {
      params['q'] = query.trim();
    }
    if (status != null && status.isNotEmpty) {
      params['status'] = status;
    }
    if (targetType != null && targetType.isNotEmpty) {
      params['targetType'] = targetType;
    }
    final uri = Uri.parse(
      '$baseUrl/admin/reports',
    ).replace(queryParameters: params);
    return await _makeRequest(
      () => http.get(uri, headers: _buildHeaders()),
      '/admin/reports',
    );
  }

  /// 处理举报
  /// POST /admin/reports/{id}/handle
  static Future<Map<String, dynamic>> adminHandleReport({
    required String id,
    required String action, // DELETE_POST / NO_VIOLATION / BAN_USER
    String? note,
  }) async {
    final payload = <String, dynamic>{
      'action': action,
      if (note != null && note.isNotEmpty) 'resolutionNote': note,
    };
    return await _makeRequest(
      () => http.post(
        Uri.parse('$baseUrl/admin/reports/$id/handle'),
        headers: _buildHeaders(),
        body: jsonEncode(payload),
      ),
      '/admin/reports/$id/handle',
    );
  }

  /// 创建管理员申请（由管理员或超管发起）
  /// POST /admin/applications
  static Future<Map<String, dynamic>> adminCreateApplication({
    required String candidateUserId,
    required String reason,
  }) async {
    final payload = {
      'candidateUserId': int.tryParse(candidateUserId) ?? candidateUserId,
      'reason': reason,
    };
    return await _makeRequest(
      () => http.post(
        Uri.parse('$baseUrl/admin/applications'),
        headers: _buildHeaders(),
        body: jsonEncode(payload),
      ),
      '/admin/applications',
    );
  }

  /// 获取管理员申请列表（仅超级管理员）
  /// GET /admin/applications?status=&page=&pageSize=
  static Future<Map<String, dynamic>> adminGetApplications({
    String? status,
    int page = 0,
    int pageSize = 20,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    };
    if (status != null && status.isNotEmpty) {
      params['status'] = status;
    }
    final uri = Uri.parse(
      '$baseUrl/admin/applications',
    ).replace(queryParameters: params);
    return await _makeRequest(
      () => http.get(uri, headers: _buildHeaders()),
      '/admin/applications',
    );
  }

  static Future<Map<String, dynamic>> adminApproveApplication(String id) async {
    return await _makeRequest(
      () => http.post(
        Uri.parse('$baseUrl/admin/applications/$id/approve'),
        headers: _buildHeaders(),
      ),
      '/admin/applications/$id/approve',
    );
  }

  static Future<Map<String, dynamic>> adminRejectApplication(String id) async {
    return await _makeRequest(
      () => http.post(
        Uri.parse('$baseUrl/admin/applications/$id/reject'),
        headers: _buildHeaders(),
      ),
      '/admin/applications/$id/reject',
    );
  }

  /// 授予管理员权限/收回权限（仅超级管理员，配合“管理员权限管理”页）
  static Future<Map<String, dynamic>> adminGrantAdmin(String userId) async {
    return await _makeRequest(
      () => http.post(
        Uri.parse('$baseUrl/admin/permissions/$userId/grant-admin'),
        headers: _buildHeaders(),
      ),
      '/admin/permissions/$userId/grant-admin',
    );
  }

  static Future<Map<String, dynamic>> adminRevokeAdmin(String userId) async {
    return await _makeRequest(
      () => http.post(
        Uri.parse('$baseUrl/admin/permissions/$userId/revoke-admin'),
        headers: _buildHeaders(),
      ),
      '/admin/permissions/$userId/revoke-admin',
    );
  }

  /// 用户封禁 / 解封 / 禁言 / 解除禁言（管理员）
  static Future<Map<String, dynamic>> adminBanUser(String userId) async {
    return await _makeRequest(
      () => http.post(
        Uri.parse('$baseUrl/admin/users/$userId/ban'),
        headers: _buildHeaders(),
      ),
      '/admin/users/$userId/ban',
    );
  }

  static Future<Map<String, dynamic>> adminUnbanUser(String userId) async {
    return await _makeRequest(
      () => http.post(
        Uri.parse('$baseUrl/admin/users/$userId/unban'),
        headers: _buildHeaders(),
      ),
      '/admin/users/$userId/unban',
    );
  }

  static Future<Map<String, dynamic>> adminMuteUser(
    String userId, {
    required int duration,
    required String unit, // HOURS / DAYS / MONTHS / YEARS
  }) async {
    final uri = Uri.parse(
      '$baseUrl/admin/users/$userId/mute?duration=$duration&unit=$unit',
    );
    return await _makeRequest(
      () => http.post(uri, headers: _buildHeaders()),
      '/admin/users/$userId/mute',
    );
  }

  static Future<Map<String, dynamic>> adminUnmuteUser(String userId) async {
    return await _makeRequest(
      () => http.post(
        Uri.parse('$baseUrl/admin/users/$userId/unmute'),
        headers: _buildHeaders(),
      ),
      '/admin/users/$userId/unmute',
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
    List<String>? mentionIds,
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
                if (mentionIds != null && mentionIds.isNotEmpty)
                  'mentionIds': mentionIds,
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

  static Future<Map<String, dynamic>> reportUser(
    String userId,
    String reason,
  ) async {
    return await _makeRequest(
      () => http.post(
        Uri.parse('$baseUrl/api/report/user/$userId'),
        headers: _buildHeaders(),
        body: jsonEncode({'reason': reason}),
      ),
      '/api/report/user/$userId',
    );
  }

  /// 获取帖子列表
  /// @param page 页码，从1开始
  /// @param pageSize 每页数量，默认20
  /// @param disciplineTag 可选：按分区 / 标签过滤帖子
  static Future<Map<String, dynamic>> getPosts({
    int page = 1,
    int pageSize = 20,
    String? disciplineTag,
  }) async {
    try {
      final queryParameters = <String, String>{
        'page': page.toString(),
        'pageSize': pageSize.toString(),
        if (disciplineTag != null && disciplineTag.isNotEmpty)
          'tag': disciplineTag,
      };
      final uri = Uri.parse(
        '$baseUrl/posts',
      ).replace(queryParameters: queryParameters);
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

  /// 获取首页推荐帖子列表
  /// - 登录用户：后端根据研究方向、浏览历史、收藏、发帖兴趣、时间和热度综合排序
  /// - 未登录用户：后端会退化为普通按时间排序（等价于 /posts）
  static Future<Map<String, dynamic>> getRecommendedPosts({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final queryParameters = <String, String>{
        'page': page.toString(),
        'pageSize': pageSize.toString(),
      };
      final uri = Uri.parse(
        '$baseUrl/posts/recommendations',
      ).replace(queryParameters: queryParameters);
      final result = await _makeRequest(
        () => http
            .get(uri, headers: _buildHeaders())
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw Exception('请求超时，请检查后端服务是否启动');
              },
            ),
        '/posts/recommendations',
      );
      return result;
    } catch (e) {
      rethrow;
    }
  }

  /// 获取“关注”信息流
  /// 只返回当前登录用户关注的作者发布的帖子
  /// GET /posts/following?page=1&pageSize=20
  static Future<Map<String, dynamic>> getFollowingPosts({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final queryParameters = <String, String>{
        'page': page.toString(),
        'pageSize': pageSize.toString(),
      };
      final uri = Uri.parse(
        '$baseUrl/posts/following',
      ).replace(queryParameters: queryParameters);
      final result = await _makeRequest(
        () => http
            .get(uri, headers: _buildHeaders())
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw Exception('请求超时，请检查后端服务是否启动');
              },
            ),
        '/posts/following',
      );
      return result;
    } catch (e) {
      print('获取关注信息流失败: $e');
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
    required String mainDiscipline,
    String? doi,
    String? journal,
    int? year,
    List<String>? externalLinks,
    String? arxivId,
    List<String>? arxivAuthors,
    String? arxivPublishedDate,
    List<String>? arxivCategories,
    List<int>? references,
    String? status,
  }) async {
    return await _makeRequest(
      () => http.post(
        Uri.parse('$baseUrl/posts'),
        headers: _buildHeaders(),
        body: jsonEncode({
          'title': title,
          if (content != null) 'content': content,
          if (media != null) 'media': media,
          'mainDiscipline': mainDiscipline,
          if (doi != null) 'doi': doi,
          if (journal != null) 'journal': journal,
          if (year != null) 'year': year,
          if (externalLinks != null) 'externalLinks': externalLinks,
          if (arxivId != null) 'arxivId': arxivId,
          if (arxivAuthors != null && arxivAuthors.isNotEmpty)
            'arxivAuthors': arxivAuthors,
          if (arxivPublishedDate != null)
            'arxivPublishedDate': arxivPublishedDate,
          if (arxivCategories != null && arxivCategories.isNotEmpty)
            'arxivCategories': arxivCategories,
          if (references != null && references.isNotEmpty)
            'references': references,
          if (status != null) 'status': status,
        }),
      ),
      '/posts',
    );
  }

  //编辑帖子
  /// postId: 要编辑的帖子 ID
  static Future<Map<String, dynamic>> updatePost({
    required String postId,
    required String title,
    String? content,
    required List<String> media,
    required String mainDiscipline,
    String? doi,
    String? journal,
    int? year,
    List<String>? externalLinks,
    String? arxivId,
    List<String>? arxivAuthors,
    String? arxivPublishedDate,
    List<String>? arxivCategories,
    List<int>? references,
    String? status,
  }) async {
    return await _makeRequest(
      () => http.put(
        Uri.parse('$baseUrl/posts/$postId'),
        headers: _buildHeaders(),
        body: jsonEncode({
          'title': title,
          if (content != null) 'content': content,
          // 编辑时 media 传"完整列表"（已有 + 新上传）
          'media': media,
          'mainDiscipline': mainDiscipline,
          if (doi != null) 'doi': doi,
          if (journal != null) 'journal': journal,
          if (year != null) 'year': year,
          if (externalLinks != null) 'externalLinks': externalLinks,
          if (arxivId != null) 'arxivId': arxivId,
          if (arxivAuthors != null && arxivAuthors.isNotEmpty)
            'arxivAuthors': arxivAuthors,
          if (arxivPublishedDate != null)
            'arxivPublishedDate': arxivPublishedDate,
          if (arxivCategories != null && arxivCategories.isNotEmpty)
            'arxivCategories': arxivCategories,
          if (references != null && references.isNotEmpty)
            'references': references,
          if (status != null) 'status': status,
        }),
      ),
      '/posts/$postId',
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
      () => http.get(uri, headers: _buildHeaders()),
      '/api/conversations',
    );
  }

  /// 创建或获取私聊会话
  /// POST /api/conversations
  static Future<Map<String, dynamic>> createOrGetConversation(
    String targetUserId,
  ) async {
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
    int pageSize = 100,
  }) async {
    final uri = Uri.parse('$baseUrl/api/conversations/$conversationId/messages')
        .replace(
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
  /// 注意：后端不支持 sharePost 字段，分享消息的信息需要编码在 content 中
  static Future<Map<String, dynamic>> sendMessage(
    String conversationId,
    String content, {
    String type = 'TEXT',
    String? fileUrl,
    String? fileName,
    int? fileSize,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/conversations/$conversationId/messages',
    );
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

  /// 发送带媒体的消息
  /// POST /api/conversations/{conversationId}/messages
  static Future<Map<String, dynamic>> sendMessageWithMedia(
    String conversationId,
    List<String> mediaUrls, {
    String type = 'IMAGE',
    String content = '',
    String? fileName,
    int? fileSize,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/conversations/$conversationId/messages',
    );
    return await _makeRequest(
      () => http.post(
        uri,
        headers: _buildHeaders(),
        body: jsonEncode({
          'content': content,
          'type': type,
          'mediaUrls': mediaUrls,
          if (fileName != null) 'fileName': fileName,
          if (fileSize != null) 'fileSize': fileSize,
        }),
      ),
      '/api/conversations/$conversationId/messages',
    );
  }

  /// 标记会话为已读
  /// PUT /api/conversations/{conversationId}/read
  static Future<Map<String, dynamic>> markConversationAsRead(
    String conversationId,
  ) async {
    final uri = Uri.parse('$baseUrl/api/conversations/$conversationId/read');
    return await _makeRequest(
      () => http.put(uri, headers: _buildHeaders()),
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

  // ==================== 举报系统相关接口 ====================

  /// 举报帖子
  static Future<Map<String, dynamic>> reportPost({
    required int postId,
    required String description,
  }) async {
    final resp = await _retryWithRefresh(
      () => http.post(
        Uri.parse('$baseUrl/posts/$postId/report'),
        headers: _buildHeaders(),
        body: jsonEncode({'description': description}),
      ),
      '/posts/$postId/report',
    );
    return resp;
  }

  /// 获取帖子详情（支持不同状态的帖子）
  /// 兼容旧用法：获取帖子详情（支持字符串或int参数）
  static Future<Map<String, dynamic>> getPostDetail(dynamic postId) async {
    int id;
    if (postId is int) {
      id = postId;
    } else if (postId is String) {
      id = int.tryParse(postId) ?? -1;
    } else {
      throw ArgumentError('postId must be int or String');
    }
    return await getPostDetailWithStatus(id);
  }

  static Future<Map<String, dynamic>> getPostDetailWithStatus(
    int postId,
  ) async {
    final resp = await _retryWithRefresh(
      () => http.get(
        Uri.parse('$baseUrl/api/post/$postId'),
        headers: _buildHeaders(),
      ),
      '/api/post/$postId',
    );
    return resp;
  }

  /// 用户主动保存为草稿
  static Future<Map<String, dynamic>> savePostAsDraft(String postId) async {
    final resp = await _retryWithRefresh(
      () => http.post(
        Uri.parse('$baseUrl/posts/$postId/save-draft'),
        headers: _buildHeaders(),
      ),
      '/posts/$postId/save-draft',
    );
    return resp;
  }

  /// 获取用户的草稿列表
  static Future<Map<String, dynamic>> getUserDrafts({
    int page = 1,
    int pageSize = 20,
  }) async {
    final resp = await _retryWithRefresh(
      () => http.get(
        Uri.parse('$baseUrl/posts/drafts?page=$page&pageSize=$pageSize'),
        headers: _buildHeaders(),
      ),
      '/posts/drafts',
    );
    return resp;
  }

  /// 作者保存草稿（修改被下架的帖子）
  static Future<Map<String, dynamic>> saveDraft({
    required int postId,
    required String title,
    required String content,
    List<String>? media,
    List<String>? tags,
  }) async {
    final resp = await _retryWithRefresh(
      () => http.post(
        Uri.parse('$baseUrl/api/post/$postId/draft'),
        headers: _buildHeaders(),
        body: jsonEncode({
          'title': title,
          'content': content,
          'media': media ?? [],
          'tags': tags ?? [],
        }),
      ),
      '/api/post/$postId/draft',
    );
    return resp;
  }

  /// 作者提交审核
  static Future<Map<String, dynamic>> submitForAudit(int postId) async {
    final resp = await _retryWithRefresh(
      () => http.post(
        Uri.parse('$baseUrl/api/post/$postId/submit'),
        headers: _buildHeaders(),
      ),
      '/api/post/$postId/submit',
    );
    return resp;
  }

  /// 查询作者的被下架帖子列表
  static Future<Map<String, dynamic>> getAuthorRemovedPosts({
    int page = 0,
    int pageSize = 20,
  }) async {
    final resp = await _retryWithRefresh(
      () => http.get(
        Uri.parse('$baseUrl/api/post/removed?page=$page&pageSize=$pageSize'),
        headers: _buildHeaders(),
      ),
      '/api/post/removed',
    );
    return resp;
  }

  // ==================== 管理员端举报系统接口 ====================

  /// 管理员查看举报列表
  static Future<Map<String, dynamic>> adminGetReportPosts({
    String? status,
    int page = 0,
    int pageSize = 20,
  }) async {
    String url =
        '$baseUrl/api/admin/report/posts?page=$page&pageSize=$pageSize';
    if (status != null && status.isNotEmpty) {
      url += '&status=$status';
    }

    final resp = await _retryWithRefresh(
      () => http.get(Uri.parse(url), headers: _buildHeaders()),
      '/api/admin/report/posts',
    );
    return resp;
  }

  /// 管理员下架帖子
  static Future<Map<String, dynamic>> adminRemovePost({
    required int reportId,
    required String reason,
  }) async {
    final resp = await _retryWithRefresh(
      () => http.post(
        Uri.parse('$baseUrl/api/admin/report/$reportId/remove'),
        headers: _buildHeaders(),
        body: jsonEncode({'reason': reason}),
      ),
      '/api/admin/report/$reportId/remove',
    );
    return resp;
  }

  /// 管理员忽略举报
  static Future<Map<String, dynamic>> adminIgnoreReport({
    required int reportId,
    String? reason,
  }) async {
    final resp = await _retryWithRefresh(
      () => http.post(
        Uri.parse('$baseUrl/api/admin/report/$reportId/ignore'),
        headers: _buildHeaders(),
        body: jsonEncode({'reason': reason ?? '未发现违规'}),
      ),
      '/api/admin/report/$reportId/ignore',
    );
    return resp;
  }

  /// 管理员审核通过
  static Future<Map<String, dynamic>> adminApprovePost(int postId) async {
    final resp = await _retryWithRefresh(
      () => http.post(
        Uri.parse('$baseUrl/api/admin/post/$postId/approve'),
        headers: _buildHeaders(),
      ),
      '/api/admin/post/$postId/approve',
    );
    return resp;
  }

  /// 管理员拒绝审核
  static Future<Map<String, dynamic>> adminRejectPost({
    required int postId,
    required String reason,
  }) async {
    final resp = await _retryWithRefresh(
      () => http.post(
        Uri.parse('$baseUrl/api/admin/post/$postId/reject'),
        headers: _buildHeaders(),
        body: jsonEncode({'reason': reason}),
      ),
      '/api/admin/post/$postId/reject',
    );
    return resp;
  }

  /// 管理员查询待审核的帖子列表
  static Future<Map<String, dynamic>> adminGetAuditPosts({
    int page = 0,
    int pageSize = 20,
  }) async {
    final resp = await _retryWithRefresh(
      () => http.get(
        Uri.parse(
          '$baseUrl/api/admin/post/audit?page=$page&pageSize=$pageSize',
        ),
        headers: _buildHeaders(),
      ),
      '/api/admin/post/audit',
    );
    return resp;
  }

  /// 管理员统计待处理举报数量
  static Future<Map<String, dynamic>> adminCountPendingReports() async {
    final resp = await _retryWithRefresh(
      () => http.get(
        Uri.parse('$baseUrl/api/admin/report/count'),
        headers: _buildHeaders(),
      ),
      '/api/admin/report/count',
    );
    return resp;
  }

  /// 管理员审核通过AUDIT状态帖子
  static Future<Map<String, dynamic>> adminApproveAuditPost({
    required int postId,
  }) async {
    final resp = await _retryWithRefresh(
      () => http.post(
        Uri.parse('$baseUrl/admin/post/$postId/approve-audit'),
        headers: _buildHeaders(),
      ),
      '/admin/post/$postId/approve-audit',
    );
    return resp;
  }

  /// 管理员打回AUDIT状态帖子
  static Future<Map<String, dynamic>> adminRejectAuditPost({
    required int postId,
    required String reason,
  }) async {
    final resp = await _retryWithRefresh(
      () => http.post(
        Uri.parse('$baseUrl/admin/post/$postId/reject-audit'),
        headers: _buildHeaders(),
        body: jsonEncode({'reason': reason}),
      ),
      '/admin/post/$postId/reject-audit',
    );
    return resp;
  }
}
