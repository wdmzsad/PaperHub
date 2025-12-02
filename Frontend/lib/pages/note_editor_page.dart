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
import '../constants/discipline_constants.dart';

class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage({Key? key}) : super(key: key);

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

  // #符号触发标签选择相关状态
  bool _showTagSuggestions = false;
  String _currentTagInput = '';
  List<String> _filteredTagSuggestions = [];
  final FocusNode _contentFocusNode = FocusNode();
  bool _isTypingCustomTag = false;

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

  // 发布逻辑
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
    if (_images.isEmpty) {
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

      // 调用创建笔记接口（注意：ApiService.createPost 需要支持 externalLinks / tags 参数）
      List<String> mediaUrls = [];
      // 先上传图片获取 URL
      for (var img in _images) {
        print('2\n');
        final url = await _uploadFileToServer(img, 'image');
        print(url);
        print("\n");
        if (url != null) mediaUrls.add(url);
      }
      // 再上传 PDF（如有）
      if (_pdfFile != null) {
        String? pdfUrl;
        if (kIsWeb && _pdfFileBytes != null && _pdfFileName != null) {
          // Web 平台：使用字节数据上传
          final uri = Uri.parse('${AppEnv.apiBaseUrl}/posts/upload');
          final request = http.MultipartRequest('POST', uri);
          request.files.add(
            http.MultipartFile.fromBytes(
              'file',
              _pdfFileBytes!,
              filename: _pdfFileName!,
              contentType: MediaType('application', 'pdf'),
            ),
          );
          final response = await request.send();
          if (response.statusCode == 200) {
            final respStr = await response.stream.bytesToString();
            final data = jsonDecode(respStr) as Map<String, dynamic>;
            pdfUrl = data['url'] as String?;
          }
        } else {
          // 移动平台：使用文件路径上传
          final pdfXFile = XFile(_pdfFile!.path);
          pdfUrl = await _uploadFileToServer(pdfXFile, 'pdf');
        }
        if (pdfUrl != null) mediaUrls.add(pdfUrl);
      }
      // 调用创建笔记接口
      final resp = await ApiService.createPost(
        title: title,
        content: content.isNotEmpty ? content : null,
        media: mediaUrls.isNotEmpty ? mediaUrls : null,
        tags: tags.isNotEmpty ? tags : null,
        doi: _doi,
        journal: _journal,
        year: _year,
        externalLinks: _externalLinks.isNotEmpty ? _externalLinks : null,
        arxivId: _arxivId,
        arxivAuthors: _arxivMetadata?.authors,
        arxivPublishedDate: _arxivMetadata?.publishedDateFormatted,
        arxivCategories: _arxivMetadata?.categories,
      );

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

  // 图片九宫格
  Widget _buildImageGrid() {
    final int total = _images.length < 9 ? _images.length + 1 : 9;
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: total,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
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
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(4),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        // “添加图片” 按钮
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

  // 一级标签选择（放在外部链接之上）
  Widget _buildDisciplineSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '选择学科分区',
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
            if (_selectedDiscipline != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                    fontSize: 12,
                    color: kDisciplineColors[_selectedDiscipline] ?? const Color(0xFF1976D2),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // 一级标签水平滚动选择
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: kMainDisciplines.length,
            separatorBuilder: (context, index) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final d = kMainDisciplines[index];
              final bool selected = _selectedDiscipline == d;
              final color = kDisciplineColors[d] ?? const Color(0xFF1976D2);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (_selectedDiscipline == d) {
                      _selectedDiscipline = null;
                    } else {
                      _selectedDiscipline = d;
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected ? color.withOpacity(0.15) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected ? color : Colors.grey.shade300,
                      width: selected ? 1.5 : 1,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: color.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    d,
                    style: TextStyle(
                      fontSize: 13,
                      color: selected ? color : Colors.black87,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
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

      // 如果#后面直接是空格或换行，表示标签已结束
      if (nextSpaceIndex == 0 || nextNewlineIndex == 0) {
        // 完成自定义标签输入
        _completeCustomTag();
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
          print('可用标签数量: ${availableTags.length}'); // 调试
          print('当前输入: "$tagInput"'); // 调试
          _filteredTagSuggestions.clear();
          if (tagInput.isNotEmpty) {
            _filteredTagSuggestions.addAll(
              availableTags.where((tag) =>
                tag.toLowerCase().contains(tagInput.toLowerCase())
              ).toList()
            );
          }

          print('过滤后标签数量: ${_filteredTagSuggestions.length}'); // 调试
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

  // 构建标签建议列表
  Widget _buildTagSuggestions() {
    print('构建标签建议: _showTagSuggestions=$_showTagSuggestions, _filteredTagSuggestions.length=${_filteredTagSuggestions.length}, _isTypingCustomTag=$_isTypingCustomTag'); // 调试
    if (!_showTagSuggestions) {
      print('不显示标签建议'); // 调试
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

  @override
  Widget build(BuildContext context) {
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
        actions: const [SizedBox(width: 48)],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              
              //选择图片
              _buildImageGrid(),
              const SizedBox(height: 16),

              // 标题
              TextField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                decoration: const InputDecoration(
                  hintText: '添加标题（最多一行）',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 4),
                ),
              ),
              const Divider(height: 1, color: Colors.grey),

              const SizedBox(height: 8),

              // 正文（支持#符号添加标签）
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _contentController,
                    focusNode: _contentFocusNode,
                    keyboardType: TextInputType.multiline,
                    maxLines: null,
                    minLines: 6,
                    onChanged: _onContentChanged,
                    decoration: const InputDecoration(
                      hintText: '写下你的笔记（输入#添加标签，支持学术笔记格式）',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                      isCollapsed: false,
                    ),
                  ),
                  _buildTagSuggestions(),
                ],
              ),

              // 一级标签选择（学科分区）
              _buildDisciplineSelector(),
              const SizedBox(height: 16),

              // 外部链接区
              _buildExternalLinksSection(),

              const SizedBox(height: 16),

              // arXiv 文献信息区
              _buildArxivSection(),

              const SizedBox(height: 16),

              // PDF 附件
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickPdf,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(
                      _pdfFile == null ? '添加 PDF 附件（仅一篇）' : '替换 PDF',
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
                  if (_pdfFile != null)
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.attach_file,
                              size: 18, color: Colors.grey),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _pdfFileName ?? _pdfFile!.path.split('/').last,
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
                  child: const Text(
                    '发布笔记',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
