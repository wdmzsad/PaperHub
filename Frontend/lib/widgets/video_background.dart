import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:video_player/video_player.dart';

/// 视频背景组件：
/// - 自动播放
/// - 播完停在最后一帧
/// - Web 自动静音绕过 autoplay 限制
/// - 失败自动显示渐变背景
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
  bool _isInitialized = false;
  bool _needsUserInteraction = false;
  bool _videoLoadFailed = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      if (kIsWeb) {
        final videoFileName = widget.videoPath.split('/').last;
        final possiblePaths = [
          '/assets/$videoFileName',
          '/assets/assets/$videoFileName',
          '/$videoFileName',
          widget.videoPath.startsWith('assets/')
              ? '/${widget.videoPath}'
              : widget.videoPath,
        ];

        for (final path in possiblePaths) {
          try {
            _controller = VideoPlayerController.networkUrl(Uri.parse(path));
            await _controller!.initialize();
            break;
          } catch (_) {
            _controller?.dispose();
            _controller = null;
          }
        }

        if (_controller == null) {
          setState(() {
            _videoLoadFailed = true;
            _isInitialized = true;
          });
          return;
        }

        await _controller!.setVolume(0); // Web 必须静音
      } else {
        _controller = VideoPlayerController.asset(widget.videoPath);
        await _controller!.initialize();
      }

      _controller!.setLooping(false);

      _controller!.addListener(() {
        if (_controller!.value.position >= _controller!.value.duration) {
          _controller!.pause();
        }
      });

      await _controller!.play();

      if (kIsWeb) {
        bool played = false;
        for (int i = 0; i < 10; i++) {
          await Future.delayed(const Duration(milliseconds: 100));
          if (_controller!.value.isPlaying) {
            played = true;
            break;
          }
          await _controller!.play();
        }

        if (!played) {
          setState(() {
            _needsUserInteraction = true;
          });
        }
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('视频加载失败: $e');
      }
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _videoLoadFailed = true;
        });
      }
    }
  }

  Future<void> _tryPlayOnUserInteraction() async {
    if (_controller != null && !_controller!.value.isPlaying) {
      await _controller!.play();
      setState(() {
        _needsUserInteraction = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return GestureDetector(
      onTap: _needsUserInteraction ? _tryPlayOnUserInteraction : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 视频或渐变背景
          if (_videoLoadFailed)
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF1E3A8A),
                    Color(0xFF3B82F6),
                    Color(0xFF60A5FA),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            )
          else if (_controller != null && _controller!.value.isInitialized)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.size.width,
                height: _controller!.value.size.height,
                child: VideoPlayer(_controller!),
              ),
            )
          else
            const SizedBox(),

          // Web 用户点击提示
          if (_needsUserInteraction && kIsWeb)
            Positioned(
              top: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '点击任意位置播放视频',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),

          // 内容层
          widget.child,
        ],
      ),
    );
  }
}
