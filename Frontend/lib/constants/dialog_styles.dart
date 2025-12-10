import 'package:flutter/material.dart';
import 'app_colors.dart'; 

/// 对话框样式常量
class DialogStyles {
  // 布局常量
  static const double dialogBorderRadius = 12.0;
  static const double dialogButtonSpacing = 8.0; // 按钮垂直间距减小
  static const double dialogButtonHeight = 48.0; // 按钮高度略增，提升点击区域
  static const double dialogContentSpacing = 16.0;
  static const double dialogIconSize = 20.0; // 图标大小略减，更精致

  // 文本样式
  static const TextStyle titleTextStyle = TextStyle(
    fontSize: 18.0,
    fontWeight: FontWeight.w700, // **优化点：标题加粗至 W700**
    color: AppColors.dialogTitle,
    height: 1.3,
  );

  static const TextStyle progressTextStyle = TextStyle( // **新增样式**
    fontSize: 14.0,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle contentTextStyle = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w400,
    color: AppColors.dialogContent,
    height: 1.4, // **优化点：内容行高调整至 1.4，增加呼吸感**
  );

  static const TextStyle hintTextStyle = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  // ===================================
  // 按钮样式优化 (全部改为全宽以支持垂直堆叠)
  // ===================================

  // 统一的 ButtonStyle 基础，用于实现全宽
  static ButtonStyle _fullWidthButtonStyle(Color backgroundColor, Color foregroundColor) {
    return ButtonStyle(
      minimumSize: MaterialStateProperty.all(
        const Size(double.infinity, dialogButtonHeight), // **关键优化：全宽**
      ),
      padding: MaterialStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 20.0), // 垂直 padding 不再需要，由 height 控制
      ),
      shape: MaterialStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
      backgroundColor: MaterialStateProperty.all(backgroundColor),
      foregroundColor: MaterialStateProperty.all(foregroundColor),
      // 增加轻微的阴影效果（可选，提升立体感）
      elevation: MaterialStateProperty.all(0),
      overlayColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.pressed)) {
          return foregroundColor.withOpacity(0.1); // 按下时的水波纹颜色
        }
        return null;
      }),
    );
  }

  static ButtonStyle get cancelButtonStyle => TextButton.styleFrom(
        foregroundColor: AppColors.dialogCancel,
        minimumSize: const Size(double.infinity, dialogButtonHeight),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
      );

  static ButtonStyle get confirmButtonStyle => _fullWidthButtonStyle(
        AppColors.dialogConfirm,
        Colors.white,
      );

  static ButtonStyle get dangerButtonStyle => _fullWidthButtonStyle(
        AppColors.danger,
        Colors.white,
      );

  static ButtonStyle get optionButtonStyle => TextButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        backgroundColor: Colors.transparent,
        minimumSize: const Size(double.infinity, 48.0),
        padding: const EdgeInsets.symmetric(
          horizontal: 16.0, // 选项 padding 略小，提供更灵活的布局
          vertical: 12.0,
        ),
        alignment: Alignment.centerLeft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
      );

  // ===================================
  // 输入框样式优化 (无边框 + 填充)
  // ===================================
  static InputDecoration get inputDecoration => InputDecoration(
        filled: true,
        fillColor: AppColors.backgroundLight, // **优化点：使用 backgroundLight，更柔和**
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide.none, // **优化点：移除边框**
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(
            color: AppColors.primary, // **优化点：聚焦边框使用主色**
            width: 1.5, // 细一点
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 12.0,
        ),
        hintStyle: hintTextStyle,
      );

  // ===================================
  // 危险操作警告样式 (保持不变，已在 DialogUtils 中内联使用)
  // ===================================
  static Widget buildDangerWarning(String text) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: AppColors.dangerLight, // 浅红背景
        borderRadius: BorderRadius.circular(8.0),
        // 移除边框，依赖填充色和阴影（如果 AppColors 中有）
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: AppColors.danger,
            size: dialogIconSize,
          ),
          const SizedBox(width: 8.0),
          Expanded(
            child: Text(
              text,
              style: contentTextStyle.copyWith(
                color: AppColors.danger,
                fontWeight: FontWeight.w500,
                height: 1.4, // 保证与内容行高一致
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 弹窗主题 (可选，如果通过 Theme 设置)
  static DialogTheme get dialogTheme => DialogTheme(
        backgroundColor: AppColors.dialogBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0, // **优化点：移除默认 elevation，依赖自定义阴影**
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(dialogBorderRadius),
        ),
        alignment: Alignment.center,
        insetPadding: const EdgeInsets.all(24.0), // 与 DialogUtils 中的 padding 保持一致
      );
}