import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoMessagePlayer extends StatefulWidget {
  final String videoUrl;
  final bool isMe;

  const VideoMessagePlayer({
    Key? key,
    required this.videoUrl,
    required this.isMe,
  }) : super(key: key);

  @override
  State<VideoMessagePlayer> createState() => _VideoMessagePlayerState();
}

class _VideoMessagePlayerState extends State<VideoMessagePlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _controller.initialize();
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        width: 250,
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red),
              SizedBox(height: 8),
              Text('视频加载失败'),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return Container(
        width: 250,
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return GestureDetector(
      onTap: _togglePlayPause,
      child: Container(
        width: 250,
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.black,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
              if (!_controller.value.isPlaying)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(16),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
