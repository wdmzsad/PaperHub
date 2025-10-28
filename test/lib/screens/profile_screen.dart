import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController( // 外层包裹整个 Scaffold
      length: 4,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5), // 浅灰色背景
        body: SingleChildScrollView(
          child: Column(
            children: [
              // 顶部个人信息区域
              // ================= 顶部背景 + 头像 + 粉丝栏 =================
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('profile_bg.jpg'),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      Colors.grey.withOpacity(0.7), // 背景半透明遮罩
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
                        // 左上角菜单图标
                        Positioned(
                          top: 10,
                          left: 10,
                          child: IconButton(
                            icon: const Icon(Icons.menu, color: Colors.white),
                            onPressed: () {},
                          ),
                        ),

                        // 右上角分享图标
                        Positioned(
                          top: 10,
                          right: 10,
                          child: IconButton(
                            icon: const Icon(Icons.share_outlined, color: Colors.white),
                            onPressed: () {},
                          ),
                        ),

                        // 头像 + 昵称 + 简介
                        Padding(
                          padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 20),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const CircleAvatar(
                                radius: 50,
                                backgroundImage: AssetImage('touxiang.jpg'),
                              ),
                              const SizedBox(width: 20),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'SCI批发4S店',
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
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

                    // ======== 关注 / 粉丝 / 动态栏 ========
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

              // ======= 研究方向展示区（新增） =======
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '研究方向',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 白色背景卡片
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
                      // 内部"方向标签"按钮区域
                      child: Wrap(
                        spacing: 8, // 水平间距
                        runSpacing: 8, // 垂直间距
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

              // Tab 切换（笔记 / 论文 / 收藏）
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // 外边距，避免贴边
                padding: const EdgeInsets.all(12), // 内边距
                decoration: BoxDecoration(
                  color: Colors.white, // 白色底
                  borderRadius: BorderRadius.circular(12), // 圆角矩形
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1), // 阴影颜色
                      blurRadius: 6, // 模糊半径
                      offset: const Offset(0, 3), // 阴影偏移
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const TabBar(
                      labelColor: Colors.black,
                      indicatorColor: Colors.blueAccent, // 可选：选中条颜色
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

        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            child: BottomNavigationBar(
              backgroundColor: const Color(0xFFF5F5F5), // ✅ 浅灰色背景
              // 当前索引（先固定为 0，不需要改结构）
              currentIndex: 0,

              // 暂时禁用点击逻辑（因为你还没做各页面）
              onTap: (index) {},

              type: BottomNavigationBarType.fixed,
              selectedItemColor: const Color(0xFF1976D2),
              unselectedItemColor: Colors.grey,
              selectedFontSize: 12,
              unselectedFontSize: 12,

              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: '首页',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.category_outlined),
                  activeIcon: Icon(Icons.category),
                  label: '分类',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.message_outlined),
                  activeIcon: Icon(Icons.message),
                  label: '消息',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: '我的',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 研究方向小标签构建方法
  Widget _buildDirectionChip(String label) {
    return Container(
      margin: const EdgeInsets.only(right: 8.0, bottom: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2), // 浅灰底色
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.black87, // 字体颜色
          fontSize: 14,
        ),
      ),
    );
  }
}

// ======= 组件 =======

// 关注/粉丝/动态统计组件
class _StatItem extends StatelessWidget {
  final String title;
  final String count;

  const _StatItem({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(count, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 5),
        Text(title, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}

// Tab 内容的占位组件
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
