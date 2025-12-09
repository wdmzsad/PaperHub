import 'package:flutter/material.dart';

/// 对话框选项模型
/// 用于选择类对话框的选项配置
class DialogOption<T> {
  final T value;
  final String label;
  final IconData? icon;
  final Color? color;
  final bool isDangerous;

  const DialogOption({
    required this.value,
    required this.label,
    this.icon,
    this.color,
    this.isDangerous = false,
  });

  /// 创建文本按钮选项
  DialogOption.text({
    required T value,
    required String label,
    bool isDangerous = false,
  }) : this(
          value: value,
          label: label,
          isDangerous: isDangerous,
        );

  /// 创建带图标的选项
  DialogOption.withIcon({
    required T value,
    required String label,
    required IconData icon,
    Color? color,
    bool isDangerous = false,
  }) : this(
          value: value,
          label: label,
          icon: icon,
          color: color,
          isDangerous: isDangerous,
        );
}