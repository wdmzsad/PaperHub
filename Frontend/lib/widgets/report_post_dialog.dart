import 'package:flutter/material.dart';
import '../services/api_service.dart';

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
      title: const Text('举报帖子'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '请描述您举报的理由：',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 5,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: '例如：该帖子包含不实信息、违规内容等',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                errorText: _errorMessage,
              ),
              enabled: !_isSubmitting,
            ),
            const SizedBox(height: 8),
            const Text(
              '提示：恶意举报可能会受到处罚',
              style: TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitReport,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('提交举报'),
        ),
      ],
    );
  }
}
