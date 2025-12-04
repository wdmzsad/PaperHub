/// 聊天输入框组件
///
/// 功能：
/// - 文本输入和发送
/// - 多行文本支持
/// - 表情和附件按钮
/// - 发送按钮状态管理
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import '../services/local_storage.dart';
import '../config/app_env.dart';

class ChatInput extends StatefulWidget {
  final TextEditingController controller;
  final Function(String) onSend;
  final Function(List<String> mediaUrls, String messageType, String fileName, int fileSize)? onSendMedia;
  final String hintText;
  final bool enabled;
  final int maxLines;

  const ChatInput({
    Key? key,
    required this.controller,
    required this.onSend,
    this.onSendMedia,
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
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _recordingPath;

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
    _audioRecorder.dispose();
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
    final emojis = [
      '😀',
      '😃',
      '😄',
      '😁',
      '😅',
      '😂',
      '🤣',
      '😊',
      '😇',
      '🙂',
      '😉',
      '😌',
      '😍',
      '🥰',
      '😘',
      '😗',
      '😙',
      '😚',
      '😋',
      '😛',
    ];

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
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: Color(0xFF1976D2),
              ),
              title: const Text('图片和视频'),
              subtitle: const Text('从相册选择图片或视频'),
              onTap: () {
                Navigator.pop(context);
                _pickMedia();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF1976D2)),
              title: const Text('拍照'),
              subtitle: const Text('使用相机拍照'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file, color: Color(0xFF1976D2)),
              title: const Text('文件'),
              subtitle: const Text('选择文档文件'),
              onTap: () {
                Navigator.pop(context);
                _pickFile();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _pickMedia() async {
    final ImagePicker picker = ImagePicker();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择类型'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('图片'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? file = await picker.pickImage(source: ImageSource.gallery);
                if (file != null && widget.onSendMedia != null) {
                  await _uploadAndSendMediaFile(file, 'IMAGE');
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library),
              title: const Text('视频'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? file = await picker.pickVideo(source: ImageSource.gallery);
                if (file != null && widget.onSendMedia != null) {
                  await _uploadAndSendMediaFile(file, 'VIDEO');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);

    if (image != null && widget.onSendMedia != null) {
      await _uploadAndSendMediaFile(image, 'IMAGE');
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx',
                          'txt', 'csv', 'zip', 'rar', '7z', 'exe', 'mp4'],
    );

    if (result != null && widget.onSendMedia != null) {
      final file = result.files.single;
      await _uploadAndSendMediaBytes(file.bytes!, file.name, 'FILE');
    }
  }

  Future<void> _uploadAndSendMediaFile(XFile file, String messageType) async {
    final bytes = await file.readAsBytes();
    await _uploadAndSendMediaBytes(bytes, file.name, messageType);
  }

  Future<void> _uploadAndSendMediaBytes(
    List<int> bytes,
    String fileName,
    String messageType,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final url = await _uploadFileBytes(bytes, fileName);

      Navigator.pop(context);

      if (url != null && widget.onSendMedia != null) {
        widget.onSendMedia!([url], messageType, fileName, bytes.length);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('上传失败，未获取到文件URL')),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('上传失败: $e')),
      );
    }
  }

  Future<String?> _uploadFileBytes(List<int> bytes, String fileName) async {
    try {
      final String? token = LocalStorage.instance.read('accessToken');
      if (token == null) {
        throw Exception('未登录');
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppEnv.apiBaseUrl}/api/upload/chat-file'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
      ));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('上传成功: ${data['url']}');
        return data['url'];
      } else {
        throw Exception('上传失败: ${response.body}');
      }
    } catch (e) {
      print('上传文件失败: $e');
      return null;
    }
  }

  Future<void> _startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      final path = '${Directory.systemTemp.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(const RecordConfig(), path: path);
      setState(() {
        _isRecording = true;
        _recordingPath = path;
      });
    }
  }

  Future<void> _stopRecording() async {
    final path = await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
    });

    if (path != null && widget.onSendMedia != null) {
      final file = File(path);
      final bytes = await file.readAsBytes();
      final fileName = path.split('/').last;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final url = await _uploadFileBytes(bytes, fileName);
        Navigator.pop(context);

        if (url != null) {
          widget.onSendMedia!([url], 'VOICE', fileName, bytes.length);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('语音上传失败')),
          );
        }
      } catch (e) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('语音上传失败: $e')),
        );
      } finally {
        file.delete();
      }
    }
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
              constraints: const BoxConstraints(minHeight: 40, maxHeight: 120),
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                enabled: widget.enabled,
                maxLines: widget.maxLines,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: TextStyle(color: Colors.grey[500], fontSize: 16),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                style: const TextStyle(fontSize: 16, color: Colors.black87),
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
        icon: Icon(icon, color: const Color(0xFF1976D2), size: 24),
        onPressed: widget.enabled ? onPressed : null,
        splashRadius: 20,
      ),
    );
  }

  Widget _buildSendButton() {
    if (_isComposing) {
      return Container(
        margin: const EdgeInsets.only(left: 4, right: 8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: widget.enabled ? const Color(0xFF1976D2) : Colors.grey[300],
            borderRadius: BorderRadius.circular(20),
            boxShadow: widget.enabled
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
              Icons.send,
              color: widget.enabled ? Colors.white : Colors.grey[600],
              size: 20,
            ),
            onPressed: widget.enabled ? _handleSend : null,
            splashRadius: 20,
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(left: 4, right: 8),
      child: GestureDetector(
        onLongPressStart: (_) => _startRecording(),
        onLongPressEnd: (_) => _stopRecording(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: _isRecording ? 48 : 32,
          height: _isRecording ? 48 : 32,
          decoration: BoxDecoration(
            color: _isRecording
                ? Colors.red
                : (widget.enabled ? const Color(0xFF1976D2) : Colors.grey[300]),
            borderRadius: BorderRadius.circular(_isRecording ? 24 : 16),
            boxShadow: _isRecording
                ? [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            Icons.mic,
            color: widget.enabled ? Colors.white : Colors.grey[600],
            size: _isRecording ? 24 : 16,
          ),
        ),
      ),
    );
  }
}
