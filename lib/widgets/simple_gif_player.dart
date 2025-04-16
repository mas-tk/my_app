// lib/widgets/simple_gif_player.dart
import 'package:flutter/material.dart';
import 'dart:async';

class SimpleGifPlayer extends StatefulWidget {
  final String gifPath;
  final BoxFit fit;
  final double width;
  final double height;
  final bool autoPlay;
  final bool loop;
  final Duration duration;
  final VoidCallback? onAnimationComplete;

  const SimpleGifPlayer({
    Key? key,
    required this.gifPath,
    this.fit = BoxFit.contain,
    this.width = double.infinity,
    this.height = double.infinity,
    this.autoPlay = true,
    this.loop = true,
    this.duration = const Duration(seconds: 2),
    this.onAnimationComplete,
  }) : super(key: key);

  @override
  State<SimpleGifPlayer> createState() => _SimpleGifPlayerState();
}

class _SimpleGifPlayerState extends State<SimpleGifPlayer> {
  bool _isPlaying = false;
  Timer? _animationTimer;

  @override
  void initState() {
    super.initState();

    if (widget.autoPlay) {
      _startPlaying();
    }
  }

  void _startPlaying() {
    setState(() {
      _isPlaying = true;
    });

    // 非ループモードの場合、指定した時間後にアニメーションを終了
    if (!widget.loop) {
      _animationTimer = Timer(widget.duration, () {
        if (mounted) {
          setState(() {
            _isPlaying = false;
          });

          if (widget.onAnimationComplete != null) {
            widget.onAnimationComplete!();
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child:
          _isPlaying
              ? Image.asset(
                widget.gifPath,
                fit: widget.fit,
                width: widget.width,
                height: widget.height,
                gaplessPlayback: true,
                cacheWidth: widget.width.toInt(),
                cacheHeight: widget.height.toInt(),
              )
              : const SizedBox(),
    );
  }
}
