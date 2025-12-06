import 'package:flutter/material.dart';
import '../services/background_service.dart';
import '../utils/font_utils.dart';

/// 高级标题动画组件：
/// - 背景随机选择bg1-4.png
/// - PaperHub 字母弹性快速进场（可选）
/// - 含缩放 + 顺序动画 + 收尾整体动效
/// - 网站级启动动画观感
class AnimatedTitleBackground extends StatefulWidget {
  final Widget child;
  final bool enableAnimation; // 是否启用动画

  const AnimatedTitleBackground({
    Key? key,
    required this.child,
    this.enableAnimation = true,
  }) : super(key: key);

  @override
  State<AnimatedTitleBackground> createState() => _AnimatedTitleBackgroundState();
}

class _AnimatedTitleBackgroundState extends State<AnimatedTitleBackground>
    with TickerProviderStateMixin {

  final String _title = 'PaperHub';

  // === 参数调优（已是最佳观感）===
  final int _animationDuration = 400;    // 单字母动画时长
  final int _delayBetweenLetters = 80;   // 字母间延迟

  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  // 整体收尾动画
  late AnimationController _groupController;
  late Animation<double> _groupScale;

  @override
  void initState() {
    super.initState();

    if (widget.enableAnimation) {
      // 创建字母动画控制器
      _controllers = List.generate(
        _title.length,
        (_) => AnimationController(
          duration: Duration(milliseconds: _animationDuration),
          vsync: this,
        ),
      );

      // 每个字母的动画（弹性曲线）
      _animations = _controllers.map((controller) {
        return CurvedAnimation(
          parent: controller,
          curve: Curves.easeOutBack,
        );
      }).toList();

      // 整体 Logo 收尾动画（轻微回弹）
      _groupController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      );

      _groupScale = Tween<double>(begin: 1.06, end: 1.0).animate(
        CurvedAnimation(
          parent: _groupController,
          curve: Curves.easeOut,
        ),
      );

      _startAnimations();
    } else {
      // 静态模式：直接设置为完成状态
      _controllers = List.generate(
        _title.length,
        (_) => AnimationController(
          duration: Duration(milliseconds: 1),
          vsync: this,
        ),
      );

      _animations = _controllers.map((controller) {
        return Tween<double>(begin: 1.0, end: 1.0).animate(controller);
      }).toList();

      _groupController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1),
      );

      _groupScale = Tween<double>(begin: 1.0, end: 1.0).animate(_groupController);

      // 立即完成所有动画
      for (var controller in _controllers) {
        controller.value = 1.0;
      }
      _groupController.value = 1.0;
    }
  }

  void _startAnimations() {
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(
        Duration(milliseconds: i * _delayBetweenLetters),
        () {
          if (mounted) {
            _controllers[i].forward();

            // 最后一个字母触发整体回弹
            if (i == _controllers.length - 1) {
              Future.delayed(const Duration(milliseconds: 150), () {
                if (mounted) {
                  _groupController.forward();
                }
              });
            }
          }
        },
      );
    }
  }

  @override
  void dispose() {
    if (widget.enableAnimation) {
      for (var c in _controllers) {
        c.dispose();
      }
      _groupController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [

        /// ✅ 背景图片（随机选择）
        Image.asset(
          BackgroundService().getCurrentBackground(),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF0F172A),
                    Color(0xFF1E3A8A),
                    Color(0xFF2563EB),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            );
          },
        ),

        /// ✅ 动画标题
        Positioned(
          top: MediaQuery.of(context).size.height * 0.12,
          left: 0,
          right: 0,
          child: Center(
            child: widget.enableAnimation
                ? ScaleTransition(
                    scale: _groupScale, // 整体收尾动效
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        _title.length,
                        (index) => AnimatedBuilder(
                          animation: _animations[index],
                          builder: (_, __) {
                            final value = _animations[index].value;

                            return Opacity(
                              opacity: value.clamp(0.0, 1.0),
                              child: Transform.translate(
                                offset: Offset((1 - value) * -18, 0), // 小幅滑入
                                child: Transform.scale(
                                  scale: 0.85 + value * 0.15, // 缩放动效
                                  child: Text(
                                    _title[index],
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                      //fontFamily: 'JetBrainsMono',
                                      fontSize: 80,
                                      //fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      //letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      _title.length,
                      (index) => Text(
                        _title[index],
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          //fontFamily: 'JetBrainsMono',
                          fontSize: 80,
                          //fontWeight: FontWeight.bold,
                          color: Colors.white,
                          //letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
          ),
        ),

        /// ✅ 内容层（登录卡片等）
        widget.child,
      ],
    );
  }
}
