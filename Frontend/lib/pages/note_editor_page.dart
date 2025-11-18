import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';              // 用于 Uint8List
import 'package:flutter/foundation.dart' show kIsWeb;  // 用于 kIsWeb
import 'package:http_parser/http_parser.dart';        // 用于 MediaType
   
   

class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage({Key? key}) : super(key: key);

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  final ImagePicker _picker = ImagePicker();
  List<XFile> _images = []; // 存放已选择的图片，最多9张
  File? _pdfFile; // 存放选中的pdf（只允许1个）
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  // 选择图片（从相册/相机都可以，这里用相册示例）
  Future<void> _pickImage() async {
    if (_images.length >= 9) return;
    final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      setState(() {
        if (_images.length < 9) 
          _images.add(file);
      });
    }
  }

  // 移除指定索引图片
  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  // 选择 PDF（只允许一个）
  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: false,
    );
    if (result != null && result.files.isNotEmpty) {
      final path = result.files.single.path;
      if (path != null) {
        setState(() {
          _pdfFile = File(path);
        });
      }
    }
  }

  // 取消 PDF
  void _removePdf() {
    setState(() {
      _pdfFile = null;
    });
  }

  // 上传图片方法
  Future<String?> _uploadImageToServer(XFile image) async {
    try {
      final uri = Uri.parse('http://localhost:8080/posts/upload');
      final request = http.MultipartRequest('POST', uri);

      if (kIsWeb) {
       // -------------------------------------------
        // ✔ Web 端：使用 bytes 创建 MultipartFile
        // -------------------------------------------
        Uint8List bytes = await image.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: image.name,
            contentType: MediaType('image', image.mimeType?.split('/').last ?? 'jpeg'),
          ),
        );
      } else {
        // -------------------------------------------
        // ✔ 移动端/桌面端：使用文件路径上传
        // -------------------------------------------
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            image.path,
        ),
      );
    }

    final response = await request.send();

    if (response.statusCode == 200) {
      final respStr = await response.stream.bytesToString();
      final Map<String, dynamic> data = jsonDecode(respStr);
      return data['url'];
    } else {
      print("上传失败: ${response.statusCode}");
      return null;
    }
  } catch (e) {
    print('上传图片失败: $e');
    return null;
  }
}

  // 发布逻辑
  Future<void> _publishNote() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty && _images.isEmpty && _pdfFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入标题、正文、图片或附件后再发布')),
      );
      return;
    }

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入标题')),
      );
      return;
    }

    // 显示加载中
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    print('1\n');
    try {
      // 先上传图片获取 URL
      List<String> mediaUrls = [];
      for (var img in _images) {
        print('2\n');
        final url = await _uploadImageToServer(img);
        print(url);
        print("\n");
        if (url != null) mediaUrls.add(url);
      }
      print(3);
      // 调用创建笔记接口
      final resp = await ApiService.createPost(
        title: title,
        content: content.isNotEmpty ? content : null,
        media: mediaUrls.isNotEmpty ? mediaUrls : null,
        tags: null,
        doi: null,
        journal: null,
        year: null,
      );
      print(mediaUrls);
      print("\n");
      // 关闭加载对话框
      if (mounted) Navigator.of(context).pop();

      final status = resp['statusCode'] as int? ?? 500;
      final body = resp['body'] as Map<String, dynamic>?;

      if (status >= 200 && status < 300) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('发布成功')),
          );
          Navigator.of(context).pop(); // 返回上一页
        }
      } else {
        final msg = body != null && body['message'] != null
            ? body['message'].toString()
            : '发布失败';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('网络错误，发布失败')),
        );
      }
    }
  }


  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Widget _buildImageGrid() {
    // 使用 Grid 展示已选图片与“添加”格
    final int total = _images.length < 9 ? _images.length + 1 : 9;
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: total,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, // 一行放4个正方形
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1, // 保证正方形
      ),
      itemBuilder: (context, index) {
        // 如果 index < _images.length：显示图片，右上角显示删除按钮
        if (index < _images.length) {
          return Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: FileImage(File(_images[index].path)),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => _removeImage(index),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(4),
                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        }

        // 否则显示添加按钮
        return GestureDetector(
          onTap: _pickImage,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[200], // 浅灰色背景
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Icon(Icons.add, size: 34, color: Colors.grey),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 整体白色背景，顶部 AppBar 左上角 × 关闭
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0.3,
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: const Text('发布笔记', style: TextStyle(color: Colors.black)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () {
            Navigator.of(context).maybePop();
          },
        ),
        actions: const [SizedBox(width: 48)], // 预留空间使标题居中
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 图片区域
              _buildImageGrid(),
              const SizedBox(height: 16),

              // 标题输入（单行）
              TextField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                maxLines: 1,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  hintText: '添加标题（最多一行）',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 4),
                ),
              ),
              const Divider(height: 1, color: Colors.grey),

              // 正文输入（多行）
              const SizedBox(height: 8),
              TextField(
                controller: _contentController,
                keyboardType: TextInputType.multiline,
                maxLines: null,
                minLines: 6,
                decoration: const InputDecoration(
                  hintText: '写下你的笔记（支持学术笔记格式）',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  isCollapsed: false,
                ),
              ),

              const SizedBox(height: 16),
              // PDF 附件区
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickPdf,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(_pdfFile == null ? '添加 PDF 附件（仅一篇）' : '替换 PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[100],
                      foregroundColor: Colors.black87,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (_pdfFile != null)
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.attach_file, size: 18, color: Colors.grey),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _pdfFile!.path.split('/').last,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          IconButton(
                            onPressed: _removePdf,
                            icon: const Icon(Icons.close, size: 20),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 36),

              // 发布按钮（底部蓝色）
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _publishNote,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('发布笔记', style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
