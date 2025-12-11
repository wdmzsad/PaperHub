import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/app_env.dart';
import '../services/api_service.dart';
import '../utils/dialog_utils.dart';
import '../constants/app_colors.dart';

enum _AdminSection {
  users,
  posts,
  reports,
  userReports,
  postReports,
  notices,
  recommend, // 管理员推荐
  applyReview,
  permissions,
}

class AdminModeScreen extends StatefulWidget {
  final String role;

  const AdminModeScreen({super.key, required this.role});

  @override
  State<AdminModeScreen> createState() => _AdminModeScreenState();
}

class _AdminModeScreenState extends State<AdminModeScreen> {
  late _AdminSection _selectedSection;

  // ==== 用户管理 ====
  String _userSearchKeyword = '';
  String _userStatusFilter = 'NON_NORMAL'; // 默认加载非正常状态的用户
  List<Map<String, dynamic>> _userList = [];
  bool _userLoading = false;
  int _userPage = 0;
  int _userTotal = 0;

  // ==== 帖子管理 ====
  String _postSearchKeyword = '';
  String _postAuthorKeyword = '';
  List<Map<String, dynamic>> _postList = [];
  bool _postLoading = false;
  int _postPage = 0;
  int _postTotal = 0;

  // ==== 举报管理 ====
  String _reportSearchKeyword = '';
  String _reportStatus = '';
  String _reportTargetType = '';
  List<Map<String, dynamic>> _reportList = [];
  bool _reportLoading = false;
  int _reportPage = 0;
  int _reportTotal = 0;
  WebSocketChannel? _wsChannel;

  // ==== 待审核用户 ====
  List<Map<String, dynamic>> _auditUserList = [];
  bool _auditUserLoading = false;
  String _auditUserSearchKeyword = '';
  int _auditUserPage = 0;
  final int _auditUserPageSize = 10;

  // ==== 公告管理 ====
  String _noticeSearchKeyword = '';
  List<Map<String, dynamic>> _noticeList = [];
  bool _noticeLoading = false;
  int _noticePage = 0;
  int _noticeTotal = 0;
  final TextEditingController _noticeTitleCtrl = TextEditingController();
  final TextEditingController _noticeContentCtrl = TextEditingController();

  // ==== 管理员申请审核 ====
  List<Map<String, dynamic>> _applicationList = [];
  bool _applicationLoading = false;
  int _applicationPage = 0;
  int _applicationTotal = 0;

  // ==== 权限管理 ====
  String _adminSearchKeyword = '';
  String _userSearchKeywordForGrant = '';
  List<Map<String, dynamic>> _adminList = [];
  List<Map<String, dynamic>> _normalUserList = [];
  bool _permissionLoading = false;
  int _adminPageLocal = 0;
  int _normalPageLocal = 0;

  // ==== 管理员推荐 ====
  String _recommendSearchKeyword = '';
  List<Map<String, dynamic>> _recommendUserList = [];
  bool _recommendLoading = false;
  int _recommendPage = 0;
  int _recommendTotal = 0;

  bool get _isSuperAdmin => widget.role.toUpperCase() == 'SUPER_ADMIN';

  static const List<_AdminMenuItem> _superAdminMenuItems = [
    _AdminMenuItem(
      section: _AdminSection.users,
      label: '用户管理',
      icon: Icons.people_outline,
    ),
    _AdminMenuItem(
      section: _AdminSection.posts,
      label: '帖子管理',
      icon: Icons.description_outlined,
    ),
    _AdminMenuItem(
      section: _AdminSection.userReports,
      label: '用户举报管理',
      icon: Icons.person_off_outlined,
    ),
    _AdminMenuItem(
      section: _AdminSection.postReports,
      label: '帖子举报管理',
      icon: Icons.article_outlined,
    ),
    _AdminMenuItem(
      section: _AdminSection.applyReview,
      label: '管理员申请审核',
      icon: Icons.assignment_turned_in_outlined,
    ),
    _AdminMenuItem(
      section: _AdminSection.permissions,
      label: '管理员权限管理',
      icon: Icons.security_outlined,
    ),
  ];

  static const List<_AdminMenuItem> _regularAdminMenuItems = [
    _AdminMenuItem(
      section: _AdminSection.userReports,
      label: '用户举报管理',
      icon: Icons.person_off_outlined,
    ),
    _AdminMenuItem(
      section: _AdminSection.postReports,
      label: '帖子举报管理',
      icon: Icons.article_outlined,
    ),
    _AdminMenuItem(
      section: _AdminSection.recommend,
      label: '管理员推荐',
      icon: Icons.person_add_outlined,
    ),
  ];

  List<_AdminMenuItem> get _menuItems =>
      _isSuperAdmin ? _superAdminMenuItems : _regularAdminMenuItems;

  @override
  void initState() {
    super.initState();
    _selectedSection = _menuItems.first.section;
    _loadInitialData();
    _connectWebSocket();
  }

  @override
  void dispose() {
    _wsChannel?.sink.close();
    _noticeTitleCtrl.dispose();
    _noticeContentCtrl.dispose();
    super.dispose();
  }

  void _connectWebSocket() {
    try {
      final wsUrl = '${AppEnv.wsBaseUrl}/ws/admin';
      _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _wsChannel!.stream.listen(
        (event) {
          try {
            final data = jsonDecode(event);
            if (data['type'] == 'post_status_update') {
              _handlePostStatusUpdate(data);
            }
          } catch (e) {
            print('WebSocket message parse error: $e');
          }
        },
        onError: (error) {
          print('WebSocket error: $error');
        },
        onDone: () {
          print('WebSocket connection closed');
        },
      );
    } catch (e) {
      print('WebSocket connection error: $e');
    }
  }

  void _handlePostStatusUpdate(Map<String, dynamic> data) {
    if (_selectedSection == _AdminSection.postReports && !_reportLoading) {
      _loadReports(page: _reportPage);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      if (_isSuperAdmin) _loadUsers(page: 0),
      if (_isSuperAdmin) _loadPosts(page: 0),
      _loadReports(page: 0),
      _loadAuditUsers(),
      if (_isSuperAdmin) _loadNotices(page: 0),
      if (_isSuperAdmin) _loadRecommendUsers(page: 0),
      if (_isSuperAdmin) _loadApplications(page: 0),
      if (_isSuperAdmin) _loadPermissionUsers(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: Row(
                children: [
                  _buildSidebar(),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _buildSectionContent(_selectedSection),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 1),
            blurRadius: 6,
            color: Colors.black.withOpacity(0.08),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.dashboard_customize_outlined, size: 28),
          const SizedBox(width: 12),
          const Text(
            'PaperHub 管理员后台',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          Chip(
            avatar: Icon(
              _isSuperAdmin ? Icons.star : Icons.verified_user_outlined,
              size: 18,
              color: Colors.white,
            ),
            label: Text(_isSuperAdmin ? '超级管理员' : '管理员'),
            backgroundColor: _isSuperAdmin
                ? Colors.deepPurpleAccent
                : Colors.blueAccent,
            labelStyle: const TextStyle(color: Colors.white),
          ),
          const SizedBox(width: 16),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.logout),
            label: const Text('返回普通模式'),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 220,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFEAEAEA))),
            ),
            child: const Text(
              '管理员后台',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                ..._menuItems.map(
                  (item) => _AdminMenuTile(
                    label: item.label,
                    icon: item.icon,
                    selected: _selectedSection == item.section,
                    onTap: () {
                      setState(() {
                        _selectedSection = item.section;
                      });
                      // 进入部分页面时如果还没加载过数据，则自动加载第一页
                      if (item.section == _AdminSection.recommend &&
                          _recommendUserList.isEmpty &&
                          !_recommendLoading) {
                        _loadRecommendUsers(page: 0);
                      }
                      if (item.section == _AdminSection.permissions &&
                          _adminList.isEmpty &&
                          _normalUserList.isEmpty &&
                          !_permissionLoading) {
                        _loadPermissionUsers();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionContent(_AdminSection section) {
    switch (section) {
      case _AdminSection.users:
        return _buildUserManagementSection();
      case _AdminSection.posts:
        return _buildPostManagementSection();
      case _AdminSection.reports:
        return _buildReportManagementSection();
      case _AdminSection.userReports:
        return _buildUserReportManagementSection();
      case _AdminSection.postReports:
        return _buildPostReportManagementSection();
      case _AdminSection.notices:
        return _buildNoticeManagementSection();
      case _AdminSection.recommend:
        return _buildRecommendAdminSection();
      case _AdminSection.applyReview:
        return _buildApplyReviewSection();
      case _AdminSection.permissions:
        return _buildPermissionManagementSection();
    }
  }

  Widget _buildUserManagementSection() {
    return _AdminSectionScaffold(
      title: '用户管理',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _SearchBar(
                  hintText: '输入用户名或邮箱（留空则查询全部）',
                  buttonLabel: '搜索',
                  onPressed: () => _loadUsers(page: 0),
                  onChanged: (v) => _userSearchKeyword = v,
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _userStatusFilter,
                items: const [
                  DropdownMenuItem(value: 'NON_NORMAL', child: Text('非正常状态')),
                  DropdownMenuItem(value: 'AUDIT', child: Text('待审核')),
                  DropdownMenuItem(value: 'BANNED', child: Text('已封禁')),
                  DropdownMenuItem(value: 'MUTE', child: Text('已禁言')),
                  DropdownMenuItem(value: 'NORMAL', child: Text('正常')),
                  DropdownMenuItem(value: '', child: Text('全部')),
                ],
                onChanged: (v) {
                  setState(() => _userStatusFilter = v ?? 'NON_NORMAL');
                  _loadUsers(page: 0);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_userLoading)
            const Center(child: CircularProgressIndicator())
          else
            _buildPlaceholderTable(
              headers: const ['用户名', '邮箱', '角色', '状态', '操作'],
              rows: _userList
                  .map(
                    (u) => [
                      Text(u['name']?.toString() ?? ''),
                      Text(u['email']?.toString() ?? ''),
                      Text(u['role']?.toString() ?? ''),
                      _buildStatusChip(u['status']?.toString()),
                      _buildUserActions(u),
                    ],
                  )
                  .toList(),
            ),
          const SizedBox(height: 12),
          _buildPagination(
            currentPage: _userPage,
            totalItems: _userTotal,
            onPageChanged: (p) => _loadUsers(page: p),
          ),
        ],
      ),
    );
  }

  Widget _buildPostManagementSection() {
    return _AdminSectionScaffold(
      title: '帖子管理',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SearchBar(
            hintText: '按标题或内容搜索帖子（留空为全部）',
            buttonLabel: '搜索',
            onChanged: (v) => _postSearchKeyword = v,
            onPressed: () => _loadPosts(page: 0),
          ),
          const SizedBox(height: 12),
          _SearchBar(
            hintText: '按作者昵称或邮箱筛选（可选）',
            buttonLabel: '筛选',
            onChanged: (v) => _postAuthorKeyword = v,
            onPressed: () => _loadPosts(page: 0),
          ),
          const SizedBox(height: 16),
          if (_postLoading)
            const Center(child: CircularProgressIndicator())
          else
            _buildPlaceholderTable(
              headers: const ['ID', '标题', '作者信息', '发布时间', '操作'],
              rows: _postList
                  .map(
                    (p) => [
                      Text(p['id']?.toString() ?? ''),
                      Text(
                        _truncateTitle(p['title']?.toString() ?? ''),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'ID: ${p['authorId'] ?? ''} | 昵称: ${p['authorName'] ?? ''} | 邮箱: ${p['authorEmail'] ?? ''}',
                      ),
                      Text(_formatPostTime(p['createdAt']?.toString())),
                      ElevatedButton(
                        onPressed: () async {
                          final id = (p['id'] ?? '').toString();
                          if (id.isEmpty) return;
                          final resp = await ApiService.adminHidePost(id);
                          final msg =
                              resp['body']?['message']?.toString() ?? '已发送下架请求';
                          if (!mounted) return;
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(msg)));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                        ),
                        child: const Text('下架'),
                      ),
                    ],
                  )
                  .toList(),
            ),
          const SizedBox(height: 12),
          _buildPagination(
            currentPage: _postPage,
            totalItems: _postTotal,
            onPageChanged: (p) => _loadPosts(page: p),
          ),
        ],
      ),
    );
  }

  Widget _buildReportManagementSection() {
    return _AdminSectionScaffold(
      title: '举报管理',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReportFilterBar(
            onSearchChanged: (v) => _reportSearchKeyword = v,
            onSearch: () => _loadReports(page: 0),
          ),
          const SizedBox(height: 16),
          if (_reportLoading)
            const Center(child: CircularProgressIndicator())
          else
            _buildPlaceholderTable(
              headers: const [
                '举报人(ID/昵称)',
                '对象类型',
                '举报时间',
                '被举报对象(ID/昵称)',
                '理由',
                '状态',
                '操作',
              ],
              rows: _reportList
                  .map(
                    (r) => [
                      Text(
                        'U${r['reporter']?['id'] ?? ''} / ${r['reporter']?['name'] ?? ''}',
                      ),
                      Text(r['targetType']?.toString() ?? ''),
                      Text(_formatPostTime(r['createdAt']?.toString())),
                      Text(_formatReportedTarget(r)),
                      Text(r['reason']?.toString() ?? ''),
                      Text(r['status']?.toString() ?? ''),
                      OutlinedButton(
                        onPressed: () =>
                            _showReportDialog(reportId: r['id'].toString()),
                        child: const Text('处理'),
                      ),
                    ],
                  )
                  .toList(),
            ),
          const SizedBox(height: 12),
          _buildPagination(
            currentPage: _reportPage,
            totalItems: _reportTotal,
            onPageChanged: (p) => _loadReports(page: p),
          ),
        ],
      ),
    );
  }

  Widget _buildUserReportManagementSection() {
    // 本地过滤和分页
    var filteredUsers = _auditUserList.where((u) {
      if (_auditUserSearchKeyword.isEmpty) return true;
      final keyword = _auditUserSearchKeyword.toLowerCase();
      final name = (u['name']?.toString() ?? '').toLowerCase();
      final email = (u['email']?.toString() ?? '').toLowerCase();
      return name.contains(keyword) || email.contains(keyword);
    }).toList();

    final totalUsers = filteredUsers.length;
    final startIndex = _auditUserPage * _auditUserPageSize;
    final endIndex = (startIndex + _auditUserPageSize).clamp(0, totalUsers);
    final paginatedUsers = filteredUsers.sublist(
      startIndex.clamp(0, totalUsers),
      endIndex,
    );

    return _AdminSectionScaffold(
      title: '用户举报管理',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _SearchBar(
                  hintText: '输入用户名或邮箱（留空则查询全部）',
                  buttonLabel: '搜索',
                  onPressed: () => setState(() => _auditUserPage = 0),
                  onChanged: (v) => _auditUserSearchKeyword = v,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_auditUserLoading)
            const Center(child: CircularProgressIndicator())
          else
            _buildPlaceholderTable(
              headers: const ['用户名', '邮箱', '角色', '状态', '操作'],
              rows: paginatedUsers
                  .map(
                    (u) => [
                      Text(u['name']?.toString() ?? ''),
                      Text(u['email']?.toString() ?? ''),
                      Text(u['role']?.toString() ?? ''),
                      _buildStatusChip(u['status']?.toString()),
                      _buildUserActions(u),
                    ],
                  )
                  .toList(),
            ),
          const SizedBox(height: 12),
          _buildPagination(
            currentPage: _auditUserPage,
            totalItems: totalUsers,
            onPageChanged: (p) => setState(() => _auditUserPage = p),
          ),
        ],
      ),
    );
  }

  Widget _buildPostReportManagementSection() {
    return _AdminSectionScaffold(
      title: '帖子举报管理',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReportFilterBar(
            onSearchChanged: (v) => _reportSearchKeyword = v,
            onSearch: () => _loadReports(page: 0),
          ),
          const SizedBox(height: 16),
          if (_reportLoading)
            const Center(child: CircularProgressIndicator())
          else
            _buildPlaceholderTable(
              headers: const [
                '举报人',
                '举报时间',
                '被举报帖子',
                '理由',
                '举报状态',
                '帖子状态',
                '操作',
              ],
              rows: _reportList
                  .map(
                    (r) => [
                      Text(
                        '${r['reporterName'] ?? ''} (ID: ${r['reporterId'] ?? ''})',
                      ),
                      Text(_formatPostTime(r['reportTime']?.toString())),
                      TextButton(
                        onPressed: () =>
                            _viewPostDetail(r['postId']?.toString()),
                        child: Text(
                          '${r['postTitle'] ?? ''} (ID: ${r['postId'] ?? ''})',
                        ),
                      ),
                      Text(r['description']?.toString() ?? ''),
                      _buildStatusChip(r['status']?.toString()),
                      _buildPostStatusChip(r['postStatusAfter']?.toString()),
                      OutlinedButton(
                        onPressed:
                            (r['status']?.toString() == 'PENDING' ||
                                r['postStatusAfter']?.toString() == 'AUDIT')
                            ? () => _showPostReportDialog(r)
                            : null,
                        child: const Text('处理'),
                      ),
                    ],
                  )
                  .toList(),
            ),
          const SizedBox(height: 12),
          _buildPagination(
            currentPage: _reportPage,
            totalItems: _reportTotal,
            onPageChanged: (p) => _loadReports(page: p),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeManagementSection() {
    return _AdminSectionScaffold(
      title: '公告管理',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _SearchBar(
                  hintText: '搜索公告标题',
                  buttonLabel: '搜索',
                  onChanged: (v) => _noticeSearchKeyword = v,
                  onPressed: () => _loadNotices(page: 0),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () {
                  _noticeTitleCtrl.clear();
                  _noticeContentCtrl.clear();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('清空编辑区'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_noticeLoading)
            const Center(child: CircularProgressIndicator())
          else
            _buildPlaceholderTable(
              headers: const ['标题', '发布时间', '状态', '操作'],
              rows: _noticeList
                  .map(
                    (n) => [
                      Text(n['title']?.toString() ?? ''),
                      Text(_formatPostTime(n['createdAt']?.toString())),
                      Text((n['published'] == true) ? '已发布' : '草稿'),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              _noticeTitleCtrl.text =
                                  n['title']?.toString() ?? '';
                              _noticeContentCtrl.text =
                                  n['content']?.toString() ?? '';
                            },
                            child: const Text('编辑'),
                          ),
                          TextButton(
                            onPressed: () =>
                                _deleteNotice((n['id'] ?? '').toString()),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('删除'),
                          ),
                        ],
                      ),
                    ],
                  )
                  .toList(),
            ),
          const SizedBox(height: 12),
          _buildPagination(
            currentPage: _noticePage,
            totalItems: _noticeTotal,
            pageSize: 5,
            onPageChanged: (p) => _loadNotices(page: p),
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 12),
          const Text(
            '发布公告',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              hintText: '公告标题',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            controller: _noticeTitleCtrl,
          ),
          const SizedBox(height: 12),
          TextField(
            minLines: 5,
            maxLines: 12,
            decoration: InputDecoration(
              hintText: '请输入公告正文',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            controller: _noticeContentCtrl,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.image_outlined),
                label: const Text('添加图片'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.link_outlined),
                label: const Text('添加链接'),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '（占位：后续可支持选择上传图片、插入外部链接，效果类似发帖编辑器）',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _createOrUpdateNotice,
              child: const Text('发布'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplyReviewSection() {
    return _AdminSectionScaffold(
      title: '管理员申请审核',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_applicationLoading)
            const Center(child: CircularProgressIndicator())
          else
            _buildPlaceholderTable(
              headers: const [
                '推荐管理员(ID/昵称)',
                '被推荐用户(ID/昵称)',
                '申请理由',
                '申请时间',
                '操作',
              ],
              rows: _applicationList
                  .map(
                    (a) => [
                      Text(
                        'A${a['recommender']?['id'] ?? ''} / ${a['recommender']?['name'] ?? ''}',
                      ),
                      Text(
                        'U${a['candidate']?['id'] ?? ''} / ${a['candidate']?['name'] ?? ''}',
                      ),
                      Text(a['reason']?.toString() ?? ''),
                      Text(_formatPostTime(a['createdAt']?.toString())),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: () =>
                                _approveApplication((a['id'] ?? '').toString()),
                            child: const Text('批准'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () =>
                                _rejectApplication((a['id'] ?? '').toString()),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                            ),
                            child: const Text('拒绝'),
                          ),
                        ],
                      ),
                    ],
                  )
                  .toList(),
            ),
          const SizedBox(height: 12),
          _buildPagination(
            currentPage: _applicationPage,
            totalItems: _applicationTotal,
            onPageChanged: (p) => _loadApplications(page: p),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionManagementSection() {
    return _AdminSectionScaffold(
      title: '管理员权限管理',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '管理员列表',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _SearchBar(
            hintText: '搜索管理员（ID / 昵称 / 邮箱）',
            buttonLabel: '搜索',
            onChanged: (v) => _adminSearchKeyword = v,
            onPressed: () => _loadPermissionUsers(),
          ),
          const SizedBox(height: 12),
          if (_permissionLoading)
            const Center(child: CircularProgressIndicator())
          else
            Builder(
              builder: (context) {
                // 如果后端列表为空，则回退到通用用户列表做拆分，避免界面完全空白
                final source = _adminList.isNotEmpty
                    ? _adminList
                    : _userList.where((u) {
                        final role = (u['role'] ?? '').toString().toUpperCase();
                        return role == 'ADMIN' || role == 'SUPER_ADMIN';
                      }).toList();
                const pageSize = 10;
                final total = source.length;
                final start = _adminPageLocal * pageSize;
                final visible = source.skip(start).take(pageSize).toList();
                return Column(
                  children: [
                    _buildPlaceholderTable(
                      headers: const ['用户名', '当前角色', '操作'],
                      rows: visible
                          .map(
                            (u) => [
                              Text(u['name']?.toString() ?? ''),
                              Text(u['role']?.toString() ?? ''),
                              if ((u['role'] ?? '').toString().toUpperCase() ==
                                  'SUPER_ADMIN')
                                const Text('无法操作')
                              else
                                OutlinedButton(
                                  onPressed: () =>
                                      _revokeAdmin((u['id'] ?? '').toString()),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.redAccent,
                                  ),
                                  child: const Text('收回权限'),
                                ),
                            ],
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                    _buildPagination(
                      currentPage: _adminPageLocal,
                      totalItems: total,
                      onPageChanged: (p) {
                        setState(() {
                          _adminPageLocal = p;
                        });
                      },
                    ),
                  ],
                );
              },
            ),
          const SizedBox(height: 32),
          const Text(
            '普通用户列表',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _SearchBar(
            hintText: '搜索普通用户（ID / 昵称 / 邮箱）',
            buttonLabel: '搜索',
            onChanged: (v) => _userSearchKeywordForGrant = v,
            onPressed: () => _loadPermissionUsers(),
          ),
          const SizedBox(height: 12),
          if (_permissionLoading)
            const SizedBox.shrink()
          else
            Builder(
              builder: (context) {
                // 同样做回退：如果后端返回为空，则从用户列表中拆出普通用户
                final source = _normalUserList.isNotEmpty
                    ? _normalUserList
                    : _userList
                          .where(
                            (u) =>
                                (u['role'] ?? '').toString().toUpperCase() ==
                                'USER',
                          )
                          .toList();
                const pageSize = 10;
                final total = source.length;
                final start = _normalPageLocal * pageSize;
                final visible = source.skip(start).take(pageSize).toList();
                return Column(
                  children: [
                    _buildPlaceholderTable(
                      headers: const ['用户名', '当前角色', '操作'],
                      rows: visible
                          .map(
                            (u) => [
                              Text(u['name']?.toString() ?? ''),
                              Text(u['role']?.toString() ?? ''),
                              ElevatedButton(
                                onPressed: () =>
                                    _grantAdmin((u['id'] ?? '').toString()),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                                child: const Text('授权为管理员'),
                              ),
                            ],
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                    _buildPagination(
                      currentPage: _normalPageLocal,
                      totalItems: total,
                      onPageChanged: (p) {
                        setState(() {
                          _normalPageLocal = p;
                        });
                      },
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderTable({
    required List<String> headers,
    required List<List<Widget>> rows,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Card(
          margin: EdgeInsets.zero,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                columns: headers
                    .map((h) => DataColumn(label: Text(h)))
                    .toList(),
                rows: rows
                    .map(
                      (cells) => DataRow(
                        cells: cells.map((cell) => DataCell(cell)).toList(),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showReportDialog({String? reportId}) {
    final report = _reportList.firstWhere(
      (r) => r['id'].toString() == reportId,
    );
    final targetType = report['targetType']?.toString();

    if (targetType == 'USER') {
      _showUserReportDialog(report);
    } else {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('处理举报'),
          content: const Text('该举报类型暂不支持'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    }
  }

  void _showUserReportDialog(Map<String, dynamic> report) {
    final userId = report['reportedUser']?['id']?.toString();
    if (userId == null) return;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('处理用户举报'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('举报人: ${report['reporter']?['name']}'),
            const SizedBox(height: 8),
            Text('被举报用户: ${report['reportedUser']?['name']}'),
            const SizedBox(height: 8),
            Text('举报理由: ${report['reason']}'),
            const SizedBox(height: 16),
            const Text('请选择处理方式：'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _handleBanUser(userId);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('封禁用户'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _handleUnbanUser(userId);
                  },
                  child: const Text('解除封禁'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _handleMuteUser(userId);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                  child: const Text('禁言'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _handleUnmuteUser(userId);
                  },
                  child: const Text('解除禁言'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleBanUser(String userId) async {
    try {
      final resp = await ApiService.adminBanUser(userId);
      if (resp['statusCode'] == 200) {
        _showSnackBar('用户已封禁');
        _loadReports(page: _reportPage);
      } else {
        _showSnackBar('操作失败: ${resp['body']?['message'] ?? '未知错误'}');
      }
    } catch (e) {
      _showSnackBar('操作失败: $e');
    }
  }

  Future<void> _handleUnbanUser(String userId) async {
    try {
      final resp = await ApiService.adminUnbanUser(userId);
      if (resp['statusCode'] == 200) {
        _showSnackBar('已解除封禁');
        _loadReports(page: _reportPage);
      } else {
        _showSnackBar('操作失败: ${resp['body']?['message'] ?? '未知错误'}');
      }
    } catch (e) {
      _showSnackBar('操作失败: $e');
    }
  }

  Future<void> _handleMuteUser(String userId) async {
    final durationController = TextEditingController(text: '7');
    String selectedUnit = 'DAYS';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('禁言用户'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: durationController,
                decoration: const InputDecoration(
                  labelText: '禁言时长',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedUnit,
                decoration: const InputDecoration(
                  labelText: '时间单位',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'HOURS', child: Text('小时')),
                  DropdownMenuItem(value: 'DAYS', child: Text('天')),
                  DropdownMenuItem(value: 'MONTHS', child: Text('月')),
                  DropdownMenuItem(value: 'YEARS', child: Text('年')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => selectedUnit = value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                final duration = int.tryParse(durationController.text);
                if (duration == null || duration <= 0) {
                  _showSnackBar('请输入有效的时长');
                  return;
                }
                Navigator.pop(ctx);
                try {
                  final resp = await ApiService.adminMuteUser(
                    userId,
                    duration: duration,
                    unit: selectedUnit,
                  );
                  if (resp['statusCode'] == 200) {
                    _showSnackBar('用户已禁言');
                    _loadReports(page: _reportPage);
                  } else {
                    _showSnackBar(
                      '操作失败: ${resp['body']?['message'] ?? '未知错误'}',
                    );
                  }
                } catch (e) {
                  _showSnackBar('操作失败: $e');
                }
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleUnmuteUser(String userId) async {
    try {
      final resp = await ApiService.adminUnmuteUser(userId);
      if (resp['statusCode'] == 200) {
        _showSnackBar('已解除禁言');
        _loadReports(page: _reportPage);
      } else {
        _showSnackBar('操作失败: ${resp['body']?['message'] ?? '未知错误'}');
      }
    } catch (e) {
      _showSnackBar('操作失败: $e');
    }
  }

  void _showPostReportDialog(Map<String, dynamic> report) {
    final reasonController = TextEditingController();
    final postStatus = report['postStatusAfter']?.toString();
    final isAudit = postStatus == 'AUDIT';

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4), // 统一半透明遮罩
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.dialogBackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0), // 统一圆角
        ),
        insetPadding: const EdgeInsets.all(24.0),
        titlePadding: const EdgeInsets.only(
          top: 24.0,
          left: 24.0,
          right: 24.0,
          bottom: 16.0,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24.0),
        actionsPadding: const EdgeInsets.all(24.0),
        title: Text(
          isAudit ? '处理待审核帖子' : '处理帖子举报',
          style: TextStyle(
            fontSize: 18.0,
            fontWeight: FontWeight.w700,
            color: AppColors.dialogTitle,
          ),
          textAlign: TextAlign.center,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isAudit) ...[
                Text(
                  '举报人: ${report['reporterName']}',
                  style: TextStyle(
                    fontSize: 14.0,
                    color: AppColors.dialogContent,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                '举报人: ${report['reporterName']}',
                style: TextStyle(
                  fontSize: 14.0,
                  color: AppColors.dialogContent,
                ),
              ),
              Text(
                '帖子: ${report['postTitle']}',
                style: TextStyle(
                  fontSize: 14.0,
                  color: AppColors.dialogContent,
                ),
              ),
              const SizedBox(height: 8),
              if (!isAudit) ...[
                Text(
                  '举报理由: ${report['description']}',
                  style: TextStyle(
                    fontSize: 14.0,
                    color: AppColors.dialogContent,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (isAudit) const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  labelText: '处理原因',
                  hintText: isAudit ? '请输入打回原因（审核通过可留空）' : '请输入下架或忽略的原因',
                  filled: true,
                  fillColor: AppColors.backgroundLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          if (isAudit) ...[
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _handleRejectAudit(
                  report['postId'],
                  reasonController.text,
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('继续打回'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _handleApproveAudit(report['postId']);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('审核通过'),
            ),
          ] else ...[
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _handleIgnoreReport(report['id'], reasonController.text);
              },
              child: const Text('忽略举报'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _handleRemovePost(report['id'], reasonController.text);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('打回帖子'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleRemovePost(int reportId, String reason) async {
    try {
      final resp = await ApiService.adminRemovePost(
        reportId: reportId,
        reason: reason.isEmpty ? '违规内容' : reason,
      );
      if (resp['statusCode'] == 200 && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('帖子已打回')));
        _loadReports(page: _reportPage);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('操作失败: $e')));
      }
    }
  }

  Future<void> _handleIgnoreReport(int reportId, String reason) async {
    try {
      final resp = await ApiService.adminIgnoreReport(
        reportId: reportId,
        reason: reason.isEmpty ? '未发现违规' : reason,
      );
      if (resp['statusCode'] == 200 && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已忽略该举报')));
        _loadReports(page: _reportPage);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('操作失败: $e')));
      }
    }
  }

  Future<void> _handleRejectAudit(int postId, String reason) async {
    try {
      final resp = await ApiService.adminRejectAuditPost(
        postId: postId,
        reason: reason.isEmpty ? '不符合发布要求' : reason,
      );
      if (resp['statusCode'] == 200 && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已打回草稿')));
        _loadReports(page: _reportPage);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('操作失败: $e')));
      }
    }
  }

  Future<void> _handleApproveAudit(int postId) async {
    try {
      final resp = await ApiService.adminApproveAuditPost(postId: postId);
      if (resp['statusCode'] == 200 && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('审核通过')));
        _loadReports(page: _reportPage);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('操作失败: $e')));
      }
    }
  }

  void _viewPostDetail(String? postId) async {
    if (postId == null || postId.isEmpty) return;
    try {
      final resp = await ApiService.getPostDetail(postId);
      if (resp['statusCode'] == 200 && mounted) {
        final postData = resp['body'];
        showDialog(
          context: context,
          builder: (ctx) => Dialog(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              height: MediaQuery.of(context).size.height * 0.8,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '帖子详情',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            postData['title'] ?? '',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '作者: ${postData['author']?['name'] ?? ''}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '状态: ${postData['status'] ?? ''}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          if (postData['hiddenReason'] != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              '打回原因: ${postData['hiddenReason']}',
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Text(postData['content'] ?? ''),
                          const SizedBox(height: 16),
                          if (postData['media'] != null &&
                              (postData['media'] as List).isNotEmpty)
                            ...((postData['media'] as List).map(
                              (url) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Image.network(
                                  url,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Text('图片加载失败'),
                                ),
                              ),
                            )),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('无法查看帖子: $e')));
      }
    }
  }

  // ===================== 数据加载 & 动作 =====================

  Future<void> _loadUsers({int page = 0}) async {
    setState(() => _userLoading = true);
    try {
      const pageSize = 10;
      final resp = await ApiService.adminSearchUsers(
        query: _userSearchKeyword,
        status: _userStatusFilter,
        page: page,
        pageSize: pageSize,
      );
      final body = resp['body'] as Map<String, dynamic>?;
      _userList =
          (body?['users'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      _userTotal = (body?['total'] as num?)?.toInt() ?? 0;
      _userPage = (body?['page'] as num?)?.toInt() ?? page;
    } finally {
      if (mounted) setState(() => _userLoading = false);
    }
  }

  Future<void> _loadNotices({int page = 0}) async {
    setState(() => _noticeLoading = true);
    try {
      const pageSize = 5;
      final resp = await ApiService.adminGetNotices(
        query: _noticeSearchKeyword,
        page: page,
        pageSize: pageSize,
      );
      final body = resp['body'] as Map<String, dynamic>?;
      _noticeList =
          (body?['notices'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      _noticeTotal = (body?['total'] as num?)?.toInt() ?? 0;
      _noticePage = (body?['page'] as num?)?.toInt() ?? page;
    } finally {
      if (mounted) setState(() => _noticeLoading = false);
    }
  }

  Future<void> _loadReports({int page = 0}) async {
    setState(() => _reportLoading = true);
    try {
      const pageSize = 10;
      final resp = await ApiService.adminGetReportPosts(
        status: _reportStatus.isEmpty ? null : _reportStatus,
        page: page,
        pageSize: pageSize,
      );
      final body = resp['body'] as Map<String, dynamic>?;
      _reportList = (body != null && body['reports'] is List)
          ? (body['reports'] as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList()
          : [];
      _reportTotal = (body?['total'] as num?)?.toInt() ?? 0;
      _reportPage = (body?['page'] as num?)?.toInt() ?? page;
    } finally {
      if (mounted) setState(() => _reportLoading = false);
    }
  }

  Future<void> _loadAuditUsers() async {
    setState(() => _auditUserLoading = true);
    try {
      final resp = await ApiService.getAuditUsers();
      final body = resp['body'] as Map<String, dynamic>?;
      _auditUserList = (body != null && body['users'] is List)
          ? (body['users'] as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList()
          : [];
    } finally {
      if (mounted) setState(() => _auditUserLoading = false);
    }
  }

  Future<void> _loadApplications({int page = 0}) async {
    setState(() => _applicationLoading = true);
    try {
      const pageSize = 10;
      final resp = await ApiService.adminGetApplications(
        status: 'PENDING',
        page: page,
        pageSize: pageSize,
      );
      final body = resp['body'] as Map<String, dynamic>?;
      _applicationList =
          (body?['applications'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      _applicationTotal = (body?['total'] as num?)?.toInt() ?? 0;
      _applicationPage = (body?['page'] as num?)?.toInt() ?? page;
    } finally {
      if (mounted) setState(() => _applicationLoading = false);
    }
  }

  Future<void> _loadPermissionUsers() async {
    setState(() => _permissionLoading = true);
    try {
      // 每次加载时重置本地分页页码
      _adminPageLocal = 0;
      _normalPageLocal = 0;
      // 管理员列表
      final adminResp = await ApiService.adminSearchUsers(
        query: _adminSearchKeyword,
        page: 0,
        pageSize: 100,
      );
      final adminBody = adminResp['body'] as Map<String, dynamic>?;
      final allUsers =
          (adminBody?['users'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      _adminList = allUsers
          .where((u) => u['role'] == 'ADMIN' || u['role'] == 'SUPER_ADMIN')
          .toList();

      // 普通用户列表
      final userResp = await ApiService.adminSearchUsers(
        query: _userSearchKeywordForGrant,
        page: 0,
        pageSize: 100,
      );
      final userBody = userResp['body'] as Map<String, dynamic>?;
      final allUsers2 =
          (userBody?['users'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      _normalUserList = allUsers2
          .where((u) => (u['role'] ?? '').toString() == 'USER')
          .toList();
    } finally {
      if (mounted) setState(() => _permissionLoading = false);
    }
  }

  Future<void> _createOrUpdateNotice() async {
    final title = _noticeTitleCtrl.text.trim();
    final content = _noticeContentCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('公告标题不能为空')));
      return;
    }
    setState(() => _noticeLoading = true);
    try {
      await ApiService.adminCreateNotice(
        title: title,
        content: content.isEmpty ? null : content,
        published: true,
      );
      await _loadNotices();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('公告发布成功')));
    } finally {
      if (mounted) setState(() => _noticeLoading = false);
    }
  }

  Future<void> _deleteNotice(String id) async {
    if (id.isEmpty) return;
    await ApiService.adminDeleteNotice(id);
    await _loadNotices();
  }

  Future<void> _approveApplication(String id) async {
    if (id.isEmpty) return;
    await ApiService.adminApproveApplication(id);
    await _loadApplications();
  }

  Future<void> _rejectApplication(String id) async {
    if (id.isEmpty) return;
    await ApiService.adminRejectApplication(id);
    await _loadApplications();
  }

  Future<void> _grantAdmin(String userId) async {
    if (userId.isEmpty) return;
    await ApiService.adminGrantAdmin(userId);
    await _loadPermissionUsers();
  }

  Future<void> _revokeAdmin(String userId) async {
    if (userId.isEmpty) return;
    await ApiService.adminRevokeAdmin(userId);
    await _loadPermissionUsers();
  }

  String _formatReportedTarget(Map<String, dynamic> r) {
    final targetType = r['targetType']?.toString() ?? '';
    if (targetType == 'POST') {
      return 'POST ${r['postId'] ?? ''}';
    } else if (targetType == 'COMMENT') {
      return 'COMMENT ${r['commentId'] ?? ''}';
    } else if (targetType == 'USER') {
      final user = r['reportedUser'] as Map<String, dynamic>?;
      return 'U${user?['id'] ?? ''} / ${user?['name'] ?? ''}';
    }
    return '';
  }

  Future<void> _loadPosts({int page = 0}) async {
    setState(() => _postLoading = true);
    try {
      const pageSize = 10;
      final resp = await ApiService.adminSearchPosts(
        query: _postSearchKeyword,
        author: _postAuthorKeyword,
        page: page,
        pageSize: pageSize,
      );
      final body = resp['body'] as Map<String, dynamic>?;
      _postList =
          (body?['posts'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      _postTotal = (body?['total'] as num?)?.toInt() ?? 0;
      _postPage = (body?['page'] as num?)?.toInt() ?? page;
    } finally {
      if (mounted) setState(() => _postLoading = false);
    }
  }

  Future<void> _loadRecommendUsers({int page = 0}) async {
    setState(() => _recommendLoading = true);
    try {
      const pageSize = 10;
      final resp = await ApiService.adminSearchUsers(
        query: _recommendSearchKeyword,
        page: page,
        pageSize: pageSize,
      );
      final body = resp['body'] as Map<String, dynamic>?;
      final users =
          (body?['users'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      // 只展示普通用户
      _recommendUserList = users
          .where((u) => (u['role'] ?? '').toString() == 'USER')
          .toList();
      _recommendTotal = (body?['total'] as num?)?.toInt() ?? 0;
      _recommendPage = (body?['page'] as num?)?.toInt() ?? page;
    } finally {
      if (mounted) setState(() => _recommendLoading = false);
    }
  }

  Future<void> _banUser(String userId) async {
    if (userId.isEmpty) return;
    final resp = await ApiService.adminBanUser(userId);
    final msg = resp['body']?['message']?.toString() ?? '操作已提交';
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    await _loadUsers();
  }

  Future<void> _unbanUser(String userId) async {
    if (userId.isEmpty) return;
    final resp = await ApiService.adminUnbanUser(userId);
    final msg = resp['body']?['message']?.toString() ?? '操作已提交';
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    await _loadUsers();
  }

  Future<void> _banUserAndRefresh(String userId) async {
    if (userId.isEmpty) return;
    final resp = await ApiService.adminBanUser(userId);
    final msg = resp['body']?['message']?.toString() ?? '操作已提交';
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    await _loadAuditUsers();
  }

  Future<void> _unbanUserAndRefresh(String userId) async {
    if (userId.isEmpty) return;
    final resp = await ApiService.adminUnbanUser(userId);
    final msg = resp['body']?['message']?.toString() ?? '操作已提交';
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    await _loadAuditUsers();
  }

  Future<void> _muteUser(String userId) async {
    if (userId.isEmpty) return;
    await _showMuteDialog(userId);
  }

  Future<void> _approveUser(String userId) async {
    if (userId.isEmpty) return;
    final resp = await ApiService.adminApproveUser(userId);
    final msg = resp['body']?['message']?.toString() ?? '审核通过';
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    // 根据当前界面刷新数据
    if (_selectedSection == _AdminSection.users) {
      await _loadUsers();
    } else if (_selectedSection == _AdminSection.userReports) {
      await _loadReports();
      await _loadAuditUsers();
    }
  }

  Future<void> _showRejectUserDialog(String userId) async {
    String action = 'BAN';
    final reasonCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('处理举报'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('选择处理方式：'),
                  const SizedBox(height: 12),
                  RadioListTile<String>(
                    title: const Text('封禁用户'),
                    value: 'BAN',
                    groupValue: action,
                    onChanged: (v) => setState(() => action = v!),
                  ),
                  RadioListTile<String>(
                    title: const Text('禁言用户（7天）'),
                    value: 'MUTE',
                    groupValue: action,
                    onChanged: (v) => setState(() => action = v!),
                  ),
                  RadioListTile<String>(
                    title: const Text('恢复正常'),
                    value: 'NORMAL',
                    groupValue: action,
                    onChanged: (v) => setState(() => action = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonCtrl,
                    decoration: const InputDecoration(
                      labelText: '处理说明（可选）',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('确定'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      final resp = await ApiService.adminRejectUser(
        userId,
        action: action,
        reason: reasonCtrl.text,
      );
      final msg = resp['body']?['message']?.toString() ?? '处理完成';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      // 根据当前界面刷新数据
      if (_selectedSection == _AdminSection.users) {
        await _loadUsers();
      } else if (_selectedSection == _AdminSection.userReports) {
        await _loadReports();
        await _loadAuditUsers();
      }
    }
  }

  String _formatUserStatus(String? status) {
    switch ((status ?? 'NORMAL').toUpperCase()) {
      case 'BANNED':
        return '封禁中';
      case 'MUTED':
        return '禁言中';
      default:
        return '正常';
    }
  }

  Widget _buildStatusChip(String? rawStatus) {
    final status = (rawStatus ?? 'NORMAL').toUpperCase();
    Color bg;
    Color fg = Colors.white;
    String label;
    switch (status) {
      case 'AUDIT':
        bg = Colors.blue;
        label = '待审核';
        break;
      case 'BANNED':
        bg = Colors.redAccent;
        label = '封禁中';
        break;
      case 'MUTE':
      case 'SILENT': // 兼容旧数据
        bg = Colors.orange;
        label = '禁言中';
        break;
      default:
        bg = Colors.green;
        label = '正常';
        break;
    }
    return Chip(
      label: Text(label),
      backgroundColor: bg,
      labelStyle: TextStyle(color: fg, fontSize: 12),
    );
  }

  Widget _buildPostStatusChip(String? rawStatus) {
    if (rawStatus == null || rawStatus.isEmpty) {
      return const Text('-', style: TextStyle(color: Colors.grey));
    }

    final status = rawStatus.toUpperCase();
    Color bg;
    Color fg = Colors.white;
    String label;

    switch (status) {
      case 'NORMAL':
        bg = Colors.green;
        label = '正常';
        break;
      case 'AUDIT':
        bg = Colors.orange;
        label = '审核中';
        break;
      case 'DRAFT':
        bg = Colors.blue;
        label = '打回草稿';
        break;
      case 'REMOVED':
        bg = Colors.red;
        label = '下架';
        break;
      default:
        bg = Colors.grey;
        label = rawStatus;
        break;
    }

    return Chip(
      label: Text(label),
      backgroundColor: bg,
      labelStyle: TextStyle(color: fg, fontSize: 12),
    );
  }

  // 从举报记录中获取被举报用户的状态
  Widget _buildUserStatusFromReport(Map<String, dynamic> report) {
    final reportedUser = report['reportedUser'] as Map<String, dynamic>?;
    if (reportedUser == null) {
      return const Text('-', style: TextStyle(color: Colors.grey));
    }

    // 注意：后端需要在举报记录中包含被举报用户的状态信息
    // 如果后端没有返回，这里会显示为 '-'
    final status = reportedUser['status']?.toString();
    if (status == null || status.isEmpty) {
      return const Text('未知', style: TextStyle(color: Colors.grey));
    }

    return _buildStatusChip(status);
  }

  // 从举报记录中构建用户操作按钮
  Widget _buildUserActionsFromReport(Map<String, dynamic> report) {
    final reportedUser = report['reportedUser'] as Map<String, dynamic>?;
    if (reportedUser == null) {
      return const Text('-', style: TextStyle(color: Colors.grey));
    }

    final userId = reportedUser['id']?.toString();
    final role = (reportedUser['role'] ?? 'USER').toString().toUpperCase();

    // 管理员不能被操作
    if (role == 'ADMIN' || role == 'SUPER_ADMIN') {
      return const Text(
        '管理员',
        style: TextStyle(fontSize: 12, color: Colors.grey),
      );
    }

    if (userId == null || userId.isEmpty) {
      return const Text('-', style: TextStyle(color: Colors.grey));
    }

    // 显示举报处理操作按钮
    return OutlinedButton(
      onPressed: () => _showReportDialog(reportId: report['id'].toString()),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      child: const Text('处理举报', style: TextStyle(fontSize: 12)),
    );
  }

  Widget _buildUserActions(Map<String, dynamic> u) {
    final role = (u['role'] ?? '').toString();
    final status = (u['status'] ?? 'NORMAL').toString();
    final id = (u['id'] ?? '').toString();

    return UserModerationActions(
      userId: id,
      status: status,
      role: role,
      onBan: () => _banUser(id),
      onUnban: () => _unbanUser(id),
      onMute: () => _showMuteDialog(id),
      onApprove: () => _approveUser(id),
      onReject: () => _showRejectUserDialog(id),
    );
  }

  Widget _buildUserActionsForAudit(Map<String, dynamic> u) {
    final role = (u['role'] ?? '').toString();
    final status = (u['status'] ?? 'NORMAL').toString();
    final id = (u['id'] ?? '').toString();

    return UserModerationActions(
      userId: id,
      status: status,
      role: role,
      onBan: () => _banUserAndRefresh(id),
      onUnban: () => _unbanUserAndRefresh(id),
      onMute: () => _muteUserForAudit(id),
      onApprove: () => _approveUser(id),
      onReject: () => _showRejectUserDialog(id),
    );
  }

  Future<void> _showMuteDialog(String userId) async {
    final durationCtrl = TextEditingController(text: '24');
    String unit = 'HOURS'; // HOURS / DAYS / MONTHS / YEARS
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('设置禁言时长'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: durationCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '时长数值',
                        hintText: '例如 24',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: unit,
                    items: const [
                      DropdownMenuItem(value: 'HOURS', child: Text('小时')),
                      DropdownMenuItem(value: 'DAYS', child: Text('天')),
                      DropdownMenuItem(value: 'MONTHS', child: Text('月')),
                      DropdownMenuItem(value: 'YEARS', child: Text('年')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        unit = v;
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );

    if (result != true) return;
    final duration = int.tryParse(durationCtrl.text.trim()) ?? 0;
    if (duration <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入正确的禁言时长')));
      return;
    }
    await _muteUserWithDuration(userId, duration, unit);
  }

  Future<void> _muteUserWithDuration(
    String userId,
    int duration,
    String unit,
  ) async {
    final resp = await ApiService.adminMuteUser(
      userId,
      duration: duration,
      unit: unit,
    );
    final msg = resp['body']?['message']?.toString() ?? '操作已提交';
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

    // 立即更新本地状态
    if (resp['statusCode'] == 200) {
      setState(() {
        final index = _auditUserList.indexWhere(
          (u) => u['id']?.toString() == userId,
        );
        if (index != -1) {
          _auditUserList[index]['status'] = 'MUTE';
        }
      });
    }

    await _loadAuditUsers();
  }

  Future<void> _muteUserForAudit(String userId) async {
    if (userId.isEmpty) return;
    await _showMuteDialogForAudit(userId);
  }

  Future<void> _showMuteDialogForAudit(String userId) async {
    final durationCtrl = TextEditingController(text: '24');
    String unit = 'HOURS';
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('设置禁言时长'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: durationCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '时长数值',
                        hintText: '例如 24',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: unit,
                    items: const [
                      DropdownMenuItem(value: 'HOURS', child: Text('小时')),
                      DropdownMenuItem(value: 'DAYS', child: Text('天')),
                      DropdownMenuItem(value: 'MONTHS', child: Text('月')),
                      DropdownMenuItem(value: 'YEARS', child: Text('年')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        unit = v;
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );

    if (result != true) return;
    final duration = int.tryParse(durationCtrl.text.trim()) ?? 0;
    if (duration <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入正确的禁言时长')));
      return;
    }
    await _muteUserWithDuration(userId, duration, unit);
  }

  Widget _buildRecommendAdminSection() {
    return _AdminSectionScaffold(
      title: '管理员推荐',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SearchBar(
            hintText: '输入普通用户昵称或邮箱（可选）',
            buttonLabel: '搜索',
            onChanged: (v) => _recommendSearchKeyword = v,
            onPressed: () => _loadRecommendUsers(page: 0),
          ),
          const SizedBox(height: 16),
          if (_recommendLoading)
            const Center(child: CircularProgressIndicator())
          else
            _buildPlaceholderTable(
              headers: const ['用户名', '邮箱', '角色', '状态', '操作'],
              rows: _recommendUserList
                  .map(
                    (u) => [
                      Text(u['name']?.toString() ?? ''),
                      Text(u['email']?.toString() ?? ''),
                      Text(u['role']?.toString() ?? ''),
                      _buildStatusChip(u['status']?.toString()),
                      ElevatedButton(
                        onPressed: () =>
                            _showRecommendDialog((u['id'] ?? '').toString()),
                        child: const Text('推荐为管理员'),
                      ),
                    ],
                  )
                  .toList(),
            ),
          const SizedBox(height: 12),
          _buildPagination(
            currentPage: _recommendPage,
            totalItems: _recommendTotal,
            onPageChanged: (p) => _loadRecommendUsers(page: p),
          ),
        ],
      ),
    );
  }

  Future<void> _showRecommendDialog(String userId) async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('推荐用户为管理员'),
          content: TextField(
            controller: reasonCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: '推荐理由',
              hintText: '请输入推荐理由',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('提交'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;
    final reason = reasonCtrl.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('推荐理由不能为空')));
      return;
    }
    final resp = await ApiService.adminCreateApplication(
      candidateUserId: userId,
      reason: reason,
    );
    final msg = resp['body']?['message']?.toString() ?? '推荐已提交，等待超级管理员审核';
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // 标题截断（最多20个字符，超出加省略号）
  String _truncateTitle(String title) {
    const maxLen = 20;
    if (title.runes.length <= maxLen) return title;
    return String.fromCharCodes(title.runes.take(maxLen)) + '...';
  }

  // 格式化帖子时间为 yyyy-MM-dd HH:mm
  // 统一时间格式化：yyyy-MM-dd HH:mm
  String _formatPostTime(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      String two(int v) => v.toString().padLeft(2, '0');
      return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
          '${two(dt.hour)}:${two(dt.minute)}';
    } catch (_) {
      return raw;
    }
  }

  Widget _buildPagination({
    required int currentPage,
    required int totalItems,
    int pageSize = 10,
    required ValueChanged<int> onPageChanged,
  }) {
    if (totalItems <= 0) return const SizedBox.shrink();
    final totalPages = (totalItems + pageSize - 1) ~/ pageSize;
    if (totalPages <= 1) return const SizedBox.shrink();
    final displayPage = currentPage + 1;
    return Align(
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: currentPage <= 0
                ? null
                : () => onPageChanged(currentPage - 1),
            icon: const Icon(Icons.chevron_left),
          ),
          Text('第 $displayPage / $totalPages 页'),
          IconButton(
            onPressed: currentPage >= totalPages - 1
                ? null
                : () => onPageChanged(currentPage + 1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  void showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _ReportFilterBar extends StatelessWidget {
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onSearch;

  const _ReportFilterBar({this.onSearchChanged, this.onSearch});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SearchBar(
            hintText: '搜索举报（举报人 / 被举报人 / 理由 / 对象）',
            buttonLabel: '搜索',
            onChanged: onSearchChanged,
            onPressed: onSearch,
          ),
        ),
      ],
    );
  }
}

class _AdminSectionScaffold extends StatelessWidget {
  final String title;
  final Widget child;

  const _AdminSectionScaffold({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey(title),
      color: const Color(0xFFF5F7FA),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: constraints.maxWidth,
                minHeight: constraints.maxHeight,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  child,
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final String hintText;
  final String buttonLabel;
  final VoidCallback? onPressed;
  final ValueChanged<String>? onChanged;

  const _SearchBar({
    required this.hintText,
    required this.buttonLabel,
    this.onPressed,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            decoration: InputDecoration(
              hintText: hintText,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(onPressed: onPressed ?? () {}, child: Text(buttonLabel)),
      ],
    );
  }
}

class _PaginationPlaceholder extends StatelessWidget {
  const _PaginationPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(onPressed: () {}, icon: const Icon(Icons.chevron_left)),
        const Text('第 1 / 5 页'),
        IconButton(onPressed: () {}, icon: const Icon(Icons.chevron_right)),
      ],
    );
  }
}

class _AdminMenuItem {
  final _AdminSection section;
  final String label;
  final IconData icon;

  const _AdminMenuItem({
    required this.section,
    required this.label,
    required this.icon,
  });
}

class _AdminMenuTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _AdminMenuTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFE8F1FF) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? Colors.blueAccent : Colors.grey[700],
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected ? Colors.blueAccent : Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UserModerationActions extends StatelessWidget {
  final String userId;
  final String status;
  final String role;
  final VoidCallback onBan;
  final VoidCallback onUnban;
  final VoidCallback onMute;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const UserModerationActions({
    super.key,
    required this.userId,
    required this.status,
    required this.role,
    required this.onBan,
    required this.onUnban,
    required this.onMute,
    this.onApprove,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final roleUpper = role.toUpperCase();
    final statusUpper = status.toUpperCase();

    if (roleUpper == 'ADMIN' || roleUpper == 'SUPER_ADMIN') {
      return const Text(
        '管理员帐号，无法封禁/禁言',
        style: TextStyle(fontSize: 12, color: Colors.grey),
      );
    }

    final isAudit = statusUpper == 'AUDIT';
    final isBanned = statusUpper == 'BANNED';
    final isSilent = statusUpper == 'MUTE' || statusUpper == 'SILENT';

    if (isAudit && onApprove != null && onReject != null) {
      return Row(
        children: [
          OutlinedButton(
            onPressed: onApprove,
            style: OutlinedButton.styleFrom(foregroundColor: Colors.green),
            child: const Text('忽略举报'),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onReject,
            style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('处理举报'),
          ),
        ],
      );
    }

    return Row(
      children: [
        OutlinedButton(
          onPressed: isBanned ? null : onBan,
          style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
          child: const Text('封禁'),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: (!isBanned && !isSilent) ? null : onUnban,
          style: OutlinedButton.styleFrom(foregroundColor: Colors.green),
          child: const Text('解封'),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: isBanned ? null : onMute,
          style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
          child: Text(isSilent ? '重新禁言' : '禁言'),
        ),
      ],
    );
  }
}
