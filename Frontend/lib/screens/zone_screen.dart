import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../constants/discipline_constants.dart';
import '../models/post_model.dart';
import '../services/api_service.dart';
import '../widgets/post_card.dart';
import 'post_detail_screen.dart';

/// 分区瀑布流页面
/// - 顶部 AppBar 显示当前分区名称，带返回按钮
/// - 下方第一行是可左右滑动的分区切换条
/// - 主体是当前分区下的帖子瀑布流（分页加载）
class ZoneScreen extends StatefulWidget {
  final String initialDiscipline;
  /// 是否显示 AppBar（从帖子详情进入时为 true，从首页分区内部进入时可设为 false）
  final bool showAppBar;

  const ZoneScreen({
    Key? key,
    required this.initialDiscipline,
    this.showAppBar = true,
  }) : super(key: key);

  @override
  State<ZoneScreen> createState() => _ZoneScreenState();
}

class _ZoneScreenState extends State<ZoneScreen> {
  late String _currentDiscipline;

  final ScrollController _scrollController = ScrollController();
  final List<Post> _posts = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _currentDiscipline = widget.initialDiscipline;
    _loadFirstPage();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _loadNextPage();
    }
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _isLoading = true;
      _hasMore = true;
      _page = 1;
      _posts.clear();
    });

    try {
      final resp = await ApiService.getPosts(
        page: 1,
        pageSize: 12,
        disciplineTag: _currentDiscipline,
      );
      final status = resp['statusCode'] as int? ?? 500;
      final body = resp['body'] as Map<String, dynamic>?;

      if (status >= 200 && status < 300 && body != null) {
        final postsData = (body['posts'] as List<dynamic>?) ?? [];
        final total = body['total'] as int? ?? postsData.length;
        final newPosts = postsData
            .map((e) => Post.fromJson(e as Map<String, dynamic>))
            .toList();
        setState(() {
          _posts.addAll(newPosts);
          _hasMore = _posts.length < total;
          _page = 2;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadNextPage() async {
    if (_isLoading || !_hasMore) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final resp = await ApiService.getPosts(
        page: _page,
        pageSize: 12,
        disciplineTag: _currentDiscipline,
      );
      final status = resp['statusCode'] as int? ?? 500;
      final body = resp['body'] as Map<String, dynamic>?;
      if (status >= 200 && status < 300 && body != null) {
        final postsData = (body['posts'] as List<dynamic>?) ?? [];
        final total = body['total'] as int? ?? postsData.length;
        final newPosts = postsData
            .map((e) => Post.fromJson(e as Map<String, dynamic>))
            .toList();
        setState(() {
          _posts.addAll(newPosts);
          _hasMore = _posts.length < total;
          _page += 1;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onDisciplineChanged(String discipline) {
    if (discipline == _currentDiscipline) return;
    setState(() {
      _currentDiscipline = discipline;
    });
    _loadFirstPage();
  }

  @override
  Widget build(BuildContext context) {
    final color = kDisciplineColors[_currentDiscipline] ?? Colors.blue;
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: Text(
                _currentDiscipline,
                style: const TextStyle(color: Colors.black),
              ),
              backgroundColor: Colors.white,
              iconTheme: const IconThemeData(color: Colors.black),
              elevation: 0.3,
            )
          : null,
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          _buildZoneSelectorBar(),
          const Divider(height: 1),
          Expanded(
            child: _isLoading && _posts.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadFirstPage,
                    child: _posts.isEmpty
                        ? ListView(
                            children: [
                              SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.5,
                                child: Center(
                                  child: Text(
                                    '当前分区暂时没有内容\n去发布一条笔记试试吧～',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : MasonryGridView.count(
                            controller: _scrollController,
                            crossAxisCount: 2,
                            crossAxisSpacing: 3,
                            mainAxisSpacing: 3,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 3,
                              vertical: 3,
                            ),
                            itemCount: _posts.length + (_hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _posts.length) {
                                if (_isLoading) {
                                  return const Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              }
                              final post = _posts[index];
                              return PostCard(
                                post: post,
                                onTap: () {
                                  // 使用与其他界面一致的方式导航到帖子详情页
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PostDetailScreen(post: post),
                                    ),
                                  );
                                },
                                onAuthorTap: () {
                                  Navigator.of(context)
                                      .pushNamed('/user/${post.author.id}');
                                },
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneSelectorBar() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: kMainDisciplines.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final discipline = kMainDisciplines[index];
          final selected = discipline == _currentDiscipline;
          final color = kDisciplineColors[discipline] ?? Colors.blue;
          return GestureDetector(
            onTap: () => _onDisciplineChanged(discipline),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? color.withOpacity(0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected ? color : Colors.grey.shade300,
                ),
              ),
              child: Center(
                child: Text(
                  discipline,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected ? color : Colors.black87,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}


