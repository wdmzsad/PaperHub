/// 底部导航组件（封装 BottomNavigationBar 的样式与交互）
///
/// 职责：
/// - 统一提供底部导航的 UI 样式（圆角 + 阴影 + 固定四个入口）。
/// - 对外暴露 `currentIndex` 与 `onTap`，由上层决定导航逻辑（如路由跳转、弹窗等）。
///
/// 设计说明：
/// - 使用 `Container + ClipRRect` 实现顶部圆角与阴影，内部承载 `BottomNavigationBar`。
/// - `type: fixed` 保证四个 item 平分宽度并同时显示文本。
/// - 颜色规范：选中项 `0xFF1976D2`（蓝色），未选中灰色；字号统一为 12。
/// - items 顺序：0=首页，1=消息，2=发布，3=我的；上层可据此在 onTap 中分支。
///
/// 注意：
/// - 本组件包含一个 `context` 字段，当前实现中未在 `build` 内部显式使用，
///   可作为上层透传的上下文以便未来扩展（例如展示 Sheet/Overlay 等），
///   如无需要也可在不影响兼容性的前提下考虑移除（本次仅注释，不改动代码）。
import 'package:flutter/material.dart';

/// 简单、可复用的底部导航无状态组件
class BottomNavigation extends StatelessWidget {
  /// 当前激活的导航索引（0~3），用于高亮对应的 tab。
  final int currentIndex;
  /// 点击导航项时回调索引，由上层处理跳转/弹窗等逻辑。
  final Function(int) onTap;
  /// 透传的构建上下文（当前未使用，保留以供扩展）。
  final BuildContext context;

  const BottomNavigation({
    Key? key,
    required this.currentIndex,
    required this.onTap,
    required this.context,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 外层容器：负责投影与圆角；底部吸附由上层 Scaffold 的 bottomNavigationBar 承载。
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
        boxShadow: [
          // 向上的轻微阴影以强调分层（offset y 为负数）
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
        // 使用裁剪保证 BottomNavigationBar 本身也遵循顶部圆角
        child: BottomNavigationBar(
          // 高亮索引与点击事件均由上层传入，组件仅做展示
          currentIndex: currentIndex,
          onTap: onTap,
          // 固定类型：展示四个均分的 tab
          type: BottomNavigationBarType.fixed,
          // 配色与字号
          selectedItemColor: const Color(0xFF1976D2),
          unselectedItemColor: Colors.grey,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          // 四个固定入口：图标采用 outlined/filled 形态分别对应未选中/选中
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: '首页',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.message_outlined),
              activeIcon: Icon(Icons.message),
              label: '消息',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.add_circle_outline),
              activeIcon: Icon(Icons.add_circle),
              label: '发布',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outlined),
              activeIcon: Icon(Icons.person),
              label: '我的',
            ),
          ],
        ),
      ),
    );
  }
}
