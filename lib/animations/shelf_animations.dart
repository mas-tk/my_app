// lib/animations/shelf_animations.dart
// 棚登りなどの複雑なアニメーションを扱うためのコード

import 'package:flutter/material.dart';
import '../models/animated_object_models.dart';
import '../widgets/simple_gif_player.dart';
import 'dart:math' as math; // Math を math に修正

class ShelfAnimationPlayer extends StatefulWidget {
  final AnimatedObjectInfo animInfo;
  final Size initialSize;
  final Offset initialPosition;
  final ObjectAnimationBehavior
  behavior; // AnimationBehavior を ObjectAnimationBehavior に変更
  final VoidCallback onAnimationComplete;

  const ShelfAnimationPlayer({
    Key? key,
    required this.animInfo,
    required this.initialSize,
    required this.initialPosition,
    required this.behavior,
    required this.onAnimationComplete,
  }) : super(key: key);

  @override
  State<ShelfAnimationPlayer> createState() => _ShelfAnimationPlayerState();
}

class _ShelfAnimationPlayerState extends State<ShelfAnimationPlayer>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _positionAnimation;
  late Animation<double> _scaleAnimation;

  // 画面サイズ
  late double _screenWidth;
  late double _screenHeight;

  @override
  void initState() {
    super.initState();

    // アニメーションコントローラー
    _controller = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    );

    // アニメーション完了のリスナー
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onAnimationComplete();
      }
    });

    // ビルド後に画面サイズを取得してアニメーションをセットアップ
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _screenWidth = MediaQuery.of(context).size.width;
      _screenHeight = MediaQuery.of(context).size.height;
      _setupAnimations();
      _controller.forward();
    });
  }

  void _setupAnimations() {
    switch (widget.behavior) {
      case ObjectAnimationBehavior
          .inPlace: // AnimationBehavior を ObjectAnimationBehavior に変更
        _setupInPlaceAnimation();
        break;

      case ObjectAnimationBehavior
          .expand: // AnimationBehavior を ObjectAnimationBehavior に変更
        _setupExpandAnimation();
        break;

      case ObjectAnimationBehavior
          .walkAround: // AnimationBehavior を ObjectAnimationBehavior に変更
        _setupWalkAroundAnimation();
        break;

      case ObjectAnimationBehavior
          .climbShelf: // AnimationBehavior を ObjectAnimationBehavior に変更
        _setupClimbShelfAnimation();
        break;
    }
  }

  void _setupInPlaceAnimation() {
    // その場でのアニメーション - 微かに拍動するエフェクト
    _positionAnimation = Tween<Offset>(
      begin: Offset(widget.initialPosition.dx, widget.initialPosition.dy),
      end: Offset(widget.initialPosition.dx, widget.initialPosition.dy),
    ).animate(_controller);

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.1), weight: 25),
      TweenSequenceItem(tween: Tween<double>(begin: 1.1, end: 1.0), weight: 25),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.1), weight: 25),
      TweenSequenceItem(tween: Tween<double>(begin: 1.1, end: 1.0), weight: 25),
    ]).animate(_controller);
  }

  void _setupExpandAnimation() {
    // 拡大アニメーション
    _positionAnimation = Tween<Offset>(
      begin: Offset(widget.initialPosition.dx, widget.initialPosition.dy),
      end: Offset(widget.initialPosition.dx, widget.initialPosition.dy),
    ).animate(_controller);

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: widget.animInfo.expandRatio),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: widget.animInfo.expandRatio,
          end: widget.animInfo.expandRatio,
        ),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: widget.animInfo.expandRatio, end: 1.0),
        weight: 40,
      ),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  void _setupWalkAroundAnimation() {
    // 周囲を移動するアニメーション - 円を描くような動き
    final List<Offset> path = [];

    // 始点位置
    final double centerX = widget.initialPosition.dx;
    final double centerY = widget.initialPosition.dy;
    const double radius = 100.0;

    // 円を描くポイントを生成
    const int numPoints = 100;
    for (int i = 0; i < numPoints; i++) {
      final double angle = 2 * math.pi * i / numPoints; // Math.piをmath.piに修正
      path.add(
        Offset(
          centerX + radius * math.cos(angle), // Math.cos を math.cos に修正
          centerY + radius * math.sin(angle), // Math.sin を math.sin に修正
        ),
      );
    }

    // パスアニメーション
    _positionAnimation = TweenSequence<Offset>(
      List.generate(path.length - 1, (index) {
        return TweenSequenceItem(
          tween: Tween<Offset>(begin: path[index], end: path[index + 1]),
          weight: 1,
        );
      }),
    ).animate(_controller);

    // スケールアニメーション（一定）
    _scaleAnimation = Tween<double>(
      begin: widget.animInfo.expandRatio,
      end: widget.animInfo.expandRatio,
    ).animate(_controller);
  }

  void _setupClimbShelfAnimation() {
    // 棚登りアニメーション（より複雑な動きのシーケンス）

    // 始点
    final double startX = widget.initialPosition.dx;
    final double startY = widget.initialPosition.dy;

    // 上の棚まで登る
    final double midX = startX;
    final double midY = startY - 200; // 上に移動

    // 棚上を水平移動
    final double endX = startX + 150; // 右に移動
    final double endY = midY;

    // 点のシーケンスを作成
    _positionAnimation = TweenSequence<Offset>([
      // 最初に上昇（登る）
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: Offset(startX, startY),
          end: Offset(midX, midY),
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      // 次に水平移動
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: Offset(midX, midY),
          end: Offset(endX, endY),
        ).chain(CurveTween(curve: Curves.linear)),
        weight: 30,
      ),
      // 少し戻る
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: Offset(endX, endY),
          end: Offset(endX - 50, endY),
        ).chain(CurveTween(curve: Curves.linear)),
        weight: 30,
      ),
    ]).animate(_controller);

    // スケールアニメーション（一定）
    _scaleAnimation = Tween<double>(
      begin: widget.animInfo.expandRatio,
      end: widget.animInfo.expandRatio,
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // 現在の位置とスケールを取得
        final Offset currentPosition = _positionAnimation.value;
        final double currentScale = _scaleAnimation.value;

        // スケールに基づくサイズを計算
        final double width = widget.initialSize.width * currentScale;
        final double height = widget.initialSize.height * currentScale;

        // 位置（中心点とスケールを考慮）
        final double left = currentPosition.dx - (width / 2);
        final double top = currentPosition.dy - (height / 2);

        return Positioned(
          left: left,
          top: top,
          width: width,
          height: height,
          child: getAnimatedAssetWidget(),
        );
      },
    );
  }

  Widget getAnimatedAssetWidget() {
    switch (widget.animInfo.animationType) {
      case AnimationType.gif:
        return GifPlayer(
          gifPath: widget.animInfo.animatedAssetPath,
          fit: BoxFit.contain,
          duration: const Duration(milliseconds: 1000),
        );

      case AnimationType.video:
        // ビデオプレーヤーのプレースホルダー
        return Container(
          color: Colors.transparent,
          child: Center(child: Text('Video: ${widget.animInfo.name}')),
        );

      case AnimationType.lottie:
        // Lottieアニメーションのプレースホルダー
        return Container(
          color: Colors.transparent,
          child: Center(child: Text('Lottie: ${widget.animInfo.name}')),
        );
    }
  }
}
