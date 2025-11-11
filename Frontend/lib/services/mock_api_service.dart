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

class _CommentStore {
  final String postId;
  final Map<String, Map<String, dynamic>> comments = {};
  final Map<String, List<String>> commentLikes = {}; // commentId -> [userId]
  int nextCommentId = 1;

  _CommentStore(this.postId);

  String generateCommentId() => '${postId}_c_${nextCommentId++}';
}

class MockApiService {
  static final MockApiService instance = MockApiService._();
  final Map<String, _User> _users = {};
  final Map<String, _CommentStore> _commentStores = {};

  MockApiService._() {
    // 初始化一些示例评论
    _initMockComments();
  }

  void _initMockComments() {
    // 为演示帖子创建一些示例评论
    final store = _CommentStore('1');  // 为 ID 为 1 的帖子创建评论
    
    // 添加一些顶层评论
    final comment1 = {
      'id': store.generateCommentId(),
      'author': {
        'id': 'user_1',
        'name': '张三',
        'avatar': 'images/userAvatar1.png',
      },
      'content': '这篇论文的方法很有创新性，特别是在模型优化方面的改进。',
      'parentId': null,
      'replyTo': null,
      'likesCount': 5,
      'isLiked': false,
      'replies': [],
      'createdAt': DateTime.now().subtract(Duration(hours: 2)).toIso8601String(),
    };
    store.comments[comment1['id'] as String] = comment1;
    store.commentLikes[comment1['id'] as String] = [];

    // 添加带有回复的评论
    final comment2 = {
      'id': store.generateCommentId(),
      'author': {
        'id': 'user_2',
        'name': '李四',
        'avatar': 'images/userAvatar2.png',
      },
      'content': '我在实现过程中遇到了一些问题，不知道作者是如何处理数据预处理的？',
      'parentId': null,
      'replyTo': null,
      'likesCount': 3,
      'isLiked': false,
      'replies': [],
      'createdAt': DateTime.now().subtract(Duration(hours: 1)).toIso8601String(),
    };
    store.comments[comment2['id'] as String] = comment2;
    store.commentLikes[comment2['id'] as String] = [];

    // 添加一个回复
    final reply1 = {
      'id': store.generateCommentId(),
      'author': {
        'id': 'user_3',
        'name': '王五',
        'avatar': 'images/userAvatar3.png',
      },
      'content': '我建议可以先对数据进行归一化处理，这样可以提高模型的稳定性。',
      'parentId': comment2['id'],
      'replyTo': {
        'id': 'user_2',
        'name': '李四',
        'avatar': 'images/userAvatar2.png',
      },
      'likesCount': 2,
      'isLiked': false,
      'replies': [],
      'createdAt': DateTime.now().subtract(Duration(minutes: 30)).toIso8601String(),
    };
    store.comments[reply1['id'] as String] = reply1;
    store.commentLikes[reply1['id'] as String] = [];

    _commentStores[store.postId] = store;
  }

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

  // 评论相关的 mock API
  Future<MockApiResponse> getComments(String postId, {int page = 1, int pageSize = 20, String sort = 'time'}) async {
    await Future.delayed(Duration(milliseconds: 300));
    final store = _commentStores[postId];
    if (store == null) {
      return MockApiResponse(200, {
        'comments': [],
        'total': 0,
        'page': page,
        'pageSize': pageSize,
      });
    }

    // 获取顶层评论（parentId 为 null 的评论）
    final topLevelComments = store.comments.values
        .where((c) => c['parentId'] == null)
        .toList();

    // 按时间或热度排序
    if (sort == 'time') {
      topLevelComments.sort((a, b) => DateTime.parse(b['createdAt'] as String)
          .compareTo(DateTime.parse(a['createdAt'] as String)));
    } else {
      // 热度排序：按点赞数
      topLevelComments.sort((a, b) => (b['likesCount'] as int).compareTo(a['likesCount'] as int));
    }

    // 分页
    final start = (page - 1) * pageSize;
    final end = start + pageSize;
    final pagedComments = topLevelComments.skip(start).take(pageSize).toList();

    // 为每个顶层评论添加回复
    for (var comment in pagedComments) {
      final replies = store.comments.values
          .where((c) => c['parentId'] == comment['id'])
          .toList()
        ..sort((a, b) => DateTime.parse(a['createdAt'] as String)
            .compareTo(DateTime.parse(b['createdAt'] as String)));
      comment['replies'] = replies;
    }

    return MockApiResponse(200, {
      'comments': pagedComments,
      'total': topLevelComments.length,
      'page': page,
      'pageSize': pageSize,
    });
  }

  Future<MockApiResponse> createComment(String postId, String content,
      {String? parentId, String? replyToId}) async {
    await Future.delayed(Duration(milliseconds: 400));
    final store = _commentStores[postId] ?? _CommentStore(postId);
    _commentStores[postId] = store;

    Map<String, dynamic>? replyTo;
    if (replyToId != null) {
      final targetComment = store.comments[parentId ?? replyToId];
      if (targetComment != null) {
        replyTo = targetComment['author'] as Map<String, dynamic>;
      }
    }

    final comment = {
      'id': store.generateCommentId(),
      'author': {
        'id': 'current_user',  // 模拟当前用户
        'name': '当前用户',
        'avatar': 'images/userAvatar0.png',
      },
      'content': content,
      'parentId': parentId,
      'replyTo': replyTo,
      'likesCount': 0,
      'isLiked': false,
      'replies': [],
      'createdAt': DateTime.now().toIso8601String(),
    };

    store.comments[comment['id'] as String] = comment;
    store.commentLikes[comment['id'] as String] = [];

    return MockApiResponse(200, {
      'message': '评论成功',
      'comment': comment,
    });
  }

  Future<MockApiResponse> likeComment(String postId, String commentId) async {
    await Future.delayed(Duration(milliseconds: 300));
    final store = _commentStores[postId];
    if (store == null) {
      return MockApiResponse(404, {'message': '帖子不存在'});
    }

    final comment = store.comments[commentId];
    if (comment == null) {
      return MockApiResponse(404, {'message': '评论不存在'});
    }

    final userId = 'current_user';  // 模拟当前用户
    final likes = store.commentLikes[commentId]!;
    
    if (!likes.contains(userId)) {
      likes.add(userId);
      comment['likesCount'] = (comment['likesCount'] as int) + 1;
      comment['isLiked'] = true;
    }

    return MockApiResponse(200, {
      'message': '点赞成功',
      'likesCount': comment['likesCount'],
      'isLiked': comment['isLiked'],
    });
  }

  Future<MockApiResponse> unlikeComment(String postId, String commentId) async {
    await Future.delayed(Duration(milliseconds: 300));
    final store = _commentStores[postId];
    if (store == null) {
      return MockApiResponse(404, {'message': '帖子不存在'});
    }

    final comment = store.comments[commentId];
    if (comment == null) {
      return MockApiResponse(404, {'message': '评论不存在'});
    }

    final userId = 'current_user';  // 模拟当前用户
    final likes = store.commentLikes[commentId]!;
    
    if (likes.contains(userId)) {
      likes.remove(userId);
      comment['likesCount'] = (comment['likesCount'] as int) - 1;
      comment['isLiked'] = false;
    }

    return MockApiResponse(200, {
      'message': '取消点赞成功',
      'likesCount': comment['likesCount'],
      'isLiked': comment['isLiked'],
    });
  }
}
