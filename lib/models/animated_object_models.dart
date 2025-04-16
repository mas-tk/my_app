// lib/models/animated_object_models.dart
import 'package:flutter/material.dart';

class AnimatedObjectInfo {
  final String objectId;
  final String name;
  final String staticImagePath;
  final String animatedAssetPath; // GIFまたは動画のパス
  final AnimationType animationType;
  final ObjectAnimationBehavior
  behavior; // AnimationBehavior を ObjectAnimationBehavior に変更
  final double expandRatio; // 1.0は同じサイズ、2.0は2倍サイズ、など

  AnimatedObjectInfo({
    required this.objectId,
    required this.name,
    required this.staticImagePath,
    required this.animatedAssetPath,
    this.animationType = AnimationType.gif,
    this.behavior =
        ObjectAnimationBehavior
            .inPlace, // AnimationBehavior を ObjectAnimationBehavior に変更
    this.expandRatio = 1.0,
  });
}

enum AnimationType {
  gif, // GIFアニメーション
  video, // 動画
  lottie, // Lottieアニメーション
}

// AnimationBehavior を ObjectAnimationBehavior に名称変更 (Flutterの名前衝突回避)
enum ObjectAnimationBehavior {
  inPlace, // オリジナルの境界内でアニメーション
  expand, // オリジナルの境界を超えて拡大
  walkAround, // 画面上を移動
  climbShelf, // 棚を登るための特別な動作
}
