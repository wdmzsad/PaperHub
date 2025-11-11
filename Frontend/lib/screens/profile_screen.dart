import 'package:flutter/material.dart';
import 'message_screen.dart';
import 'home_screen.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../widgets/bottom_navigation.dart';
import '../pages/login_page.dart';
import '../pages/note_editor_page.dart';
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with TickerProviderStateMixin {
  int _currentIndex = 3;

  @override
  Widget build(BuildContext context) {
  return DefaultTabController(
    length: 3,
    child: Scaffold(
      // 🔹 添加 Drawer 组件
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.white,
              ),
              child: Text(
                '菜单',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            // 🔹 登出按钮
            ListTile(
              leading: Icon(Icons.logout, color: Colors.red),
              title: Text('登出'),
              onTap: () {
                Navigator.pop(context); // 先关闭Drawer
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPage()),
                );
              },
            ),
          ],
        ),
      ),

      backgroundColor: const Color(0xFFF5F5F5),
      bottomNavigationBar: _buildBottomNavigationBar(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 顶部个人信息区域
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('images/profile_bg.jpg'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.grey.withOpacity(0.7),
                    BlendMode.darken,
                  ),
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Stack(
                    children: [
                      // 🔹 用 Scaffold.of(context).openDrawer() 打开侧边栏
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Builder(
                          builder: (context) => IconButton(
                            icon: const Icon(Icons.menu, color: Colors.white),
                            onPressed: () {
                              Scaffold.of(context).openDrawer();
                            },
                          ),
                        ),
                      ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: IconButton(
                            icon: const Icon(Icons.share_outlined, color: Colors.white),
                            onPressed: () {},
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 20),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const CircleAvatar(
                                radius: 50,
                                backgroundImage: AssetImage('images/touxiang.jpg'),
                              ),
                              const SizedBox(width: 20),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'SCI批发4S店',
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    'hello world',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Container(
                      margin: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: const [
                                _StatItem(title: '关注', count: '120'),
                                SizedBox(width: 50),
                                _StatItem(title: '粉丝', count: '305'),
                                SizedBox(width: 50),
                                _StatItem(title: '动态', count: '42'),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF5F5F5),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('编辑资料'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // 研究方向展示区
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '研究方向',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildDirectionChip('人工智能'),
                          _buildDirectionChip('机器学习'),
                          _buildDirectionChip('多模态学习'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // TabBar + TabBarView
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const TabBar(
                      labelColor: Colors.black,
                      indicatorColor: Colors.blueAccent,
                      tabs: [
                        Tab(text: '笔记'),
                        Tab(text: '论文'),
                        Tab(text: '收藏'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 400,
                      child: TabBarView(
                        children: [
                          _PlaceholderList(label: '笔记'),
                          _PlaceholderList(label: '论文'),
                          _PlaceholderList(label: '收藏'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigation(
      currentIndex: _currentIndex,
      onTap: (index) {
        setState(() {
          _currentIndex = index;
        });

        if (index == 0) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => HomeScreen()),
          ).then((_) {
            // 当从消息页面返回时，恢复首页高亮
            setState(() {
              _currentIndex = 3;
            });
          });
        } 
        else if (index == 1) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MessageScreen()),
          ).then((_) {
            setState(() {
              _currentIndex = 3;
            });
          });
        } else if (index == 2) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const NoteEditorPage()),
          ).then((_) {
            setState(() {
              _currentIndex = 0;
            });
          });
        } else if (index == 3) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ProfilePage()),
          ).then((_) {
            setState(() {
              _currentIndex = 3;
            });
          });
        }
      },
      context: context,
    );
  }

  Widget _buildDirectionChip(String label) {
    return Container(
      margin: const EdgeInsets.only(right: 8.0, bottom: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.black87, fontSize: 14),
      ),
    );
  }

  // 发布笔记（暂定）
  void _showPublishDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('发布笔记'),
        content: const Text('发布功能开发中...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}

// ======= 组件 =======
class _StatItem extends StatelessWidget {
  final String title;
  final String count;

  const _StatItem({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(count,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 5),
        Text(title, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}

class _PlaceholderList extends StatelessWidget {
  final String label;
  const _PlaceholderList({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '这里显示 $label 内容',
        style: const TextStyle(color: Colors.grey, fontSize: 16),
      ),
    );
  }
}