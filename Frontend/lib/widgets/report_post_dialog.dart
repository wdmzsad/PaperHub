import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../constants/app_colors.dart';
import '../constants/dialog_styles.dart';
import '../utils/dialog_utils.dart';

/// 举报帖子对话框
class ReportPostDialog extends StatefulWidget {
  final int postId;

  const ReportPostDialog({super.key, required this.postId});

  @override
  State<ReportPostDialog> createState() => _ReportPostDialogState();
}

class _ReportPostDialogState extends State<ReportPostDialog> {
  final TextEditingController _descriptionController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    final description = _descriptionController.text.trim();

    if (description.isEmpty) {
      setState(() {
        _errorMessage = '请输入举报理由';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.reportPost(
        postId: widget.postId,
        description: description,
      );

      if (!mounted) return;

      if (response['statusCode'] == 200) {
        Navigator.of(context).pop(true); // 返回成功标志
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('举报成功，我们会尽快处理'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _errorMessage = response['body']?['message'] ?? '举报失败，请重试';
          _isSubmitting = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '网络错误，请重试';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.dialogBackground,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DialogStyles.dialogBorderRadius),
      ),
      insetPadding: const EdgeInsets.all(24.0),
      titlePadding: const EdgeInsets.only(top: 24.0, left: 24.0, right: 24.0, bottom: 16.0),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24.0),
      actionsPadding: const EdgeInsets.all(24.0),
      title: const Text(
        '举报帖子',
        style: DialogStyles.titleTextStyle,
        textAlign: TextAlign.center,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '请描述您举报的理由：',
              style: DialogStyles.contentTextStyle,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 5,
              maxLength: 500,
              decoration: DialogStyles.inputDecoration.copyWith(
                hintText: '例如：该帖子包含不实信息、违规内容等',
                hintStyle: DialogStyles.hintTextStyle,
                errorText: _errorMessage,
                errorStyle: TextStyle(
                  fontSize: 12.0,
                  color: AppColors.danger,
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(
                    color: AppColors.danger,
                    width: 1.5,
                  ),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(
                    color: AppColors.danger,
                    width: 1.5,
                  ),
                ),
              ),
              enabled: !_isSubmitting,
              style: DialogStyles.contentTextStyle.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            // 危险操作警告
            DialogStyles.buildDangerWarning('提示：恶意举报可能会受到处罚'),
          ],
        ),
      ),
      actions: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 提交举报按钮（危险操作）
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReport,
                style: DialogStyles.dangerButtonStyle,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('提交举报'),
              ),
            ),
            const SizedBox(height: DialogStyles.dialogButtonSpacing),
            // 取消按钮
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                style: DialogStyles.cancelButtonStyle,
                child: const Text('取消'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
