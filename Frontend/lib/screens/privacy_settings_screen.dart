// lib/screens/privacy_settings_screen.dart
/// 隐私设置页面
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/local_storage.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({Key? key}) : super(key: key);

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool _hideFollowing = false;
  bool _hideFollowers = false;
  bool _publicFavorites = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPrivacySettings();
  }

  Future<void> _loadPrivacySettings() async {
    setState(() => _loading = true);
    try {
      // 优先从后端获取隐私设置
      final resp = await ApiService.getPrivacySettings();
      if (resp['statusCode'] == 200) {
        final body = resp['body'] as Map<String, dynamic>? ?? {};
        final hideFollowing =
            (body['hideFollowing'] as bool?) ?? (LocalStorage.instance.read('privacy_hide_following') == 'true');
        final hideFollowers =
            (body['hideFollowers'] as bool?) ?? (LocalStorage.instance.read('privacy_hide_followers') == 'true');
        final publicFavorites =
            (body['publicFavorites'] as bool?) ?? (LocalStorage.instance.read('privacy_public_favorites') != 'false');

        setState(() {
          _hideFollowing = hideFollowing;
          _hideFollowers = hideFollowers;
          _publicFavorites = publicFavorites;
          _loading = false;
        });
        return;
      }

      // 后端失败时回退到本地缓存
      final hideFollowingLocal = LocalStorage.instance.read('privacy_hide_following') == 'true';
      final hideFollowersLocal = LocalStorage.instance.read('privacy_hide_followers') == 'true';
      final publicFavoritesLocal =
          LocalStorage.instance.read('privacy_public_favorites') != 'false';

      setState(() {
        _hideFollowing = hideFollowingLocal;
        _hideFollowers = hideFollowersLocal;
        _publicFavorites = publicFavoritesLocal;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _savePrivacySettings() async {
    try {
      // 先保存到后端
      final resp = await ApiService.updatePrivacySettings(
        hideFollowing: _hideFollowing,
        hideFollowers: _hideFollowers,
        publicFavorites: _publicFavorites,
      );
      if (resp['statusCode'] != 200) {
        final message = (resp['body'] as Map<String, dynamic>?)?['message'] ?? '未知错误';
        throw Exception(message);
      }

      // 再更新本地缓存，作为兜底
      await LocalStorage.instance.write('privacy_hide_following', _hideFollowing.toString());
      await LocalStorage.instance.write('privacy_hide_followers', _hideFollowers.toString());
      await LocalStorage.instance.write('privacy_public_favorites', _publicFavorites.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设置已保存')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: scheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '隐私设置',
          style: TextStyle(
            color: scheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 关注与粉丝列表
                  _buildSection(
                    title: '关注与粉丝列表',
                    children: [
                      _buildSwitchTile(
                        title: '隐藏关注列表',
                        subtitle: '开启后，其他人将无法查看你的关注列表',
                        value: _hideFollowing,
                        onChanged: (value) {
                          setState(() {
                            _hideFollowing = value;
                          });
                          _savePrivacySettings();
                        },
                      ),
                      const Divider(height: 1),
                      _buildSwitchTile(
                        title: '隐藏粉丝列表',
                        subtitle: '开启后，其他人将无法查看你的粉丝列表',
                        value: _hideFollowers,
                        onChanged: (value) {
                          setState(() {
                            _hideFollowers = value;
                          });
                          _savePrivacySettings();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 我的收藏
                  _buildSection(
                    title: '我的收藏',
                    children: [
                      _buildSwitchTile(
                        title: '公开我的收藏',
                        subtitle: '开启后，其他人可以在你的主页查看你的收藏内容',
                        value: _publicFavorites,
                        onChanged: (value) {
                          setState(() {
                            _publicFavorites = value;
                          });
                          _savePrivacySettings();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface.withOpacity(0.7),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: scheme.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      tileColor: scheme.surfaceVariant,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: scheme.onSurface,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: scheme.onSurface.withOpacity(0.7),
          ),
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: scheme.primary,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }
}







