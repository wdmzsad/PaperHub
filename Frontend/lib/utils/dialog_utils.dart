import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/dialog_styles.dart'; // 假设包含所有样式定义
import '../models/dialog_option.dart';

/// 统一对话框工具类
class DialogUtils {
  // 私有构造函数，防止实例化
  DialogUtils._();

  // 加载对话框的显示状态跟踪
  static bool _isLoadingDialogShowing = false;

  // ============================================
  // 辅助方法：左对齐标题和危险提示
  // ============================================

  // 统一的弹窗标题组件
  static Widget _buildDialogTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft, // **优化点 1: 标题左对齐**
      child: Text(
        title,
        style: DialogStyles.titleTextStyle,
        textAlign: TextAlign.left,
      ),
    );
  }

  // 危险操作警告组件
  static Widget _buildDangerWarning(String warningText) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: AppColors.dangerLight, // 浅红色背景
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 20),
          const SizedBox(width: 8.0),
          Expanded(
            child: Text(
              warningText,
              style: DialogStyles.contentTextStyle.copyWith(
                color: AppColors.danger,
                fontWeight: FontWeight.w500,
                height: 1.4, // 增加行高
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // 1. 确认对话框 (A 组)
  // ============================================
  static Future<bool?> showConfirmDialog({
  required BuildContext context,
  required String title,
  String? content,
  bool isDangerous = false,
  String confirmText = '确定',
  String cancelText = '取消',
  String? dangerWarning, // 保留，但只用于内容显示
}) async {
  // 优化点 4: 修改 barrierColor 实现半透明遮罩
  return await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    // **核心修改：使用半透明的 BarrierColor**
    barrierColor: Colors.black.withOpacity(0.4), 
    builder: (context) {
      // 创建内容 Widget 列表
      List<Widget> contentChildren = [];
      
      // 优化点 3: 危险警告不再使用填充背景，直接作为内容展示
      if (isDangerous && dangerWarning != null) {
        contentChildren.add(
          Padding(
            padding: const EdgeInsets.only(bottom: DialogStyles.dialogContentSpacing),
            // 使用 Text 并在样式中设置红色
            child: Text(
              dangerWarning,
              style: DialogStyles.contentTextStyle.copyWith(
                color: AppColors.danger, // 仅文本红色
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center, // **优化点 2: 提示词居中**
            ),
          ),
        );
      }
      
      if (content != null) {
        contentChildren.add(
          Text(
            content,
            style: DialogStyles.contentTextStyle.copyWith(height: 1.4),
            textAlign: TextAlign.center, // **优化点 2: 内容居中**
          ),
        );
      }

      return AlertDialog(
        // AlertDialog 本身背景仍为白色，保证内容清晰
        backgroundColor: AppColors.dialogBackground, 
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DialogStyles.dialogBorderRadius),
        ),
        insetPadding: const EdgeInsets.all(40.0), // 增加左右间距，让弹窗更集中
        titlePadding: const EdgeInsets.only(top: 24.0, left: 24.0, right: 24.0, bottom: 8.0), // 标题下方间距减少
        contentPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0), // 内容间距
        actionsPadding: const EdgeInsets.only(bottom: 16.0, left: 16.0, right: 16.0), // 按钮区域间距

        title: Text(
          title,
          style: DialogStyles.titleTextStyle,
          textAlign: TextAlign.center, // **优化点 2: 标题居中**
        ),
        
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            // 优化点 2: 容器内容居中
            crossAxisAlignment: CrossAxisAlignment.center, 
            children: contentChildren,
          ),
        ),
        
        actions: [
          Row( // **优化点 1: 按钮并排显示 (水平)**
            mainAxisAlignment: MainAxisAlignment.spaceAround, // 按钮平分空间
            children: [
              // 1. 取消按钮 (TextButton 保持简洁)
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: DialogStyles.cancelButtonStyle.copyWith(
                    minimumSize: MaterialStateProperty.all(const Size(0, DialogStyles.dialogButtonHeight)),
                  ),
                  child: Text(cancelText),
                ),
              ),
              const SizedBox(width: DialogStyles.dialogButtonSpacing), // 按钮间距
              // 2. 确认/删除按钮 (如果是危险操作，使用红色 TextButton)
              Expanded(
                child: TextButton( // **优化点 3: 使用 TextButton (无填充色)**
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(
                    // 动态设置前景(文本)颜色
                    foregroundColor: isDangerous 
                      ? AppColors.danger // 红色文本
                      : AppColors.dialogConfirm, // 主色文本
                    minimumSize: const Size(0, DialogStyles.dialogButtonHeight),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    // 背景色设置为透明，或使用 AppColors.dialogBackground
                    backgroundColor: Colors.transparent, 
                  ),
                  child: Text(confirmText, style: TextStyle(fontWeight: FontWeight.bold)), // 稍微加粗确认文本
                ),
              ),
            ],
          ),
        ],
        actionsAlignment: MainAxisAlignment.center,
      );
    },
  );
}

  // ============================================
  // 2. 输入对话框 (B 组)
  // ============================================
  static Future<String?> showInputDialog({
    required BuildContext context,
    required String title,
    String? hintText,
    String? initialValue,
    int maxLines = 1,
    String confirmText = '确定',
    String cancelText = '取消',
    String? Function(String?)? validator,
  }) async {
    final TextEditingController controller = TextEditingController(text: initialValue);
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    return await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.dialogBackground,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DialogStyles.dialogBorderRadius),
          ),
          insetPadding: const EdgeInsets.all(24.0),
          titlePadding: const EdgeInsets.only(top: 24.0, left: 24.0, right: 24.0, bottom: 16.0),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24.0),
          actionsPadding: const EdgeInsets.all(24.0),

          title: _buildDialogTitle(title),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: controller,
                    maxLines: maxLines,
                    minLines: 1,
                    // **优化点 3: 现代输入框样式 (无边框 + 填充)**
                    decoration: InputDecoration(
                      hintText: hintText,
                      hintStyle: DialogStyles.contentTextStyle.copyWith(color: AppColors.textSecondary.withOpacity(0.6)),
                      fillColor: AppColors.backgroundLight, // 极浅的背景填充
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide.none, // 移除边框
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(color: AppColors.primary, width: 1.5), // 聚焦时主色细边框
                      ),
                    ),
                    validator: validator,
                    autofocus: true,
                    style: DialogStyles.contentTextStyle.copyWith(color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            Column( // **优化点 4: 垂直堆叠按钮**
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (formKey.currentState?.validate() ?? false) {
                        Navigator.pop(context, controller.text.trim());
                      }
                    },
                    style: DialogStyles.confirmButtonStyle,
                    child: Text(confirmText),
                  ),
                ),
                const SizedBox(height: 8.0),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: DialogStyles.cancelButtonStyle,
                    child: Text(cancelText),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // ============================================
  // 3. 选择对话框 (C 组)
  // ============================================
  static Future<T?> showSelectionDialog<T>({
    required BuildContext context,
    required String title,
    required List<DialogOption<T>> options,
    String? content,
    bool showCancel = true,
    String cancelText = '取消',
  }) async {
    return await showDialog<T>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.dialogBackground,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DialogStyles.dialogBorderRadius),
          ),
          insetPadding: const EdgeInsets.all(24.0),
          titlePadding: const EdgeInsets.only(top: 24.0, left: 24.0, right: 24.0, bottom: 16.0),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0), // 选项列表的内边距略小
          actionsPadding: const EdgeInsets.all(24.0),

          title: _buildDialogTitle(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (content != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 16.0),
                    child: Text(
                      content,
                      style: DialogStyles.contentTextStyle.copyWith(height: 1.4),
                    ),
                  ),
                ...options.map((option) {
                  return TextButton(
                    onPressed: () => Navigator.pop(context, option.value),
                    // 选项按钮样式优化：全宽，左对齐
                    style: TextButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                      backgroundColor: option.isDangerous
                          ? AppColors.dangerLight
                          : Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                      foregroundColor: option.isDangerous
                          ? AppColors.danger
                          : AppColors.textPrimary,
                    ),
                    child: Row(
                      children: [
                        if (option.icon != null)
                          Icon(
                            option.icon,
                            color: option.color ?? (option.isDangerous ? AppColors.danger : AppColors.textPrimary),
                            size: 20,
                          ),
                        if (option.icon != null) const SizedBox(width: 12.0),
                        Expanded(
                          child: Text(
                            option.label,
                            style: DialogStyles.contentTextStyle.copyWith(
                              fontWeight: FontWeight.w500,
                              color: option.isDangerous ? AppColors.danger : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          actions: showCancel
              ? [
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: DialogStyles.cancelButtonStyle,
                      child: Text(cancelText),
                    ),
                  ),
                ]
              : null,
          actionsAlignment: MainAxisAlignment.center,
        );
      },
    );
  }

  // ============================================
  // 4. 加载指示器 (D 组)
  // ============================================
  static void showLoadingDialog(
  BuildContext context, {
  String? message,
  double? progress, // 新增参数：0.0到1.0的进度值，如果为null则为循环指示器
  bool isModal = true,
  bool barrierDismissible = false,
}) {
  if (_isLoadingDialogShowing) {
    return;
  }

  _isLoadingDialogShowing = true;

  showDialog(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: isModal ? Colors.black.withOpacity(0.4) : Colors.transparent, // 使用半透明遮罩
    builder: (context) {
      return PopScope(
        canPop: barrierDismissible,
        onPopInvoked: (didPop) {
          if (didPop) {
            _isLoadingDialogShowing = false;
          }
        },
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: AppColors.dialogBackground,
              borderRadius: BorderRadius.circular(DialogStyles.dialogBorderRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 30.0,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 核心修改 B: 混合指示器 Stack
                Stack( 
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 50.0,
                      height: 50.0,
                      child: CircularProgressIndicator(
                        value: progress, // 传入 progress 值
                        color: AppColors.primary,
                        strokeWidth: 4.0,
                      ),
                    ),
                    
                    // 只有当 progress 不为 null 时才显示百分比文本
                    if (progress != null)
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: DialogStyles.progressTextStyle, // 引用新增的进度文本样式
                      ),
                  ],
                ),

                // 底部信息文本
                if (message != null) ...[
                  const SizedBox(height: 16.0),
                  Text(
                    message,
                    style: DialogStyles.contentTextStyle.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  ).then((_) {
    _isLoadingDialogShowing = false;
  });
}

  static void hideLoadingDialog(BuildContext context) {
    if (_isLoadingDialogShowing) {
      // 使用 rootNavigator: true 确保能关闭任何层级的弹窗
      Navigator.of(context, rootNavigator: true).pop(); 
      _isLoadingDialogShowing = false;
    }
  }

  // ============================================
  // 5. 快捷方法 (E 组 & A 组的快捷调用)
  // ============================================

  static Future<bool?> showDeleteConfirmDialog({
    required BuildContext context,
    required String itemName,
    String? additionalWarning,
  }) {
    String warning = '删除后将无法恢复，请谨慎操作。';
    if (additionalWarning != null) {
      warning = '$warning\n$additionalWarning';
    }

    return showConfirmDialog(
      context: context,
      title: '确认删除$itemName？',
      content: '此操作不可恢复。',
      isDangerous: true,
      confirmText: '删除',
      dangerWarning: warning, // 核心警告信息作为 dangerWarning 显示
    );
  }

  static Future<bool?> showUnfollowConfirmDialog({
    required BuildContext context,
    required String userName,
  }) {
    return showConfirmDialog(
      context: context,
      title: '不再关注$userName？',
      content: '取消关注后，您将不再看到该用户的动态更新。',
      confirmText: '不再关注',
    );
  }

  static Future<bool?> showClearConfirmDialog({
    required BuildContext context,
    required String itemName,
    String? targetName,
  }) {
    String title = '清空$itemName';
    String content = '确定要清空$itemName吗？';
    String warning = '清空后数据将无法恢复，请确认操作。';

    if (targetName != null) {
      content = '确定要清空与 $targetName 的$itemName吗？';
    }

    return showConfirmDialog(
      context: context,
      title: title,
      content: content,
      isDangerous: true,
      confirmText: '清空',
      dangerWarning: warning,
    );
  }
}