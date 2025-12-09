import 'package:flutter/material.dart';

/// 应用颜色主题
/// 使用新的蓝色系配色方案
class AppColors {
  // 主蓝色系（从浅到深）
  static const Color blueLight1 = Color(0xFFD4E5F7); // 最浅
  static const Color blueLight2 = Color(0xFFC1D6F1);
  static const Color blueLight3 = Color(0xFFA5BEE6);
  static const Color blueMedium = Color(0xFF7CA0DA);
  static const Color blueMedium2 = Color(0xFF5E8BD1);
  static const Color blueDark = Color(0xFF33568F);
  static const Color blueDarkest = Color(0xFF11284D); // 最深

  // 语义化颜色
  static const Color primary = Color(0xFF5E8BD1); // 主色：按钮、链接等
  static const Color primaryPressed = Color(0xFF33568F); // 按钮按下状态
  static const Color primaryLight = Color(0xFFA5BEE6); // 浅色背景
  static const Color primaryLighter = Color(0xFFD4E5F7); // 最浅背景（输入框填充等）

  // 文本颜色
  static const Color textPrimary = Color(0xFF0F172A); // 主要文本
  static const Color textSecondary = Color(0xFF64748B); // 次要文本
  static const Color textOnPrimary = Colors.white; // 主色上的文本

  // 反馈色
  static const Color success = Color(0xFF10B981);      // 成功
  static const Color successLight = Color(0xFFD1FAE5); // 成功浅背景
  static const Color warning = Color(0xFFF59E0B);      // 警告
  static const Color warningLight = Color(0xFFFEF3C7); // 警告浅背景
  static const Color danger = Color(0xFFDC2626);       // 危险/错误
  static const Color dangerLight = Color(0xFFFEE2E2);  // 危险浅背景

  // 弹窗专用颜色 (基于语义化颜色定义)
  static const Color dialogBackground = Colors.white;
  static const Color dialogTitle = textPrimary;
  static const Color dialogContent = textSecondary;
  static const Color dialogCancel = textSecondary; // 取消按钮文本色
  static const Color dialogConfirm = primary;      // 确认按钮背景色
  static const Color dialogDangerBg = dangerLight; // 危险弹窗背景提示色

  // 边框和分割线
  static const Color border = Color(0xFFCBD5E1); // 默认边框
  static const Color borderFocused = primary; // 聚焦边框

  // 背景色
  static const Color background = Colors.white;
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color cardBackground = Colors.white;

  // 阴影
  static BoxShadow get cardShadow => BoxShadow(
        color: Colors.black.withOpacity(0.1),
        blurRadius: 20,
        offset: const Offset(0, 10),
      );
}

