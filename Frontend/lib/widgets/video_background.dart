import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:video_player/video_player.dart';

/// 视频背景组件
/// 播放视频，结束后显示最后一帧作为静态背景
class VideoBackground extends StatefulWidget {
  final Widget child;
  final String videoPath;

  const VideoBackground({
    Key? key,
    required this.child,
    required this.videoPath,
  }) : super(key: key);

  @override
  State<VideoBackground> createState() => _VideoBackgroundState();
}

class _VideoBackgroundState extends State<VideoBackground> {
  VideoPlayerController? _controller;
  bool _isVideoFinished = false;
  bool _isInitialized = false;
  bool _needsUserInteraction = false; // 是否需要用户交互才能播放
  bool _videoLoadFailed = false; // 视频加载是否失败
  Size _cachedVideoSize = Size.zero; // 缓存视频尺寸，防止 Web 平台状态重置

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    if (kIsWeb) {
      // Web 平台：尝试多个可能的路径
      final videoFileName = widget.videoPath.split('/').last; // 提取文件名，如 "Title_07.mp4"
      final possiblePaths = [
        '/assets/$videoFileName',                 // Flutter 构建后的标准路径
        '/assets/assets/$videoFileName',          // 某些部署下会复制到 assets/assets
        '/$videoFileName',                        // 如果文件在 web 根目录
        widget.videoPath.startsWith('assets/')
            ? '/${widget.videoPath}'              // 完整路径
            : widget.videoPath,
      ];
      
      VideoPlayerController? tempController;
      Exception? lastError;
      
      // 尝试每个路径
      for (final path in possiblePaths) {
        try {
          print('Web 平台尝试加载视频: $path');
          tempController = VideoPlayerController.networkUrl(Uri.parse(path));
          await tempController.initialize();
          
          // 成功加载
          print('视频加载成功，路径: $path，时长: ${tempController.value.duration}');
          print('视频尺寸: ${tempController.value.size}');
          print('视频是否已初始化: ${tempController.value.isInitialized}');
          _controller = tempController;
          
          // 立即缓存视频尺寸（Web 平台 play() 后可能状态会重置）
          _cachedVideoSize = tempController.value.size;
          
          // Web 平台：初始化成功后立即设置状态
          if (mounted) {
            setState(() {
              _isInitialized = true;
            });
          }
          break;
        } catch (e) {
          print('路径 $path 加载失败: $e');
          tempController?.dispose();
          tempController = null;
          lastError = e is Exception ? e : Exception(e.toString());
        }
      }
      
      if (_controller == null) {
        print('所有路径都失败，最后一个错误: $lastError');
        print('视频加载失败，将使用渐变背景作为后备方案');
        // 视频加载失败，使用渐变背景作为后备方案
        if (mounted) {
          setState(() {
            _videoLoadFailed = true;
            _isInitialized = true; // 标记为已初始化，显示后备背景
          });
        }
        return; // 不抛出异常，优雅降级
      }
    } else {
      // 移动端平台：使用 asset
      print('移动端平台加载视频: ${widget.videoPath}');
      _controller = VideoPlayerController.asset(widget.videoPath);
      await _controller!.initialize();
      print('视频初始化成功，时长: ${_controller!.value.duration}');
      print('视频尺寸: ${_controller!.value.size}');
      
      // 缓存视频尺寸
      _cachedVideoSize = _controller!.value.size;
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }
    
    // 确保控制器存在
    if (_controller == null) {
      print('错误：控制器为 null');
      if (mounted) {
        setState(() {
          _isInitialized = true; // 显示黑色背景
        });
      }
      return;
    }
    
    try {
      // 监听视频播放完成和状态变化
      _controller!.addListener(_videoListener);
      _controller!.addListener(_onVideoStateChanged);
      
      // 设置循环播放为 false，确保播放完成后停在最后一帧
      await _controller!.setLooping(false);
      
      // Web 平台：先设置静音，这样可以绕过浏览器的自动播放限制
      if (kIsWeb) {
        try {
          await _controller!.setVolume(0.0); // 静音
          print('视频已设置为静音');
        } catch (e) {
          print('设置静音失败: $e');
        }
      }
      
      // 开始播放
      await _controller!.play();
      
      print('视频开始播放，当前状态: isPlaying=${_controller!.value.isPlaying}');
      print('视频尺寸: ${_controller!.value.size}');
      print('视频是否已初始化: ${_controller!.value.isInitialized}');
      
      // Web 平台：等待并检查播放状态
      if (kIsWeb) {
        // 等待视频真正开始播放
        bool isPlaying = false;
        for (int i = 0; i < 10; i++) {
          await Future.delayed(const Duration(milliseconds: 100));
          isPlaying = _controller!.value.isPlaying;
          if (isPlaying) {
            print('视频已开始播放（尝试 ${i + 1} 次后）');
            break;
          }
          // 如果仍未播放，再次尝试
          if (i < 9 && !isPlaying) {
            print('视频未播放，重试播放（第 ${i + 1} 次）');
            await _controller!.play();
          }
        }
        
        // 如果仍未播放，标记需要用户交互
        if (!isPlaying) {
          print('警告：视频可能因浏览器自动播放限制而未播放，需要用户交互');
          if (mounted) {
            setState(() {
              _needsUserInteraction = true;
            });
          }
        }
      }
      
      // 如果播放后尺寸丢失，使用缓存的尺寸
      if (_controller!.value.size.width == 0 && _cachedVideoSize.width > 0) {
        print('检测到尺寸丢失，使用缓存尺寸: $_cachedVideoSize');
      }
      
      // 强制刷新 UI
      if (mounted) {
        setState(() {
          // 触发重建
        });
      }
    } catch (e, stackTrace) {
      print('视频播放设置失败: $e');
      print('堆栈: $stackTrace');
      // 即使播放设置失败，也显示视频（可能已经初始化成功）
      if (mounted) {
        setState(() {
          _needsUserInteraction = true;
        });
      }
    }
  }

  void _videoListener() {
    if (_controller != null && _controller!.value.position >= _controller!.value.duration) {
      // 视频播放完成，暂停并显示最后一帧
      _controller!.pause();
      if (mounted) {
        setState(() {
          _isVideoFinished = true;
        });
      }
    }
  }
  
  void _onVideoStateChanged() {
    // 监听视频状态变化，确保 UI 更新
    if (_controller != null && mounted) {
      // 如果视频尺寸恢复，更新缓存
      if (_controller!.value.size.width > 0 && _controller!.value.size.height > 0) {
        _cachedVideoSize = _controller!.value.size;
        setState(() {
          // 触发重建以显示视频
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_videoListener);
    _controller?.removeListener(_onVideoStateChanged);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _tryPlayOnUserInteraction() async {
    if (_controller != null && !_controller!.value.isPlaying) {
      try {
        await _controller!.play();
        if (mounted) {
          setState(() {
            _needsUserInteraction = false;
          });
        }
      } catch (e) {
        print('用户交互后播放失败: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      // 视频加载中，显示黑色背景
      return Container(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    // 调试信息与尺寸获取
    final isControllerInitialized = _controller != null && _controller!.value.isInitialized;
    // 优先使用控制器当前尺寸，如果为 0 则使用缓存尺寸
    final currentSize = _controller?.value.size ?? Size.zero;
    final videoSize = currentSize.width > 0 && currentSize.height > 0 
        ? currentSize 
        : _cachedVideoSize;
    final screenWidth = MediaQuery.of(context).size.width;
    final bool hasVideoSize = videoSize.width > 0 && videoSize.height > 0;
    final bool showHalfCenter = hasVideoSize && screenWidth < (videoSize.width * 0.5);
    final boxFit = showHalfCenter ? BoxFit.cover : BoxFit.cover;
    const fallbackBgColor = Color(0xFF090C26);
    
    // 只在开发模式下打印调试信息，避免控制台刷屏
    if (kDebugMode) {
      print('build: isInitialized=$_isInitialized, controller!=null=${_controller != null}, '
            'controller.isInitialized=$isControllerInitialized, currentSize=$currentSize, cachedSize=$_cachedVideoSize, usingSize=$videoSize, needsInteraction=$_needsUserInteraction');
    }

    return GestureDetector(
      // 如果视频需要用户交互，点击页面任意位置后播放
      onTap: _needsUserInteraction ? _tryPlayOnUserInteraction : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 视频背景（播放中或最后一帧）
          if (_videoLoadFailed)
            // 视频加载失败，显示优雅的渐变背景
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1E3A8A), // 深蓝色
                      Color(0xFF3B82F6), // 蓝色
                      Color(0xFF60A5FA), // 浅蓝色
                    ],
                  ),
                ),
              ),
            )
          else if (_controller != null && videoSize.width > 0 && videoSize.height > 0)
            // Web 平台：即使控制器状态显示未初始化，只要有控制器和缓存尺寸就显示
            Positioned.fill(
              child: showHalfCenter
                  // 窄屏：仅展示视频中间二分之一（水平裁剪），高度全显示；其余区域用深色填充
                  ? Container(
                      color: fallbackBgColor,
                      alignment: Alignment.center,
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: videoSize.width,
                          height: videoSize.height,
                          child: ClipRect(
                            child: Align(
                              alignment: Alignment.center,
                              widthFactor: 0.5, // 只保留中间 1/2 宽度
                              child: VideoPlayer(_controller!),
                            ),
                          ),
                        ),
                      ),
                    )
                  // 常规：全幅铺满
                  : FittedBox(
                      fit: boxFit,
                      child: SizedBox(
                        width: videoSize.width,
                        height: videoSize.height,
                        child: VideoPlayer(_controller!),
                      ),
                    ),
            )
          else if (_controller != null)
            // 如果控制器存在但没有尺寸，尝试直接显示（Web 平台可能需要）
            Positioned.fill(
              child: VideoPlayer(_controller!),
            )
          else
            // 如果控制器不存在，显示渐变背景
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1E3A8A), // 深蓝色
                    Color(0xFF3B82F6), // 蓝色
                    Color(0xFF60A5FA), // 浅蓝色
                  ],
                ),
              ),
            ),

          // 如果需要用户交互，显示提示（可选）
          if (_needsUserInteraction && kIsWeb)
            Positioned(
              top: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '点击任意位置播放视频',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),

          // 子组件（登录/注册卡片）
          widget.child,
        ],
      ),
    );
  }
}

