import 'package:flutter/material.dart';
import '../utils/dialog_utils.dart';
import '../models/dialog_option.dart';

/// 对话框工具类测试页面
class DialogTestPage extends StatefulWidget {
  const DialogTestPage({super.key});

  @override
  State<DialogTestPage> createState() => _DialogTestPageState();
}

class _DialogTestPageState extends State<DialogTestPage> {
  String _lastResult = '暂无操作';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('对话框工具类测试'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 结果显示区域
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.grey[50]!,
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '操作结果：',
                    style: TextStyle(
                      fontSize: 14.0,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    _lastResult,
                    style: const TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24.0),

            // 1. 确认对话框测试
            _buildSectionTitle('1. 确认对话框'),
            _buildTestButton(
              '普通确认对话框',
              onPressed: () => _testConfirmDialog(),
            ),
            _buildTestButton(
              '危险操作对话框（删除）',
              onPressed: () => _testDangerConfirmDialog(),
              isDangerous: true,
            ),
            _buildTestButton(
              '取消关注对话框',
              onPressed: () => _testUnfollowDialog(),
            ),
            _buildTestButton(
              '清空聊天记录对话框',
              onPressed: () => _testClearDialog(),
              isDangerous: true,
            ),
            const SizedBox(height: 16.0),

            // 2. 输入对话框测试
            _buildSectionTitle('2. 输入对话框'),
            _buildTestButton(
              '单行输入对话框',
              onPressed: () => _testInputDialog(),
            ),
            _buildTestButton(
              '多行输入对话框',
              onPressed: () => _testMultiLineInputDialog(),
            ),
            const SizedBox(height: 16.0),

            // 3. 选择对话框测试
            _buildSectionTitle('3. 选择对话框'),
            _buildTestButton(
              '选项选择对话框',
              onPressed: () => _testSelectionDialog(),
            ),
            _buildTestButton(
              '带图标的选项对话框',
              onPressed: () => _testIconSelectionDialog(),
            ),
            const SizedBox(height: 16.0),

            // 4. 加载指示器测试
            _buildSectionTitle('4. 加载指示器'),
            _buildTestButton(
              '模态加载指示器（阻塞）',
              onPressed: () => _testModalLoading(),
            ),
            const SizedBox(height: 16.0),

            // 5. 快捷方法测试
            _buildSectionTitle('5. 快捷方法'),
            _buildTestButton(
              '删除确认快捷方法',
              onPressed: () => _testDeleteShortcut(),
              isDangerous: true,
            ),
            _buildTestButton(
              '取消关注快捷方法',
              onPressed: () => _testUnfollowShortcut(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16.0,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildTestButton(
    String text, {
    required VoidCallback onPressed,
    bool isDangerous = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDangerous ? Colors.red : Colors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
        child: Text(text),
      ),
    );
  }

  // ========== 测试方法 ==========

  void _updateResult(String result) {
    setState(() {
      _lastResult = result;
    });
  }

  // 1. 确认对话框测试
  Future<void> _testConfirmDialog() async {
    final result = await DialogUtils.showConfirmDialog(
      context: context,
      title: '确认操作',
      content: '您确定要执行此操作吗？',
    );
    _updateResult('确认对话框结果: ${result == true ? "确认" : "取消"}');
  }

  Future<void> _testDangerConfirmDialog() async {
    final result = await DialogUtils.showConfirmDialog(
      context: context,
      title: '确认删除笔记？',
      content: '删除后将无法恢复，请谨慎操作。',
      isDangerous: true,
      confirmText: '删除',
      dangerWarning: '这是一个危险操作，请确认您要执行此操作。',
    );
    _updateResult('危险确认对话框结果: ${result == true ? "确认删除" : "取消"}');
  }

  Future<void> _testUnfollowDialog() async {
    final result = await DialogUtils.showConfirmDialog(
      context: context,
      title: '不再关注张三？',
      content: '取消关注后，您将不再看到该用户的动态更新。',
      confirmText: '不再关注',
    );
    _updateResult('取消关注结果: ${result == true ? "确认取消关注" : "取消"}');
  }

  Future<void> _testClearDialog() async {
    final result = await DialogUtils.showConfirmDialog(
      context: context,
      title: '清空聊天记录',
      content: '确定要清空与 李四 的聊天记录吗？此操作不可恢复。',
      isDangerous: true,
      confirmText: '清空',
      dangerWarning: '清空后数据将无法恢复，请确认操作。',
    );
    _updateResult('清空聊天记录结果: ${result == true ? "确认清空" : "取消"}');
  }

  // 2. 输入对话框测试
  Future<void> _testInputDialog() async {
    final result = await DialogUtils.showInputDialog(
      context: context,
      title: '搜索聊天记录',
      hintText: '输入关键词搜索...',
      confirmText: '搜索',
    );
    _updateResult('输入对话框结果: ${result ?? "取消"}');
  }

  Future<void> _testMultiLineInputDialog() async {
    final result = await DialogUtils.showInputDialog(
      context: context,
      title: '处理举报',
      hintText: '请输入处理理由...',
      maxLines: 4,
      confirmText: '提交',
    );
    _updateResult('多行输入对话框结果: ${result ?? "取消"}');
  }

  // 3. 选择对话框测试
  Future<void> _testSelectionDialog() async {
    final options = [
      DialogOption.text(value: 'delete', label: '删除帖子'),
      DialogOption.text(value: 'no_violation', label: '无违规'),
      DialogOption.text(value: 'ban_user', label: '封禁用户', isDangerous: true),
    ];

    final result = await DialogUtils.showSelectionDialog<String>(
      context: context,
      title: '处理举报',
      options: options,
      content: '请选择处理方式：',
    );
    _updateResult('选择对话框结果: ${result ?? "取消"}');
  }

  Future<void> _testIconSelectionDialog() async {
    final options = [
      DialogOption.withIcon(
        value: 'image',
        label: '图片',
        icon: Icons.image,
      ),
      DialogOption.withIcon(
        value: 'video',
        label: '视频',
        icon: Icons.videocam,
      ),
      DialogOption.withIcon(
        value: 'file',
        label: '文件',
        icon: Icons.insert_drive_file,
      ),
      DialogOption.withIcon(
        value: 'voice',
        label: '语音',
        icon: Icons.mic,
      ),
    ];

    final result = await DialogUtils.showSelectionDialog<String>(
      context: context,
      title: '选择媒体类型',
      options: options,
    );
    _updateResult('图标选择对话框结果: ${result ?? "取消"}');
  }

Future<void> _testModalLoading() async {
  // 定义局部变量用于状态管理
  double progress = 0.0;
  // 用于在异步循环中更新对话框内部 UI 的 StateSetter
  late StateSetter dialogSetState; 
  
  // 1. 弹出对话框，并使用 StatefulBuilder 获取状态更新能力
  final dialogFuture = showDialog(
    context: context,
    barrierDismissible: false, // 模态，不可点击外部关闭
    barrierColor: Colors.black.withOpacity(0.4),
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, StateSetter setState) {
          // 关键步骤：将 StateSetter 赋值给外部变量，以便在异步循环中调用
          dialogSetState = setState; 
          
          // 构建加载指示器 UI (直接使用我们在 DialogUtils 中定义的结构，但替换为局部状态)
          return AlertDialog(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor, // 使用主题背景色
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            insetPadding: const EdgeInsets.all(40.0),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 混合指示器 Stack
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 50.0,
                      height: 50.0,
                      child: CircularProgressIndicator(
                        // progress == 0.0 时显示不确定加载，否则显示进度
                        value: progress == 0.0 ? null : progress, 
                        color: Colors.blue, // 假设 AppColors.primary 是蓝色
                        strokeWidth: 4.0,
                      ),
                    ),
                    if (progress > 0) // 进度大于 0 时才显示百分比
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 14.0,
                          fontWeight: FontWeight.w600,
                          color: Colors.black, // 假设 AppColors.textPrimary 是黑色
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16.0),
                Text(
                  progress < 1.0 ? '文件上传中...' : '上传完成！',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );

  // 2. 模拟异步任务和实时进度更新
  for (int i = 0; i <= 100; i++) {
    await Future.delayed(const Duration(milliseconds: 50));
    
    // 确保 StateSetter 已被赋值且对话框仍在屏幕上
    if (Navigator.of(context).canPop()) { 
      // 关键：调用 StateSetter 来更新对话框内部的 UI
      dialogSetState(() { 
          progress = i / 100;
      });
    }
  }

  // 3. 任务完成后关闭对话框
  if (Navigator.of(context).canPop()) {
    Navigator.pop(context);
  }
  
  _updateResult('模态加载指示器测试完成: 进度达到 100%');
}

  // 5. 快捷方法测试
  Future<void> _testDeleteShortcut() async {
    final result = await DialogUtils.showDeleteConfirmDialog(
      context: context,
      itemName: '笔记',
      additionalWarning: '该笔记包含重要信息，删除前请备份。',
    );
    _updateResult('删除快捷方法结果: ${result == true ? "确认删除" : "取消"}');
  }

  Future<void> _testUnfollowShortcut() async {
    final result = await DialogUtils.showUnfollowConfirmDialog(
      context: context,
      userName: '王五',
    );
    _updateResult('取消关注快捷方法结果: ${result == true ? "确认取消关注" : "取消"}');
  }
}