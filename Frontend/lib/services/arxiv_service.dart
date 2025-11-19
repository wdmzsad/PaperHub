import 'dart:convert';
import 'package:http/http.dart' as http;

/// arXiv 文献元数据模型
class ArxivMetadata {
  final String id;
  final String title;
  final List<String> authors;
  final String? abstract;
  final DateTime? publishedDate;
  final DateTime? updatedDate;
  final List<String> categories;
  final String? doi;
  final String? journal;
  final int? year;

  ArxivMetadata({
    required this.id,
    required this.title,
    required this.authors,
    this.abstract,
    this.publishedDate,
    this.updatedDate,
    this.categories = const [],
    this.doi,
    this.journal,
    this.year,
  });

  /// 格式化作者列表为字符串（用逗号分隔）
  String get authorsFormatted => authors.join(', ');

  /// 格式化发布日期
  String? get publishedDateFormatted {
    if (publishedDate == null) return null;
    return '${publishedDate!.year}-${publishedDate!.month.toString().padLeft(2, '0')}-${publishedDate!.day.toString().padLeft(2, '0')}';
  }

  /// 格式化年份
  int? get yearFormatted => publishedDate?.year ?? year;
}

/// arXiv API 服务
class ArxivService {
  // 使用后端代理解决 CORS 问题
  // 后端代理端点：GET /arxiv?id=1234.5678
  static const String _proxyBaseUrl = 'http://localhost:8080/arxiv';
  static const String _arxivBaseUrl = 'http://export.arxiv.org/api/query';
  
  // 优先使用后端代理（推荐），如果后端未配置则回退到直接访问
  // 注意：直接访问可能在 Web 平台遇到 CORS 问题
  static const bool _useProxy = true; // 设置为 true 使用后端代理
  static String get _baseUrl => _useProxy ? _proxyBaseUrl : _arxivBaseUrl;

  /// 从 arXiv ID 或链接中提取 ID
  /// 支持格式：
  /// - arxiv:1234.5678
  /// - 1234.5678
  /// - https://arxiv.org/abs/1234.5678
  /// - https://arxiv.org/pdf/1234.5678.pdf
  static String? extractArxivId(String input) {
    if (input.isEmpty) return null;

    // 移除首尾空格
    final trimmed = input.trim();

    // 处理完整 URL
    if (trimmed.contains('arxiv.org')) {
      final uri = Uri.tryParse(trimmed);
      if (uri != null) {
        // 从路径中提取 ID
        // 例如: /abs/1234.5678 或 /pdf/1234.5678.pdf
        final pathSegments = uri.pathSegments;
        for (var segment in pathSegments) {
          // 移除 .pdf 扩展名
          segment = segment.replaceAll('.pdf', '');
          // 检查是否是 arXiv ID 格式 (数字.数字)
          if (RegExp(r'^\d{4}\.\d{4,5}(v\d+)?$').hasMatch(segment)) {
            return segment;
          }
        }
      }
    }

    // 处理 arxiv: 前缀
    if (trimmed.startsWith('arxiv:') || trimmed.startsWith('arXiv:')) {
      final id = trimmed.substring(trimmed.indexOf(':') + 1).trim();
      if (_isValidArxivId(id)) {
        return id;
      }
    }

    // 直接检查是否是有效的 arXiv ID
    if (_isValidArxivId(trimmed)) {
      return trimmed;
    }

    return null;
  }

  /// 验证是否是有效的 arXiv ID 格式
  static bool _isValidArxivId(String id) {
    // arXiv ID 格式: YYMM.NNNNN 或 YYMM.NNNNNvN
    // 例如: 1234.5678 或 1234.5678v1
    return RegExp(r'^\d{4}\.\d{4,5}(v\d+)?$').hasMatch(id);
  }

  /// 从 arXiv 获取文献元数据
  /// 
  /// [input] 可以是 arXiv ID 或完整链接
  /// 
  /// 返回 [ArxivMetadata] 或抛出异常
  static Future<ArxivMetadata> fetchMetadata(String input) async {
    // 提取 arXiv ID
    final arxivId = extractArxivId(input);
    if (arxivId == null) {
      throw ArxivException('无效的 arXiv ID 或链接格式。请使用格式如：1234.5678 或 https://arxiv.org/abs/1234.5678');
    }

    try {
      // 构建 API 请求 URL
      final Uri uri;
      if (_useProxy) {
        // 后端代理端点格式：GET /arxiv?id=1234.5678
        uri = Uri.parse(_baseUrl).replace(queryParameters: {'id': arxivId});
      } else {
        // 直接访问 arXiv API（可能在 Web 平台遇到 CORS 问题）
        uri = Uri.parse('$_baseUrl?id_list=$arxivId');
      }

      // 发送请求，设置超时
      final response = await http.get(uri).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw ArxivException('请求超时，请检查网络连接后重试');
        },
      );

      if (response.statusCode != 200) {
        // 检查响应体是否包含错误信息
        final errorBody = response.body;
        if (errorBody.isNotEmpty && errorBody.contains('错误：')) {
          // 后端返回了错误消息
          throw ArxivException(errorBody);
        }
        throw ArxivException('无法连接到 arXiv 服务器，状态码: ${response.statusCode}');
      }

      // 检查响应体是否为空
      if (response.body.isEmpty) {
        throw ArxivException('服务器返回空响应，请确认 arXiv ID 是否正确');
      }

      // 检查响应体是否包含错误信息（后端可能返回错误消息）
      // 注意：只有在响应体以"错误："开头或整个响应都是错误消息时才抛出异常
      // 避免 XML 内容中包含"错误："字符串时误判
      final body = response.body.trim();
      if (body.startsWith('错误：') || (body.length < 200 && body.contains('错误：'))) {
        throw ArxivException(body);
      }

      // 解析 XML 响应
      final metadata = _parseXmlResponse(response.body, arxivId);
      return metadata;
    } on ArxivException {
      rethrow;
    } on http.ClientException catch (e) {
      // 检查是否是 CORS 错误
      final errorMsg = e.message.toLowerCase();
      if (errorMsg.contains('cors') || 
          errorMsg.contains('failed to fetch') || 
          errorMsg.contains('network error')) {
        throw ArxivException(
          '跨域请求被阻止。请通过后端代理访问 arXiv API，或联系管理员配置 CORS。\n'
          '错误详情：${e.message}'
        );
      }
      throw ArxivException('网络错误：${e.message}。请检查网络连接后重试。');
    } on FormatException catch (e) {
      throw ArxivException('响应格式错误：${e.message}');
    } catch (e) {
      if (e is ArxivException) {
        rethrow;
      }
      // 检查是否是 CORS 相关错误
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('failed to fetch') || 
          errorStr.contains('cors') ||
          errorStr.contains('networkerror')) {
        throw ArxivException(
          '跨域请求被阻止。这是浏览器的安全限制。\n'
          '解决方案：请通过后端代理访问 arXiv API。\n'
          '错误详情：${e.toString()}'
        );
      }
      throw ArxivException('获取文献信息失败：${e.toString()}');
    }
  }

  /// 解析 arXiv API 返回的 XML 响应
  static ArxivMetadata _parseXmlResponse(String xmlBody, String arxivId) {
    try {
      // 检查是否有错误信息
      if (xmlBody.contains('<opensearch:totalResults>0</opensearch:totalResults>')) {
        throw ArxivException('未找到 arXiv ID 为 $arxivId 的文献，请确认 ID 是否正确');
      }

      // 检查是否找到了文献（totalResults > 0）
      final totalResultsMatch = RegExp(r'<opensearch:totalResults>(\d+)</opensearch:totalResults>').firstMatch(xmlBody);
      if (totalResultsMatch != null) {
        final totalResults = int.tryParse(totalResultsMatch.group(1) ?? '0') ?? 0;
        if (totalResults == 0) {
          throw ArxivException('未找到 arXiv ID 为 $arxivId 的文献，请确认 ID 是否正确');
        }
      }

      // arXiv API 返回 Atom XML 格式
      // 使用简单的字符串解析（也可以使用 xml 包，但这里为了简单使用字符串解析）

      // 提取标题 - 从 entry 标签中提取（entry 标签内的 title 是文献标题）
      String title = '';
      // 使用更精确的正则表达式匹配 entry 标签
      // 注意：需要匹配到 entry 标签内的 title，而不是 feed 标签的 title
      final entryPattern = RegExp(r'<entry[^>]*>([\s\S]*?)</entry>', dotAll: true);
      final entryMatch = entryPattern.firstMatch(xmlBody);
      
      if (entryMatch != null) {
        final entryContent = entryMatch.group(1) ?? '';
        // 在 entry 内容中查找 title（排除 feed 的 title）
        final titleMatch = RegExp(r'<title[^>]*>([\s\S]*?)</title>', dotAll: true).firstMatch(entryContent);
        if (titleMatch != null) {
          title = titleMatch.group(1)?.trim() ?? '';
          // 移除可能的换行和多余空格，以及 HTML 实体
          title = title
              .replaceAll(RegExp(r'\s+'), ' ')
              .replaceAll('&lt;', '<')
              .replaceAll('&gt;', '>')
              .replaceAll('&amp;', '&')
              .replaceAll('&quot;', '"')
              .replaceAll('&apos;', "'");
        }
      }

      // 如果还是没找到，尝试在整个文档中查找（作为后备方案）
      if (title.isEmpty) {
        // 查找所有 title 标签，跳过第一个（通常是 feed 的 title）
        final allTitleMatches = RegExp(r'<title[^>]*>([\s\S]*?)</title>', dotAll: true).allMatches(xmlBody);
        if (allTitleMatches.length > 1) {
          // 取第二个 title（通常是 entry 的 title）
          title = allTitleMatches.elementAt(1).group(1)?.trim() ?? '';
        } else if (allTitleMatches.isNotEmpty) {
          // 如果只有一个，也使用它
          title = allTitleMatches.first.group(1)?.trim() ?? '';
        }
        title = title
            .replaceAll(RegExp(r'\s+'), ' ')
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>')
            .replaceAll('&amp;', '&')
            .replaceAll('&quot;', '"')
            .replaceAll('&apos;', "'");
      }

      // 提取摘要
      String? abstract;
      if (entryMatch != null) {
        final entryContent = entryMatch.group(1) ?? '';
        final abstractMatch = RegExp(r'<summary[^>]*>(.*?)</summary>', dotAll: true).firstMatch(entryContent);
        if (abstractMatch != null) {
          abstract = abstractMatch.group(1)?.trim();
          // 清理 HTML 实体
          abstract = abstract
              ?.replaceAll('&lt;', '<')
              .replaceAll('&gt;', '>')
              .replaceAll('&amp;', '&')
              .replaceAll('&quot;', '"')
              .replaceAll('&apos;', "'")
              .replaceAll(RegExp(r'\s+'), ' ');
        }
      }

      // 提取作者列表 - 在 entry 中查找
      final authors = <String>[];
      if (entryMatch != null) {
        final entryContent = entryMatch.group(1) ?? '';
        final authorMatches = RegExp(r'<author>\s*<name>(.*?)</name>', dotAll: true).allMatches(entryContent);
        for (var match in authorMatches) {
          final name = match.group(1)?.trim() ?? '';
          if (name.isNotEmpty) {
            authors.add(name.replaceAll(RegExp(r'\s+'), ' '));
          }
        }
      }

      if (authors.isEmpty) {
        // 如果 entry 中没找到，尝试在整个文档中查找
        final authorMatches = RegExp(r'<author>\s*<name>(.*?)</name>', dotAll: true).allMatches(xmlBody);
        for (var match in authorMatches) {
          final name = match.group(1)?.trim() ?? '';
          if (name.isNotEmpty) {
            authors.add(name.replaceAll(RegExp(r'\s+'), ' '));
          }
        }
      }

      // 提取发布日期
      DateTime? publishedDate;
      if (entryMatch != null) {
        final entryContent = entryMatch.group(1) ?? '';
        final publishedMatch = RegExp(r'<published>(.*?)</published>').firstMatch(entryContent);
        if (publishedMatch != null) {
          try {
            final dateStr = publishedMatch.group(1)?.trim();
            if (dateStr != null && dateStr.isNotEmpty) {
              publishedDate = DateTime.parse(dateStr);
            }
          } catch (_) {
            // 解析日期失败，忽略
          }
        }
      }

      // 提取更新日期
      DateTime? updatedDate;
      if (entryMatch != null) {
        final entryContent = entryMatch.group(1) ?? '';
        final updatedMatch = RegExp(r'<updated>(.*?)</updated>').firstMatch(entryContent);
        if (updatedMatch != null) {
          try {
            final dateStr = updatedMatch.group(1)?.trim();
            if (dateStr != null && dateStr.isNotEmpty) {
              updatedDate = DateTime.parse(dateStr);
            }
          } catch (_) {
            // 解析日期失败，忽略
          }
        }
      }

      // 提取分类
      final categories = <String>[];
      if (entryMatch != null) {
        final entryContent = entryMatch.group(1) ?? '';
        final categoryMatches = RegExp(r'<category[^>]*term="([^"]+)"').allMatches(entryContent);
        for (var match in categoryMatches) {
          final category = match.group(1)?.trim();
          if (category != null && category.isNotEmpty) {
            categories.add(category);
          }
        }
      }

      // 提取 DOI（如果存在）
      String? doi;
      if (entryMatch != null) {
        final entryContent = entryMatch.group(1) ?? '';
        final doiMatch = RegExp(r'<arxiv:doi[^>]*>(.*?)</arxiv:doi>', dotAll: true).firstMatch(entryContent);
        if (doiMatch != null) {
          doi = doiMatch.group(1)?.trim();
          if (doi != null && doi.isEmpty) {
            doi = null;
          }
        }
      }

      // 提取期刊引用（如果存在）
      String? journal;
      if (entryMatch != null) {
        final entryContent = entryMatch.group(1) ?? '';
        final journalMatch = RegExp(r'<arxiv:journal_ref[^>]*>(.*?)</arxiv:journal_ref>', dotAll: true).firstMatch(entryContent);
        if (journalMatch != null) {
          journal = journalMatch.group(1)?.trim();
          if (journal != null && journal.isEmpty) {
            journal = null;
          }
        }
      }

      // 验证是否找到了有效数据
      if (title.isEmpty) {
        // 添加调试信息
        print('警告：解析 XML 时未找到标题');
        print('arXiv ID: $arxivId');
        print('XML 内容前 1000 字符: ${xmlBody.length > 1000 ? xmlBody.substring(0, 1000) : xmlBody}');
        // 检查是否有 entry 标签
        if (!xmlBody.contains('<entry>') && !xmlBody.contains('<entry ')) {
          throw ArxivException('XML 响应中未找到 entry 标签，可能 arXiv API 返回了错误格式');
        }
        throw ArxivException('解析文献信息失败：未找到标题。请确认 arXiv ID 是否正确，或联系技术支持。');
      }
      
      // 验证作者列表（警告但不阻止）
      if (authors.isEmpty) {
        print('警告：解析 XML 时未找到作者信息');
      }

      return ArxivMetadata(
        id: arxivId,
        title: title,
        authors: authors,
        abstract: abstract,
        publishedDate: publishedDate,
        updatedDate: updatedDate,
        categories: categories,
        doi: doi,
        journal: journal,
        year: publishedDate?.year,
      );
    } catch (e) {
      if (e is ArxivException) {
        rethrow;
      }
      throw ArxivException('解析 arXiv 响应失败：${e.toString()}');
    }
  }
}

/// arXiv 服务异常类
class ArxivException implements Exception {
  final String message;

  ArxivException(this.message);

  @override
  String toString() => message;
}

