import 'package:flutter/material.dart';
import '../services/api_service.dart';

enum _AdminSection {
  users,
  posts,
  reports,
  notices,
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
  List<Map<String, dynamic>> _userList = [];
  bool _userLoading = false;

  // ==== 帖子管理 ====
  String _postSearchKeyword = '';
  String _postAuthorKeyword = '';
  List<Map<String, dynamic>> _postList = [];
  bool _postLoading = false;

  // ==== 举报管理 ====
  String _reportSearchKeyword = '';
  String _reportStatus = '';
  String _reportTargetType = '';
  List<Map<String, dynamic>> _reportList = [];
  bool _reportLoading = false;

  // ==== 公告管理 ====
  String _noticeSearchKeyword = '';
  List<Map<String, dynamic>> _noticeList = [];
  bool _noticeLoading = false;
  final TextEditingController _noticeTitleCtrl = TextEditingController();
  final TextEditingController _noticeContentCtrl = TextEditingController();

  // ==== 管理员申请审核 ====
  List<Map<String, dynamic>> _applicationList = [];
  bool _applicationLoading = false;

  // ==== 权限管理 ====
  String _adminSearchKeyword = '';
  String _userSearchKeywordForGrant = '';
  List<Map<String, dynamic>> _adminList = [];
  List<Map<String, dynamic>> _normalUserList = [];
  bool _permissionLoading = false;

  bool get _isSuperAdmin => widget.role.toUpperCase() == 'SUPER_ADMIN';

  static const List<_AdminMenuItem> _basicMenuItems = [
    _AdminMenuItem(
      section: _AdminSection.users,
      label: '用户管理',
      icon: Icons.people_outline,
    ),
    _AdminMenuItem(
      section: _AdminSection.posts,
      label: '帖子管理',
      icon: Icons.article_outlined,
    ),
    _AdminMenuItem(
      section: _AdminSection.reports,
      label: '举报管理',
      icon: Icons.report_gmailerrorred_outlined,
    ),
    _AdminMenuItem(
      section: _AdminSection.notices,
      label: '公告管理',
      icon: Icons.campaign_outlined,
    ),
  ];

  static const List<_AdminMenuItem> _superMenuItems = [
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

  List<_AdminMenuItem> get _menuItems =>
      _isSuperAdmin ? [..._basicMenuItems, ..._superMenuItems] : _basicMenuItems;

  @override
  void initState() {
    super.initState();
    _selectedSection = _menuItems.first.section;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadUsers(),
      _loadPosts(),
      _loadNotices(),
      _loadReports(),
      if (_isSuperAdmin) _loadApplications(),
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
              border: Border(
                bottom: BorderSide(color: Color(0xFFEAEAEA)),
              ),
            ),
            child: const Text(
              '管理员后台',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                ..._basicMenuItems.map(
                  (item) => _AdminMenuTile(
                    label: item.label,
                    icon: item.icon,
                    selected: _selectedSection == item.section,
                    onTap: () {
                      setState(() {
                        _selectedSection = item.section;
                      });
                    },
                  ),
                ),
                if (_isSuperAdmin)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    child: Text(
                      'Super Admin',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ),
                if (_isSuperAdmin)
                  ..._superMenuItems.map(
                    (item) => _AdminMenuTile(
                      label: item.label,
                      icon: item.icon,
                      selected: _selectedSection == item.section,
                      onTap: () {
                        setState(() {
                          _selectedSection = item.section;
                        });
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
      case _AdminSection.notices:
        return _buildNoticeManagementSection();
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
          _SearchBar(
            hintText: '输入用户名或邮箱（留空则查询全部）',
            buttonLabel: '搜索',
            onPressed: () => _loadUsers(keyword: _userSearchKeyword),
            onChanged: (v) => _userSearchKeyword = v,
          ),
          const SizedBox(height: 16),
          if (_userLoading)
            const Center(child: CircularProgressIndicator())
          else
            _buildPlaceholderTable(
              headers: const ['用户名', '邮箱', '角色', '状态', '操作'],
              rows: _userList
                  .map((u) => [
                        Text(u['name']?.toString() ?? ''),
                        Text(u['email']?.toString() ?? ''),
                        Text(u['role']?.toString() ?? ''),
                        _buildStatusChip(u['status']?.toString()),
                        _buildUserActions(u),
                      ])
                  .toList(),
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
            onPressed: () => _loadPosts(),
          ),
          const SizedBox(height: 12),
          _SearchBar(
            hintText: '按作者昵称或邮箱筛选（可选）',
            buttonLabel: '筛选',
            onChanged: (v) => _postAuthorKeyword = v,
            onPressed: () => _loadPosts(),
          ),
          const SizedBox(height: 16),
          if (_postLoading)
            const Center(child: CircularProgressIndicator())
          else
            _buildPlaceholderTable(
              headers: const ['ID', '标题', '作者信息', '发布时间', '操作'],
              rows: _postList
                  .map((p) => [
                        Text(p['id']?.toString() ?? ''),
                        Text(p['title']?.toString() ?? ''),
                        Text(
                          'ID: ${p['authorId'] ?? ''} | 昵称: ${p['authorName'] ?? ''} | 邮箱: ${p['authorEmail'] ?? ''}',
                        ),
                        Text(p['createdAt']?.toString() ?? ''),
                        ElevatedButton(
                          onPressed: () async {
                            final id = (p['id'] ?? '').toString();
                            if (id.isEmpty) return;
                            final resp =
                                await ApiService.adminHidePost(id);
                            final msg = resp['body']?['message']
                                    ?.toString() ??
                                '已发送下架请求';
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(msg)),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                          ),
                          child: const Text('下架'),
                        ),
                      ])
                  .toList(),
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
            onSearch: () => _loadReports(),
          ),
          const SizedBox(height: 16),
          if (_reportLoading)
            const Center(child: CircularProgressIndicator())
          else
            _buildPlaceholderTable(
              headers: const [
                '举报人(ID/昵称)',
                '对象类型',
                '被举报对象(ID/昵称)',
                '理由',
                '状态',
                '操作'
              ],
              rows: _reportList
                  .map((r) => [
                        Text(
                            'U${r['reporter']?['id'] ?? ''} / ${r['reporter']?['name'] ?? ''}'),
                        Text(r['targetType']?.toString() ?? ''),
                        Text(_formatReportedTarget(r)),
                        Text(r['reason']?.toString() ?? ''),
                        Text(r['status']?.toString() ?? ''),
                        OutlinedButton(
                          onPressed: () =>
                              _showReportDialog(reportId: r['id'].toString()),
                          child: const Text('处理'),
                        ),
                      ])
                  .toList(),
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
                  onPressed: () => _loadNotices(),
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
                  .map((n) => [
                        Text(n['title']?.toString() ?? ''),
                        Text(n['createdAt']?.toString() ?? ''),
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
                              onPressed: () => _deleteNotice(
                                  (n['id'] ?? '').toString()),
                              style: TextButton.styleFrom(
                                  foregroundColor: Colors.red),
                              child: const Text('删除'),
                            ),
                          ],
                        ),
                      ])
                  .toList(),
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
              hintText: '公告正文（支持富文本编辑器占位）',
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
                '操作'
              ],
              rows: _applicationList
                  .map((a) => [
                        Text(
                            'A${a['recommender']?['id'] ?? ''} / ${a['recommender']?['name'] ?? ''}'),
                        Text(
                            'U${a['candidate']?['id'] ?? ''} / ${a['candidate']?['name'] ?? ''}'),
                        Text(a['reason']?.toString() ?? ''),
                        Text(a['createdAt']?.toString() ?? ''),
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: () => _approveApplication(
                                  (a['id'] ?? '').toString()),
                              child: const Text('批准'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () => _rejectApplication(
                                  (a['id'] ?? '').toString()),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                              ),
                              child: const Text('拒绝'),
                            ),
                          ],
                        ),
                      ])
                  .toList(),
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
            _buildPlaceholderTable(
              headers: const ['用户名', '当前角色', '操作'],
              rows: _adminList
                  .map((u) => [
                        Text(u['name']?.toString() ?? ''),
                        Text(u['role']?.toString() ?? ''),
                        if (u['role'] == 'SUPER_ADMIN')
                          const Text('无法操作')
                        else
                          OutlinedButton(
                            onPressed: () => _revokeAdmin(
                                (u['id'] ?? '').toString()),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                            ),
                            child: const Text('收回权限'),
                          ),
                      ])
                  .toList(),
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
            _buildPlaceholderTable(
              headers: const ['用户名', '当前角色', '操作'],
              rows: _normalUserList
                  .map((u) => [
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
                      ])
                  .toList(),
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
                columns: headers.map((h) => DataColumn(label: Text(h))).toList(),
                rows: rows
                    .map(
                      (cells) => DataRow(
                        cells: cells
                            .map((cell) => DataCell(cell))
                            .toList(),
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
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('处理举报'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('请选择处理方式：'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () {
                    // TODO: 调用 ApiService.adminHandleReport(action: DELETE_POST)
                  },
                  child: const Text('删除帖子'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // TODO: 调用 ApiService.adminHandleReport(action: NO_VIOLATION)
                  },
                  child: const Text('无违规'),
                ),
                OutlinedButton(
                  onPressed: () {
                    // TODO: 调用 ApiService.adminHandleReport(action: BAN_USER)
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                  ),
                  child: const Text('封禁用户'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  // ===================== 数据加载 & 动作 =====================

  Future<void> _loadUsers({String? keyword}) async {
    setState(() => _userLoading = true);
    try {
      final resp = await ApiService.adminSearchUsers(
        query: keyword ?? _userSearchKeyword,
        page: 0,
        pageSize: 50,
      );
      final body = resp['body'] as Map<String, dynamic>?;
      _userList = (body?['users'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
    } finally {
      if (mounted) setState(() => _userLoading = false);
    }
  }

  Future<void> _loadNotices() async {
    setState(() => _noticeLoading = true);
    try {
      final resp = await ApiService.adminGetNotices(
        query: _noticeSearchKeyword,
        page: 0,
        pageSize: 50,
      );
      final body = resp['body'] as Map<String, dynamic>?;
      _noticeList = (body?['notices'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
    } finally {
      if (mounted) setState(() => _noticeLoading = false);
    }
  }

  Future<void> _loadReports() async {
    setState(() => _reportLoading = true);
    try {
      final resp = await ApiService.adminGetReports(
        query: _reportSearchKeyword,
        status: _reportStatus.isEmpty ? null : _reportStatus,
        targetType: _reportTargetType.isEmpty ? null : _reportTargetType,
        page: 0,
        pageSize: 50,
      );
      final body = resp['body'] as Map<String, dynamic>?;
      _reportList = (body?['reports'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
    } finally {
      if (mounted) setState(() => _reportLoading = false);
    }
  }

  Future<void> _loadApplications() async {
    setState(() => _applicationLoading = true);
    try {
      final resp = await ApiService.adminGetApplications(
        status: 'PENDING',
        page: 0,
        pageSize: 50,
      );
      final body = resp['body'] as Map<String, dynamic>?;
      _applicationList = (body?['applications'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
    } finally {
      if (mounted) setState(() => _applicationLoading = false);
    }
  }

  Future<void> _loadPermissionUsers() async {
    setState(() => _permissionLoading = true);
    try {
      // 管理员列表
      final adminResp = await ApiService.adminSearchUsers(
        query: _adminSearchKeyword,
        page: 0,
        pageSize: 100,
      );
      final adminBody = adminResp['body'] as Map<String, dynamic>?;
      final allUsers = (adminBody?['users'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      _adminList = allUsers
          .where((u) =>
              u['role'] == 'ADMIN' ||
              u['role'] == 'SUPER_ADMIN')
          .toList();

      // 普通用户列表
      final userResp = await ApiService.adminSearchUsers(
        query: _userSearchKeywordForGrant,
        page: 0,
        pageSize: 100,
      );
      final userBody = userResp['body'] as Map<String, dynamic>?;
      final allUsers2 = (userBody?['users'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      _normalUserList =
          allUsers2.where((u) => u['role'] == 'USER').toList();
    } finally {
      if (mounted) setState(() => _permissionLoading = false);
    }
  }

  Future<void> _createOrUpdateNotice() async {
    final title = _noticeTitleCtrl.text.trim();
    final content = _noticeContentCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('公告标题不能为空')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('公告发布成功')),
      );
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

  Future<void> _loadPosts() async {
    setState(() => _postLoading = true);
    try {
      final resp = await ApiService.adminSearchPosts(
        query: _postSearchKeyword,
        author: _postAuthorKeyword,
        page: 0,
        pageSize: 50,
      );
      final body = resp['body'] as Map<String, dynamic>?;
      _postList = (body?['posts'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
    } finally {
      if (mounted) setState(() => _postLoading = false);
    }
  }

  Future<void> _banUser(String userId) async {
    if (userId.isEmpty) return;
    final resp = await ApiService.adminBanUser(userId);
    final msg = resp['body']?['message']?.toString() ?? '操作已提交';
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
    await _loadUsers();
  }

  Future<void> _unbanUser(String userId) async {
    if (userId.isEmpty) return;
    final resp = await ApiService.adminUnbanUser(userId);
    final msg = resp['body']?['message']?.toString() ?? '操作已提交';
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
    await _loadUsers();
  }

  Future<void> _muteUser(String userId) async {
    if (userId.isEmpty) return;
    await _showMuteDialog(userId);
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
      case 'BANNED':
        bg = Colors.redAccent;
        label = '封禁中';
        break;
      case 'MUTED':
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

  Widget _buildUserActions(Map<String, dynamic> u) {
    final role = (u['role'] ?? '').toString().toUpperCase();
    final status = (u['status'] ?? 'NORMAL').toString().toUpperCase();
    final id = (u['id'] ?? '').toString();

    // 管理员/超级管理员不能被封禁或禁言
    if (role == 'ADMIN' || role == 'SUPER_ADMIN') {
      return const Text(
        '管理员帐号，无法封禁/禁言',
        style: TextStyle(fontSize: 12, color: Colors.grey),
      );
    }

    final isBanned = status == 'BANNED';
    final isMuted = status == 'MUTED';

    return Row(
      children: [
        OutlinedButton(
          onPressed: isBanned ? null : () => _banUser(id),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.redAccent,
          ),
          child: const Text('封禁'),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: (!isBanned && !isMuted) ? null : () => _unbanUser(id),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.green,
          ),
          child: const Text('解封'),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: isBanned
              ? null
              : () => _showMuteDialog(id),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.orange,
          ),
          child: Text(isMuted ? '重新禁言' : '禁言'),
        ),
      ],
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
                      DropdownMenuItem(
                        value: 'HOURS',
                        child: Text('小时'),
                      ),
                      DropdownMenuItem(
                        value: 'DAYS',
                        child: Text('天'),
                      ),
                      DropdownMenuItem(
                        value: 'MONTHS',
                        child: Text('月'),
                      ),
                      DropdownMenuItem(
                        value: 'YEARS',
                        child: Text('年'),
                      ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入正确的禁言时长')),
      );
      return;
    }
    await _muteUserWithDuration(userId, duration, unit);
  }

  Future<void> _muteUserWithDuration(
      String userId, int duration, String unit) async {
    final resp = await ApiService.adminMuteUser(
      userId,
      duration: duration,
      unit: unit,
    );
    final msg = resp['body']?['message']?.toString() ?? '操作已提交';
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
    await _loadUsers();
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

  const _AdminSectionScaffold({
    required this.title,
    required this.child,
  });

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
        ElevatedButton(
          onPressed: onPressed ?? () {},
          child: Text(buttonLabel),
        ),
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
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.chevron_left),
        ),
        const Text('第 1 / 5 页'),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.chevron_right),
        ),
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

