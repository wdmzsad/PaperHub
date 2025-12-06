import 'package:flutter/material.dart';

/// 字体工具类
/// 根据文本内容自动选择字体：中文用 Noto Sans SC，英文用 Inter
class FontUtils {
  /// 检测文本是否包含中文字符
  static bool _containsChinese(String text) {
    return RegExp(r'[\u4e00-\u9fa5]').hasMatch(text);
  }

  /// 获取合适的字体族
  /// 如果文本包含中文，返回 Noto Sans SC；否则返回 Inter
  static String? getFontFamily(String? text) {
    if (text == null || text.isEmpty) return 'Inter';
    return _containsChinese(text) ? 'NotoSansSC' : 'Inter';
  }

  /// 创建 TextStyle，自动选择字体
  static TextStyle textStyle({
    String? text,
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
  }) {
    return TextStyle(
      fontFamily: getFontFamily(text),
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
    );
  }

  /// 为 Text Widget 自动应用字体
  static Widget text(
    String text, {
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
    TextAlign? textAlign,
    TextDecoration? decoration,
  }) {
    return Text(
      text,
      style: textStyle(
        text: text,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        decoration: decoration,
      ),
      textAlign: textAlign,
    );
  }
}

