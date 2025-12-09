import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../config/app_env.dart';
import '../services/api_service.dart';
import '../services/arxiv_service.dart';
import '../services/local_storage.dart';
import '../constants/discipline_constants.dart';
import '../models/post_model.dart';
import '../models/user_profile.dart';

class NoteEditorPage extends StatefulWidget {
  /// 如果传入 initialPost，则进入“编辑模式”，否则是“新建笔记”
  final Post? initialPost;

  const NoteEditorPage({Key? key, this.initialPost}) : super(key: key);

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  final ImagePicker _picker = ImagePicker();

  // 图片与 PDF
  List<XFile> _images = []; // 最多 9 张
  File? _pdfFile; // 仅允许 1 个 PDF
  Uint8List? _pdfFileBytes; // Web 平台的 PDF 字节数据
  String? _pdfFileName; // Web 平台的 PDF 文件名

  // 文本输入
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  // 外部链接
  final TextEditingController _linkController = TextEditingController();
  final List<String> _externalLinks = [];

  // arXiv 相关
  final TextEditingController _arxivController = TextEditingController();
  ArxivMetadata? _arxivMetadata;
  bool _isLoadingArxiv = false;
  String? _arxivId;
  String? _doi;
  String? _journal;
  int? _year;

  // 分区与推荐细分类标签
  String? _selectedDiscipline; // 必选：学科分区
  bool _showDisciplineDropdown = false; // 控制下拉菜单显示
  String? _currentUserRole; // 当前用户角色

  // 高级选项（外部链接 / arXiv / 引用文献 / PDF）是否展开
  bool _showAdvancedOptions = false; // 默认收起

  // #符号触发标签选择相关状态
  bool _showTagSuggestions = false;
  String _currentTagInput = '';
  List<String> _filteredTagSuggestions = [];
  final FocusNode _contentFocusNode = FocusNode();
  bool _isTypingCustomTag = false;

  // 引用文献相关状态
  List<int> _selectedReferences = []; // 已选择的引用帖子ID列表
  List<Post> _userPosts = []; // 用户的帖子列表
  List<Post> _userFavorites = []; // 用户的收藏列表
  bool _isLoadingReferences = false;

  /// 编辑模式下旧图片的 URL 列表
  final List<String> _existingImageUrls = [];
  /// 编辑模式下旧 PDF 的 URL
  String? _existingPdfUrl;
  /// 是否处于编辑模式
  bool get _isEditing => widget.initialPost != null;

  @override
  void initState() {
    super.initState();
    // 如果传入了 initialPost，则进入编辑模式，预填内容
    if (_isEditing && widget.initialPost != null) {
      _applyExistingPost(widget.initialPost!);
    }
    // 获取当前用户角色
    _loadCurrentUserRole();
  }

  // 加载当前用户角色
  Future<void> _loadCurrentUserRole() async {
    try {
      // 尝试从API获取当前用户信息
      final response = await ApiService.getCurrentUserProfile();
      final status = response['statusCode'] as int? ?? 500;

      if (status >= 200 && status < 300) {
        final body = response['body'] as Map<String, dynamic>?;
        if (body != null) {
          final userProfile = UserProfile.fromJson(body);
          setState(() {
            _currentUserRole = userProfile.role.toUpperCase();
          });
          return;
        }
      }

      // 如果API调用失败，尝试从本地存储获取
      final userJson = LocalStorage.instance.read('currentUser');
      if (userJson != null) {
        try {
          final userData = jsonDecode(userJson) as Map<String, dynamic>;
          final userProfile = UserProfile.fromJson(userData);
          setState(() {
            _currentUserRole = userProfile.role.toUpperCase();
          });
          return;
        } catch (e) {
          print('解析本地用户数据失败: $e');
        }
      }

      // 如果都失败，设置为普通用户
      setState(() {
        _currentUserRole = 'USER';
      });
    } catch (e) {
      print('获取用户角色失败: $e');
      // 失败时设置为普通用户
      setState(() {
        _currentUserRole = 'USER';
      });
    }
    // 异步加载用户的帖子和收藏，用于引用文献选择
    // 不在initState中立即调用，而是在需要时调用，这样可以避免阻塞UI
  }

  // 将已有帖子内容灌入编辑器（编辑模式）
  void _applyExistingPost(Post post) {
    // 标题 & 正文
    _titleController.text = post.title;
    _contentController.text = post.content;

    // 已有媒体：区分图片和 PDF
    _existingImageUrls.clear();
    _existingPdfUrl = null;
    if (post.media.isNotEmpty) {
      for (final m in post.media) {
        if (m.isEmpty) continue;
        if (_isPdfUrl(m)) {
          // 只用第一份 PDF
          _existingPdfUrl ??= m;
        } else {
          _existingImageUrls.add(m);
        }
      }
    }

    // 外部链接
    _externalLinks
      ..clear()
      ..addAll(post.externalLinks);

    // 文献信息 / arXiv
    _arxivId = post.arxivId;
    _doi = post.doi;
    _journal = post.journal;
    _year = post.year;

    if (post.arxivId != null && post.arxivId!.isNotEmpty) {
      _arxivController.text = post.arxivId!;
      _arxivMetadata = ArxivMetadata(
        id: post.arxivId!,
        title: post.title,
        authors: post.arxivAuthors,
        abstract: null,
        publishedDate: post.arxivPublishedDate != null
            ? DateTime.tryParse(post.arxivPublishedDate!)
            : null,
        updatedDate: null,
        categories: post.arxivCategories,
        doi: post.doi,
        journal: post.journal,
        year: post.year,
      );
    }

    // 预填充引用文献
    _selectedReferences = List.from(post.references);
  }

  // 判断 URL 是否为 PDF
  bool _isPdfUrl(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.pdf');
  }

  // 选择图片
  Future<void> _pickImage() async {
    if (_images.length >= 9) return;
    final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      setState(() {
        if (_images.length < 9) {
          _images.add(file);
        }
      });
    }
  }

  // 移除指定索引图片
  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  // 移除已有的 PDF（编辑模式）
  void _removeExistingPdf() {
    setState(() {
      _existingPdfUrl = null;
    });
  }

  // 选择 PDF（只允许一个）
  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: kIsWeb, // Web 平台需要读取字节数据
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.single;
      if (kIsWeb) {
        // Web 平台：使用字节数据创建临时文件路径标识
        if (file.bytes != null) {
          setState(() {
            // 在 Web 上，我们存储文件名和字节数据
            // 使用一个特殊的路径格式来标识这是 Web 文件
            _pdfFile = File('web://${file.name}');
            // 存储字节数据以便后续上传
            _pdfFileBytes = file.bytes;
            _pdfFileName = file.name;
            // 选了新的 PDF，则视为替换旧附件
            _existingPdfUrl = null;
          });
        }
      } else {
        // 移动平台：使用文件路径
        final path = file.path;
        if (path != null) {
          setState(() {
            _pdfFile = File(path);
            _pdfFileBytes = null;
            _pdfFileName = null;
            _existingPdfUrl = null;
          });
        }
      }
    }
  }

  // 取消 PDF
  void _removePdf() {
    setState(() {
      _pdfFile = null;
      _pdfFileBytes = null;
      _pdfFileName = null;
    });
  }

   /// 校验链接格式是否可识别，只接受 http / https
  bool _isValidUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return false;

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return false;

    return uri.isScheme('http') || uri.isScheme('https');
  }

  // 上传图片到后端，返回 URL
  Future<String?> _uploadFileToServer(XFile file, String fileType) async {
  try {
    final uri = Uri.parse('${AppEnv.apiBaseUrl}/posts/upload');
    final request = http.MultipartRequest('POST', uri);

    if (fileType == 'image') {
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: file.name,
            contentType: MediaType('image', file.mimeType?.split('/').last ?? 'jpeg'),
          ),
        );
      } else {
        request.files.add(await http.MultipartFile.fromPath('file', file.path));
      }
    } else if (fileType == 'pdf') {
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: file.name,
            contentType: MediaType('application', 'pdf'),
          ),
        );
      } else {
        request.files.add(await http.MultipartFile.fromPath('file', file.path));
      }
    } else {
      print('不支持的文件类型');
      return null;
    }

    final response = await request.send();
    if (response.statusCode == 200) {
      final respStr = await response.stream.bytesToString();
      final data = jsonDecode(respStr) as Map<String, dynamic>;
      return data['url'] as String?;
    } else {
      print('上传失败: ${response.statusCode}');
      return null;
    }
  } catch (e) {
    print('上传文件失败: $e');
    return null;
  }
}

  // 发布 / 编辑 笔记
  Future<void> _publishNote() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    // 不允许为空的内容
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入标题')),
      );
      return;
    }
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入正文')),
      );
      return;
    }
    // 只有“新建笔记”强制要求必须选择图片；编辑时可以只改文字 / 链接
    if (!_isEditing && _images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请添加图片')),
      );
      return;
    }
    if (_selectedDiscipline == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择一个学科分区')),
      );
      return;
    }

    // 显示加载中
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 从正文中提取#标签
      final textTags = _extractTagsFromText(content);

      // 组装标签：至少包含一个主分区，加上正文中的所有#标签
      final List<String> tags = [
        _selectedDiscipline!,
        ...textTags,
      ].toSet().toList();

      List<String> mediaUrls = [];

      // 往里面加已有的图片 URL
      mediaUrls.addAll(_existingImageUrls);

      // 如果你还有别的要加，比如新选的图片 / pdf，就继续：
      if (_existingPdfUrl != null) {
        mediaUrls.add(_existingPdfUrl!);
      }


      // 2) 上传新选择的图片
      for (var img in _images) {
        final url = await _uploadFileToServer(img, 'image');
        if (url != null) mediaUrls.add(url);
      }

      // 3) 处理 PDF：优先使用新选择的 PDF，其次沿用旧的 URL
      String? pdfUrlToUse;
      if (_pdfFile != null) {
        XFile pdfXFile;
        if (kIsWeb) {
          if (_pdfFileBytes == null) {
            if (mounted) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PDF 文件数据异常，请重新选择')),
              );
            }
            return;
          }
          pdfXFile = XFile.fromData(
            _pdfFileBytes!,
            name: _pdfFileName ?? 'document.pdf',
            mimeType: 'application/pdf',
          );
        } else {
          pdfXFile = XFile(_pdfFile!.path);
        }
        pdfUrlToUse = await _uploadFileToServer(pdfXFile, 'pdf');
      } else if (_existingPdfUrl != null) {
        pdfUrlToUse = _existingPdfUrl;
      }

      if (pdfUrlToUse != null) {
        mediaUrls.add(pdfUrlToUse);
      }

      // 4) 外部链接（过滤空字符串）
      final links =
          _externalLinks.where((e) => e.trim().isNotEmpty).toList();

      // 5) arXiv 相关
      final String? arxivPublishedDate =
          _arxivMetadata?.publishedDateFormatted;
      final List<String>? arxivAuthors = _arxivMetadata?.authors;
      final List<String>? arxivCategories = _arxivMetadata?.categories;

      // 6) 调用后端接口：新建 or 更新
      Map<String, dynamic> resp;
      if (_isEditing && widget.initialPost != null) {
        // === 编辑已有帖子 ===
        resp = await ApiService.updatePost(
          postId: widget.initialPost!.id,
          title: title,
          content: content.isNotEmpty ? content : null,
          media: mediaUrls,
          mainDiscipline: _selectedDiscipline!,
          doi: _doi,
          journal: _journal,
          year: _year,
          externalLinks: links.isNotEmpty ? links : null,
          arxivId: _arxivId,
          arxivAuthors: arxivAuthors,
          arxivPublishedDate: arxivPublishedDate,
          arxivCategories: arxivCategories,
          references: _selectedReferences.isNotEmpty ? _selectedReferences : null,
        );
      } else {
        // === 新建帖子 ===
        resp = await ApiService.createPost(
          title: title,
          content: content.isNotEmpty ? content : null,
          media: mediaUrls.isNotEmpty ? mediaUrls : null,
          mainDiscipline: _selectedDiscipline!,
          doi: _doi,
          journal: _journal,
          year: _year,
          externalLinks: links.isNotEmpty ? links : null,
          arxivId: _arxivId,
          arxivAuthors: arxivAuthors,
          arxivPublishedDate: arxivPublishedDate,
          arxivCategories: arxivCategories,
          references: _selectedReferences.isNotEmpty ? _selectedReferences : null,
        );
      }

      // 关闭加载对话框
      if (mounted) Navigator.of(context).pop();

      final status = resp['statusCode'] as int? ?? 500;
      final body = resp['body'] as Map<String, dynamic>?;

      if (status >= 200 && status < 300) {
        if (mounted) {
          Post? createdPost;
          // 尝试从响应体解析新建的帖子，便于返回给首页直接展示
          if (!_isEditing && body != null) {
            final raw = body['post'] ?? body;
            if (raw is Map<String, dynamic>) {
              createdPost = Post.fromJson(raw);
            }
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isEditing ? '笔记已更新' : '发布成功'),
            ),
          );
          // 返回 true，告诉上一个页面“需要刷新”
          Navigator.of(context).pop(createdPost ?? true);
        }
      } else {
        final msg = body != null && body['message'] != null
            ? body['message'].toString()
            : (_isEditing ? '保存失败' : '发布失败');
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
          SnackBar(
            content: Text(
              _isEditing ? '保存失败，网络错误' : '发布失败，网络错误',
            ),
          ),
        );
      }
    }
  }

  // 从 arXiv 获取文献元数据
  Future<void> _fetchArxivMetadata() async {
    final input = _arxivController.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入 arXiv ID 或链接')),
      );
      return;
    }

    setState(() {
      _isLoadingArxiv = true;
    });

    try {
      final metadata = await ArxivService.fetchMetadata(input);
      
      setState(() {
        _arxivMetadata = metadata;
        _arxivId = metadata.id;
        
        // 自动填充标题（如果为空）
        if (_titleController.text.trim().isEmpty) {
          _titleController.text = metadata.title;
        }
        
        // 填充元数据
        _doi = metadata.doi;
        _journal = metadata.journal;
        _year = metadata.yearFormatted;
        
        // 如果摘要存在且内容为空，可以添加到内容中
        if (metadata.abstract != null && _contentController.text.trim().isEmpty) {
          _contentController.text = '摘要：${metadata.abstract}';
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('成功获取文献信息：${metadata.title}'),
          backgroundColor: Colors.green,
        ),
      );
    } on ArxivException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      setState(() {
        _arxivMetadata = null;
        _arxivId = null;
        _doi = null;
        _journal = null;
        _year = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('获取文献信息失败：${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      setState(() {
        _arxivMetadata = null;
        _arxivId = null;
        _doi = null;
        _journal = null;
        _year = null;
      });
    } finally {
      setState(() {
        _isLoadingArxiv = false;
      });
    }
  }

  // 清除 arXiv 信息
  void _clearArxivMetadata() {
    setState(() {
      _arxivController.clear();
      _arxivMetadata = null;
      _arxivId = null;
      _doi = null;
      _journal = null;
      _year = null;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _linkController.dispose();
    _arxivController.dispose();
    super.dispose();
  }

  // 移除已有图片（编辑模式）
  void _removeExistingImage(int index) {
    setState(() {
      _existingImageUrls.removeAt(index);
    });
  }

  // 图片九宫格
  // 图片九宫格（支持：已有图片 + 新选图片）
  Widget _buildImageGrid() {
    final int existingCount = _existingImageUrls.length;
    final int newCount = _images.length;
    final int totalImages = existingCount + newCount;

    // 最多 9 张，多出来的不再显示“添加”按钮
    final bool showAddButton = totalImages < 9;
    final int itemCount = showAddButton ? totalImages + 1 : totalImages;

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itemCount,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        // 1) 先画“已有图片”（后端返回的 URL）
        if (index < existingCount) {
          final url = _existingImageUrls[index];
          return Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: NetworkImage(url), // 用网络图
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => _removeExistingImage(index),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(3),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        // 2) 再画“新选图片”（本地 XFile）
        final int newIndex = index - existingCount;
        if (newIndex < newCount) {
          return Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: FileImage(File(_images[newIndex].path)),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => _removeImage(newIndex),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(3),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        // 3) 最后是“添加图片”按钮
        return GestureDetector(
          onTap: _pickImage,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
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

  // 拉取 arXiv 文献信息区
  Widget _buildArxivSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'arXiv 文献信息',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _arxivController,
                decoration: InputDecoration(
                  hintText: '输入 arXiv ID (如: 1234.5678) 或链接',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  enabled: !_isLoadingArxiv,
                ),
                onSubmitted: (_) => _fetchArxivMetadata(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _isLoadingArxiv ? null : _fetchArxivMetadata,
              icon: _isLoadingArxiv
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search, size: 18),
              label: const Text('获取'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        if (_arxivMetadata != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _arxivMetadata!.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: _clearArxivMetadata,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_arxivMetadata!.authors.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '作者：${_arxivMetadata!.authorsFormatted}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ),
                if (_arxivMetadata!.publishedDateFormatted != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '发布日期：${_arxivMetadata!.publishedDateFormatted}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ),
                if (_arxivMetadata!.categories.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '分类：${_arxivMetadata!.categories.join(", ")}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ),
                if (_arxivMetadata!.doi != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'DOI：${_arxivMetadata!.doi}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ),
                if (_arxivMetadata!.journal != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '期刊：${_arxivMetadata!.journal}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ),
                if (_arxivId != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'arXiv ID: $_arxivId',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // 外部链接输入区
  Widget _buildExternalLinksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          '外部链接',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _linkController,
                decoration: const InputDecoration(
                  hintText: '输入链接后点击右侧添加',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () {
                final text = _linkController.text.trim();

                if (text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('链接不能为空')),
                  );
                  return;
                }

                if (!_isValidUrl(text)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('链接格式不正确，请以 http 或 https 开头')),
                  );
                  return;
                }

                setState(() {
                  _externalLinks.add(text);
                  _linkController.clear();
                });
              },
              icon: const Icon(Icons.add_link, size: 18),
              label: const Text('添加'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_externalLinks.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _externalLinks.map((link) {
              return Chip(
                label: SizedBox(
                  width: 160,
                  child: Text(
                    link,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                onDeleted: () {
                  setState(() {
                    _externalLinks.remove(link);
                  });
                },
              );
            }).toList(),
          ),
      ],
    );
  }

  // 一级标签选择（放在外部链接之上）- 下拉隐藏式选择器
  Widget _buildDisciplineSelector() {
    final filteredDisciplines = _getFilteredDisciplines();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题行
        Row(
          children: [
            const Text(
              '选择分区',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '必选',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Spacer(),

            // 显示已选分区和下拉按钮
            Row(
              children: [
                if (_selectedDiscipline != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: kDisciplineColors[_selectedDiscipline]?.withOpacity(0.1) ?? const Color(0xFF1976D2).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: kDisciplineColors[_selectedDiscipline]?.withOpacity(0.3) ?? const Color(0xFF1976D2).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _selectedDiscipline!,
                      style: TextStyle(
                        fontSize: 14,
                        color: kDisciplineColors[_selectedDiscipline] ?? const Color(0xFF1976D2),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                // 下拉按钮
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showDisciplineDropdown = !_showDisciplineDropdown;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Icon(
                      _showDisciplineDropdown ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 20,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),

        // 下拉菜单区域 - 椭圆形文字泡矩阵排布
        if (_showDisciplineDropdown)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题和关闭按钮
                Row(
                  children: [
                    const Text(
                      '选择分区',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _showDisciplineDropdown = false;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 椭圆形文字泡矩阵
                Wrap(
                  spacing: 10, // 水平间距
                  runSpacing: 10, // 垂直间距
                  children: filteredDisciplines.map((discipline) {
                    final bool selected = _selectedDiscipline == discipline;
                    final color = kDisciplineColors[discipline] ?? const Color(0xFF1976D2);

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedDiscipline = discipline;
                          _showDisciplineDropdown = false; // 选择后收起下拉菜单
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected ? color.withOpacity(0.12) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(20), // 椭圆形
                          border: Border.all(
                            color: selected ? color : Colors.grey.shade300,
                            width: selected ? 1.5 : 1,
                          ),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: color.withOpacity(0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 颜色指示点
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withOpacity(0.4),
                                    blurRadius: 3,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              discipline,
                              style: TextStyle(
                                fontSize: 13,
                                color: selected ? color : Colors.black87,
                                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                            if (selected)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                child: Icon(
                                  Icons.check_circle,
                                  size: 14,
                                  color: color,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                // 如果没有选择任何分区，显示提示
                if (_selectedDiscipline == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 14, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '请点击上方的椭圆形标签选择一个分区',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

        const SizedBox(height: 8),
        const Text(
          '选择学科分区后，在正文中输入#可添加相关细分类标签',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  // 获取当前可选的二级标签（用于#符号提示）
  List<String> _getAvailableSubTags() {
    if (_selectedDiscipline != null &&
        kRecommendedSubTags.containsKey(_selectedDiscipline)) {
      return kRecommendedSubTags[_selectedDiscipline!]!;
    } else {
      final set = <String>{};
      for (final list in kRecommendedSubTags.values) {
        set.addAll(list);
      }
      return set.toList();
    }
  }

  // 获取过滤后的分区列表（根据用户角色隐藏"公告区"）
  List<String> _getFilteredDisciplines() {
    // 如果用户角色未加载或不是管理员，隐藏"公告区"
    if (_currentUserRole == 'ADMIN') {
      return kMainDisciplines; // 管理员可以看到所有分区
    } else {
      // 普通用户或角色未加载时隐藏"公告区"
      return kMainDisciplines.where((discipline) => discipline != '公告区').toList();
    }
  }

  // 处理正文文本变化，检测#符号
  void _onContentChanged(String text) {
    // 检查是否正在输入#标签 - 只检查最后一个#，并且后面没有空格
    final lastIndex = text.lastIndexOf('#');
    if (lastIndex != -1) {
      // 提取#后面的所有内容
      final afterHash = text.substring(lastIndex + 1);

      // 检查#后面是否有空格或换行（表示标签已结束）
      final nextSpaceIndex = afterHash.indexOf(' ');
      final nextNewlineIndex = afterHash.indexOf('\n');

      // 如果#后面有空格或换行，表示标签已结束
      if (nextSpaceIndex != -1 || nextNewlineIndex != -1) {
        // 完成自定义标签输入
        _completeCustomTag();

        // 立即隐藏建议
        setState(() {
          _showTagSuggestions = false;
          _currentTagInput = '';
          _filteredTagSuggestions.clear();
          _isTypingCustomTag = false;
        });
        return;
      }

      // 如果#后面没有内容，不显示建议
      if (afterHash.isEmpty) {
        if (_showTagSuggestions) {
          setState(() {
            _showTagSuggestions = false;
            _currentTagInput = '';
            _filteredTagSuggestions.clear();
            _isTypingCustomTag = false;
          });
        }
        return;
      }

      // 提取当前正在输入的标签内容（到空格或换行为止）
      final endIndex = nextSpaceIndex != -1
          ? nextSpaceIndex
          : (nextNewlineIndex != -1 ? nextNewlineIndex : afterHash.length);

      if (endIndex > 0) {
        final tagInput = afterHash.substring(0, endIndex);

        setState(() {
          _currentTagInput = tagInput;
          _showTagSuggestions = true;

          // 过滤标签建议
          final availableTags = _getAvailableSubTags();
          _filteredTagSuggestions.clear();
          if (tagInput.isNotEmpty) {
            _filteredTagSuggestions.addAll(
              availableTags.where((tag) =>
                tag.toLowerCase().contains(tagInput.toLowerCase())
              ).toList()
            );
          }

          // 限制显示数量
          if (_filteredTagSuggestions.length > 10) {
            _filteredTagSuggestions = _filteredTagSuggestions.sublist(0, 10);
          }

          // 如果没有匹配的建议，表示用户正在输入自定义标签
          if (_filteredTagSuggestions.isEmpty && tagInput.isNotEmpty) {
            _isTypingCustomTag = true;
          } else {
            _isTypingCustomTag = false;
          }
        });
        return;
      }
    }

    // 如果没有#标签输入，隐藏建议
    if (_showTagSuggestions) {
      setState(() {
        _showTagSuggestions = false;
        _currentTagInput = '';
        _filteredTagSuggestions.clear();
        _isTypingCustomTag = false;
      });
    }
  }

  // 选择标签建议
  void _selectTagSuggestion(String tag) {
    final currentText = _contentController.text;
    final lastIndex = currentText.lastIndexOf('#');

    if (lastIndex != -1) {
      // 替换#及其后面的输入为完整的标签
      final beforeHash = currentText.substring(0, lastIndex);
      final afterHash = currentText.substring(lastIndex);
      final nextSpaceIndex = afterHash.indexOf(' ');
      final nextNewlineIndex = afterHash.indexOf('\n');
      final endIndex = nextSpaceIndex != -1
          ? nextSpaceIndex
          : (nextNewlineIndex != -1 ? nextNewlineIndex : afterHash.length);

      final newText = beforeHash + '#$tag ';
      _contentController.text = newText;
      _contentController.selection = TextSelection.fromPosition(
        TextPosition(offset: newText.length)
      );


      // 隐藏建议
      setState(() {
        _showTagSuggestions = false;
        _currentTagInput = '';
        _filteredTagSuggestions.clear();
        _isTypingCustomTag = false;
      });
    }
  }

  // 处理自定义标签完成（按空格或回车）
  void _completeCustomTag() {
    if (_currentTagInput.isNotEmpty && !_filteredTagSuggestions.contains(_currentTagInput)) {
      // 这是一个自定义标签
      final currentText = _contentController.text;
      final lastIndex = currentText.lastIndexOf('#');

      if (lastIndex != -1) {
        // 替换#及其后面的输入为完整的自定义标签
        final beforeHash = currentText.substring(0, lastIndex);
        final afterHash = currentText.substring(lastIndex);
        final nextSpaceIndex = afterHash.indexOf(' ');
        final nextNewlineIndex = afterHash.indexOf('\n');
        final endIndex = nextSpaceIndex != -1
            ? nextSpaceIndex
            : (nextNewlineIndex != -1 ? nextNewlineIndex : afterHash.length);

        final newText = beforeHash + '#$_currentTagInput ';
        _contentController.text = newText;
        _contentController.selection = TextSelection.fromPosition(
          TextPosition(offset: newText.length)
        );

      }
    }

    // 隐藏建议
    setState(() {
      _showTagSuggestions = false;
      _currentTagInput = '';
      _filteredTagSuggestions.clear();
      _isTypingCustomTag = false;
    });
  }

  // 从文本中提取所有#标签
  Set<String> _extractTagsFromText(String text) {
    final Set<String> tags = {};
    // 匹配#后面的非空格字符，支持中文、英文、数字等
    final regex = RegExp(r'#([^\s#]+)');
    final matches = regex.allMatches(text);

    for (final match in matches) {
      if (match.groupCount >= 1) {
        final tag = match.group(1)!.trim();
        if (tag.isNotEmpty) {
          tags.add(tag);
        }
      }
    }

    return tags;
  }

  // 加载用户的帖子和收藏（用于引用文献选择）
  Future<void> _loadUserPostsAndFavorites() async {
    setState(() {
      _isLoadingReferences = true;
    });

    try {
      // 获取当前用户信息
      final userResp = await ApiService.getCurrentUserProfile();
      if (userResp['statusCode'] == 200) {
        final userId = userResp['body']['id']?.toString();

        // 检查用户ID是否存在
        if (userId == null || userId.isEmpty) {
          print('用户ID为空，无法加载引用文献');
          return;
        }

        // 并行加载用户帖子和收藏
        final results = await Future.wait([
          ApiService.getUserPosts(userId!, page: 1, pageSize: 50),
          ApiService.getUserFavorites(userId!, page: 1, pageSize: 50),
        ]);

        final postsResp = results[0] as Map<String, dynamic>;
        final favoritesResp = results[1] as Map<String, dynamic>;

        if (postsResp['statusCode'] == 200) {
          final postsData = postsResp['body']['posts'] as List<dynamic>? ?? [];
          setState(() {
            _userPosts = postsData.map((p) => Post.fromJson(p)).toList();
          });
        }

        if (favoritesResp['statusCode'] == 200) {
          final favoritesData = favoritesResp['body']['posts'] as List<dynamic>? ?? [];
          setState(() {
            _userFavorites = favoritesData.map((p) => Post.fromJson(p)).toList();
          });
        }
      }
    } catch (e) {
      print('加载用户帖子和收藏失败: $e');
    } finally {
      setState(() {
        _isLoadingReferences = false;
      });
    }
  }

  // 选择引用文献对话框
  void _showReferenceSelector() async {
    // 如果还没有加载过数据，先加载
    if (_userPosts.isEmpty && _userFavorites.isEmpty && !_isLoadingReferences) {
      await _loadUserPostsAndFavorites();
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('选择引用文献'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: '我的帖子'),
                      Tab(text: '我的收藏'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // 我的帖子标签页
                        _buildPostList(_userPosts, setState),
                        // 我的收藏标签页
                        _buildPostList(_userFavorites, setState),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                this.setState(() {}); // 刷新页面显示选中的引用
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }

  // 构建帖子列表
  Widget _buildPostList(List<Post> posts, StateSetter setState) {
    if (_isLoadingReferences) {
      return const Center(child: CircularProgressIndicator());
    }

    if (posts.isEmpty) {
      return const Center(child: Text('暂无内容'));
    }

    return ListView.builder(
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        final postId = int.tryParse(post.id) ?? 0;
        final isSelected = _selectedReferences.contains(postId);

        return ListTile(
          leading: Checkbox(
            value: isSelected,
            onChanged: (bool? value) {
              setState(() {
                final postId = int.tryParse(post.id) ?? 0;
                if (value == true) {
                  _selectedReferences.add(postId);
                } else {
                  _selectedReferences.remove(postId);
                }
              });
            },
          ),
          title: Text(
            post.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${post.author.name} · ${post.createdAt.year}-${post.createdAt.month.toString().padLeft(2, '0')}-${post.createdAt.day.toString().padLeft(2, '0')}',
            style: const TextStyle(fontSize: 12),
          ),
          onTap: () {
            // 点击文字区域时切换checkbox状态
            setState(() {
              final postId = int.tryParse(post.id) ?? 0;
              if (isSelected) {
                _selectedReferences.remove(postId);
              } else {
                _selectedReferences.add(postId);
              }
            });
          },
        );
      },
    );
  }

  // 构建标签建议列表
  Widget _buildTagSuggestions() {
        if (!_showTagSuggestions) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade300),
      ),
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _isTypingCustomTag ? '自定义标签（按空格或回车完成输入）' : '标签建议（输入#继续筛选）',
              style: TextStyle(
                fontSize: 12,
                color: _isTypingCustomTag ? Colors.orange.shade700 : Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Divider(height: 1),
          ..._filteredTagSuggestions.map((tag) {
            // 检查标签是否已经出现在正文中
            final bool alreadySelected = _contentController.text.contains('#$tag ');
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _selectTagSuggestion(tag),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.shade200,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.tag,
                        size: 16,
                        color: alreadySelected ? Colors.blue : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 14,
                            color: alreadySelected ? Colors.blue : Colors.black87,
                            fontWeight: alreadySelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (alreadySelected)
                        Icon(
                          Icons.check,
                          size: 16,
                          color: Colors.blue,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
          if (_filteredTagSuggestions.isEmpty && _currentTagInput.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isTypingCustomTag
                        ? '正在输入自定义标签 "$_currentTagInput"，按空格或回车完成输入'
                        : '未找到匹配的标签，按空格或回车可输入自定义标签 "$_currentTagInput"',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // 引用文献输入区
  Widget _buildReferencesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '引用文献',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _showReferenceSelector,
              icon: const Icon(Icons.library_books, size: 18),
              label: const Text('添加引用文献'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[100],
                foregroundColor: Colors.black87,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(width: 12),
            if (_selectedReferences.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '已选择 ${_selectedReferences.length} 篇',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
        if (_selectedReferences.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '已选择的引用文献：',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 8),
                ..._selectedReferences.map((postId) {
                  // 从用户帖子和收藏中找到对应的帖子信息
                  final post = [..._userPosts, ..._userFavorites]
                      .where((p) => int.tryParse(p.id) == postId)
                      .cast<Post?>()
                      .firstWhere((p) => p != null, orElse: () => null);

                  if (post != null) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '[${_selectedReferences.indexOf(postId) + 1}] ${post.author.name}. ${post.title}. ${post.mainDiscipline}, ${post.createdAt.year}-${post.createdAt.month.toString().padLeft(2, '0')}-${post.createdAt.day.toString().padLeft(2, '0')}.',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _selectedReferences.remove(postId);
                              });
                            },
                            icon: const Icon(Icons.close, size: 16),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    );
                  } else {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '[${_selectedReferences.indexOf(postId) + 1}] 帖子ID: $postId (信息加载中...)',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _selectedReferences.remove(postId);
                              });
                            },
                            icon: const Icon(Icons.close, size: 16),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    );
                  }
                }),
              ],
            ),
          ),
        ],
      ],
    );
  }

    // PDF 附件区域
  Widget _buildPdfSection(bool hasPdf) {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: _pickPdf,
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: Text(
            hasPdf ? '替换 PDF' : '添加 PDF 附件（仅一篇）',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[100],
            foregroundColor: Colors.black87,
            elevation: 0,
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
        ),
        const SizedBox(width: 12),
        if (hasPdf)
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _pdfFile != null
                          ? (_pdfFileName ?? '已选择 PDF')
                          : (_existingPdfUrl!.split('/').last),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      if (_pdfFile != null) {
                        _removePdf();        // 清空新选 PDF
                      } else {
                        _removeExistingPdf(); // 清空旧的 PDF URL
                      }
                    },
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasPdf = _pdfFile != null || _existingPdfUrl != null;

    return Theme(
      data: ThemeData.light(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0.3,
          backgroundColor: Colors.white,
          automaticallyImplyLeading: false,
          title: Text(
            _isEditing ? '编辑笔记' : '发布笔记',
            style: const TextStyle(color: Colors.black),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.black),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          actions: const [SizedBox(width: 48)],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildImageGrid(),
                const SizedBox(height: 16),
                TextField(
                  controller: _titleController,
                  textInputAction: TextInputAction.next,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  _buildTagSuggestions(),
                ],
              ),

              // 一级标签选择（学科分区）
              _buildDisciplineSelector(),
              const SizedBox(height: 16),

              // 高级选项入口（+ 号展开 / 收起）
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '更多学术选项（可选）',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _showAdvancedOptions = !_showAdvancedOptions;
                      });
                    },
                    icon: Icon(
                      _showAdvancedOptions
                          ? Icons.remove_circle_outline  // 展开时显示 -
                          : Icons.add_circle_outline,     // 收起时显示 +
                      color: const Color(0xFF1976D2),
                    ),
                  ),
                ],
              ),

              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                crossFadeState: _showAdvancedOptions
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 外部链接区
                    _buildExternalLinksSection(),
                    const SizedBox(height: 16),

                    // arXiv 文献信息区
                    _buildArxivSection(),
                    const SizedBox(height: 16),

                    // 引用文献区
                    _buildReferencesSection(),
                    const SizedBox(height: 16),

                    // PDF 附件
                    _buildPdfSection(hasPdf),
                  ],
                ),
                secondChild: const SizedBox.shrink(),
              ),

              const SizedBox(height: 24),

              // 发布按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _publishNote,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _isEditing ? '保存修改' : '发布笔记',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
