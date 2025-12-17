import 'dart:convert';
import 'local_storage.dart';

/// 页面状态恢复服务
/// 用于在页面刷新后恢复用户的浏览状态和表单数据
class PageStateService {
  PageStateService._();
  static final instance = PageStateService._();

  final _storage = LocalStorage.instance;
  static const _stateKey = 'page_state';
  static const _formDataKey = 'form_data';

  /// 保存页面状态（路由和滚动位置）
  Future<void> savePageState({
    required String route,
    double? scrollOffset,
    Map<String, dynamic>? extraData,
  }) async {
    final state = {
      'route': route,
      'scrollOffset': scrollOffset ?? 0.0,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      if (extraData != null) 'extraData': extraData,
    };
    await _storage.write(_stateKey, jsonEncode(state));
  }

  /// 恢复页面状态
  Map<String, dynamic>? restorePageState() {
    final stateStr = _storage.read(_stateKey);
    if (stateStr == null) return null;

    try {
      final state = jsonDecode(stateStr) as Map<String, dynamic>;
      final timestamp = state['timestamp'] as int?;

      // 只恢复5分钟内的状态
      if (timestamp != null) {
        final age = DateTime.now().millisecondsSinceEpoch - timestamp;
        if (age > 5 * 60 * 1000) {
          clearPageState();
          return null;
        }
      }

      return state;
    } catch (e) {
      return null;
    }
  }

  /// 清除页面状态
  Future<void> clearPageState() async {
    await _storage.delete(_stateKey);
  }

  /// 保存表单数据
  Future<void> saveFormData(String formId, Map<String, dynamic> data) async {
    final allForms = _getAllFormData();
    allForms[formId] = {
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    await _storage.write(_formDataKey, jsonEncode(allForms));
  }

  /// 恢复表单数据
  Map<String, dynamic>? restoreFormData(String formId) {
    final allForms = _getAllFormData();
    final formState = allForms[formId];

    if (formState == null) return null;

    try {
      final timestamp = formState['timestamp'] as int?;

      // 只恢复30分钟内的表单数据
      if (timestamp != null) {
        final age = DateTime.now().millisecondsSinceEpoch - timestamp;
        if (age > 30 * 60 * 1000) {
          clearFormData(formId);
          return null;
        }
      }

      return formState['data'] as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  /// 清除特定表单数据
  Future<void> clearFormData(String formId) async {
    final allForms = _getAllFormData();
    allForms.remove(formId);
    await _storage.write(_formDataKey, jsonEncode(allForms));
  }

  /// 清除所有表单数据
  Future<void> clearAllFormData() async {
    await _storage.delete(_formDataKey);
  }

  Map<String, dynamic> _getAllFormData() {
    final dataStr = _storage.read(_formDataKey);
    if (dataStr == null) return {};

    try {
      return jsonDecode(dataStr) as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }
}
