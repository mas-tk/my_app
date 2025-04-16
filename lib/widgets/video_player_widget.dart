// lib/widgets/video_player_widget.dart
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class AnimatedVideoPlayer extends StatefulWidget {
  final String videoPath;
  final bool autoPlay;
  final bool loop;
  final BoxFit fit;
  final double width;
  final double height;

  const AnimatedVideoPlayer({
    Key? key,
    required this.videoPath,
    this.autoPlay = true,
    this.loop = true,
    this.fit = BoxFit.contain,
    this.width = double.infinity,
    this.height = double.infinity,
  }) : super(key: key);

  @override
  State<AnimatedVideoPlayer> createState() => _AnimatedVideoPlayerState();
}

class _AnimatedVideoPlayerState extends State<AnimatedVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideoController();
  }

  Future<void> _initializeVideoController() async {
    _controller = VideoPlayerController.asset(widget.videoPath);

    await _controller.initialize();

    if (widget.loop) {
      _controller.setLooping(true);
    }

    if (widget.autoPlay) {
      _controller.play();
    }

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: FittedBox(
        fit: widget.fit,
        child: SizedBox(
          width: _controller.value.size.width,
          height: _controller.value.size.height,
          child: VideoPlayer(_controller),
        ),
      ),
    );
  }
}
