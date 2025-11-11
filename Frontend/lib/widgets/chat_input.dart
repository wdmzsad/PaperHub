/// 聊天输入框组件
///
/// 功能：
/// - 文本输入和发送
/// - 多行文本支持
/// - 表情和附件按钮
/// - 发送按钮状态管理
import 'package:flutter/material.dart';

class ChatInput extends StatefulWidget {
  final TextEditingController controller;
  final Function(String) onSend;
  final String hintText;
  final bool enabled;
  final int maxLines;

  const ChatInput({
    Key? key,
    required this.controller,
    required this.onSend,
    this.hintText = '输入消息...',
    this.enabled = true,
    this.maxLines = 5,
  }) : super(key: key);

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  bool _isComposing = false;
  FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = widget.controller.text.trim();
    setState(() {
      _isComposing = text.isNotEmpty;
    });
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      // 获得焦点时的处理
    }
  }

  void _handleSend() {
    final text = widget.controller.text.trim();
    if (text.isEmpty || !widget.enabled) return;

    widget.onSend(text);
  }

  void _handleEmojiButton() {
    // TODO: 实现表情选择器
    _showEmojiPicker();
  }

  void _handleAttachmentButton() {
    // TODO: 实现附件选择
    _showAttachmentOptions();
  }

  void _showEmojiPicker() {
    // 简单的表情选择实现
    final emojis = ['😀', '😃', '😄', '😁', '😅', '😂', '🤣', '😊', '😇', '🙂', '😉', '😌', '😍', '🥰', '😘', '😗', '😙', '😚', '😋', '😛'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '选择表情',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              height: 200,
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                  childAspectRatio: 1,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: emojis.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      widget.controller.text += emojis[index];
                      Navigator.pop(context);
                      _focusNode.requestFocus();
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          emojis[index],
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '选择附件类型',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF1976D2)),
              title: const Text('图片'),
              subtitle: const Text('从相册选择图片'),
              onTap: () {
                Navigator.pop(context);
                // TODO: 实现图片选择
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF1976D2)),
              title: const Text('拍照'),
              subtitle: const Text('使用相机拍照'),
              onTap: () {
                Navigator.pop(context);
                // TODO: 实现拍照功能
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file, color: Color(0xFF1976D2)),
              title: const Text('文件'),
              subtitle: const Text('选择文档文件'),
              onTap: () {
                Navigator.pop(context);
                // TODO: 实现文件选择
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 表情按钮
          _buildIconButton(
            icon: Icons.emoji_emotions_outlined,
            onPressed: _handleEmojiButton,
          ),

          // 附件按钮
          _buildIconButton(
            icon: Icons.add_circle_outline,
            onPressed: _handleAttachmentButton,
          ),

          // 输入框
          Expanded(
            child: Container(
              constraints: const BoxConstraints(
                minHeight: 40,
                maxHeight: 120,
              ),
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                enabled: widget.enabled,
                maxLines: widget.maxLines,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 16,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
                onSubmitted: (text) {
                  if (_isComposing) {
                    _handleSend();
                  }
                },
              ),
            ),
          ),

          // 发送按钮
          _buildSendButton(),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: IconButton(
        icon: Icon(
          icon,
          color: const Color(0xFF1976D2),
          size: 24,
        ),
        onPressed: widget.enabled ? onPressed : null,
        splashRadius: 20,
      ),
    );
  }

  Widget _buildSendButton() {
    return Container(
      margin: const EdgeInsets.only(left: 4, right: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: _isComposing ? 40 : 32,
        height: _isComposing ? 40 : 32,
        decoration: BoxDecoration(
          color: _isComposing && widget.enabled
              ? const Color(0xFF1976D2)
              : Colors.grey[300],
          borderRadius: BorderRadius.circular(_isComposing ? 20 : 16),
          boxShadow: _isComposing && widget.enabled
              ? [
                  BoxShadow(
                    color: const Color(0xFF1976D2).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: IconButton(
          icon: Icon(
            _isComposing ? Icons.send : Icons.mic,
            color: _isComposing && widget.enabled
                ? Colors.white
                : Colors.grey[600],
            size: _isComposing ? 20 : 16,
          ),
          onPressed: _isComposing && widget.enabled ? _handleSend : null,
          splashRadius: 20,
        ),
      ),
    );
  }
}