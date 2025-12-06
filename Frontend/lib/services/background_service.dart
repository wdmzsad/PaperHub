import 'dart:math';

/// 背景图片管理服务
/// - 在应用启动时随机选择一张背景图
/// - 在页面切换时保持同一张背景图
class BackgroundService {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  BackgroundService._internal();

  static const List<String> _backgroundPaths = [
    'assets/images/bg1.png',
    'assets/images/bg2.png',
    'assets/images/bg3.png',
    'assets/images/bg4.png',
    'assets/images/bg5.png',
    'assets/images/bg6.png',
    'assets/images/bg7.png',
    'assets/images/bg8.png',
    'assets/images/bg9.png', 
    'assets/images/bg10.png',
    'assets/images/bg11.png',
    'assets/images/bg12.png',
    'assets/images/bg13.png',   
  ];

  String? _currentBackground;

  /// 获取当前背景图片路径
  /// 如果是第一次调用，随机选择一张；否则返回已选择的背景
  String getCurrentBackground() {
    if (_currentBackground == null) {
      final random = Random();
      _currentBackground = _backgroundPaths[random.nextInt(_backgroundPaths.length)];
    }
    return _currentBackground!;
  }

  /// 重置背景（用于刷新页面时重新随机选择）
  void resetBackground() {
    _currentBackground = null;
  }
}

