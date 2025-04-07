// lib/widgets/page_turn_animation.dart
import 'package:flutter/material.dart';
import 'dart:math';

/// ページめくりの方向を定義
enum PageTurnDirection { rightToLeft, leftToRight }

/// リアルなページめくりアニメーションを提供するウィジェット
class RealisticPageTurn extends StatelessWidget {
  /// アニメーションの進行度（0.0〜1.0）
  final Animation<double> animation;

  /// ページめくりの方向
  final PageTurnDirection direction;

  /// 現在のページのウィジェット
  final Widget currentPage;

  /// めくった先のページのウィジェット
  final Widget nextPage;

  /// ページめくりアニメーション時間
  final Duration duration;

  const RealisticPageTurn({
    Key? key,
    required this.animation,
    required this.direction,
    required this.currentPage,
    required this.nextPage,
    this.duration = const Duration(milliseconds: 500),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Stack(
          children: [
            // 常に背景にめくった後のページを配置
            Positioned.fill(
              child:
                  direction == PageTurnDirection.rightToLeft
                      ? nextPage
                      : currentPage,
            ),

            // めくられる途中のページ
            ClipPath(
              clipper: PageTurnClipper(
                progress: animation.value,
                direction: direction,
              ),
              child: Positioned.fill(
                child:
                    direction == PageTurnDirection.rightToLeft
                        ? currentPage
                        : nextPage,
              ),
            ),

            // ページの影効果
            if (animation.value > 0.0 && animation.value < 1.0)
              CustomPaint(
                size: Size.infinite,
                painter: ShadowPainter(
                  progress: animation.value,
                  direction: direction,
                ),
              ),
          ],
        );
      },
    );
  }
}

// ページクリッパー - めくれる部分を定義
class PageTurnClipper extends CustomClipper<Path> {
  final double progress;
  final PageTurnDirection direction;

  PageTurnClipper({required this.progress, required this.direction});

  @override
  Path getClip(Size size) {
    final path = Path();

    if (direction == PageTurnDirection.rightToLeft) {
      // 右から左へページをめくる場合
      final double x = size.width * (1.0 - progress);

      path.moveTo(0, 0);
      path.lineTo(x, 0);

      // ページの曲線部分（より自然な曲がり方に）
      for (int i = 0; i <= 100; i++) {
        final double y = size.height * (i / 100);
        final double factor = (1 - i / 100); // 上部ほど大きく、下部ほど小さくカーブ
        final double dx = 20.0 * sin(pi * i / 200) * progress * factor;
        path.lineTo(x - dx, y);
      }

      path.lineTo(0, size.height);
      path.close();

      return path;
    } else {
      // 左から右へページをめくる場合
      final double x = size.width * progress;

      path.moveTo(size.width, 0);
      path.lineTo(x, 0);

      // ページの曲線部分
      for (int i = 0; i <= 100; i++) {
        final double y = size.height * (i / 100);
        final double factor = (1 - i / 100); // 上部ほど大きく、下部ほど小さくカーブ
        final double dx = 20.0 * sin(pi * i / 200) * (1.0 - progress) * factor;
        path.lineTo(x + dx, y);
      }

      path.lineTo(size.width, size.height);
      path.close();

      return path;
    }
  }

  @override
  bool shouldReclip(PageTurnClipper oldClipper) {
    return oldClipper.progress != progress || oldClipper.direction != direction;
  }
}

// ページの影を描画
class ShadowPainter extends CustomPainter {
  final double progress;
  final PageTurnDirection direction;

  ShadowPainter({required this.progress, required this.direction});

  @override
  void paint(Canvas canvas, Size size) {
    // 影の色とぼかし効果を定義
    final shadowPaint =
        Paint()
          ..color = Colors.black.withOpacity(0.4)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.0);

    // 折り目の光沢効果用
    final highlightPaint =
        Paint()
          ..color = Colors.white.withOpacity(0.3)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

    final Path shadowPath = Path();
    final Path highlightPath = Path();

    if (direction == PageTurnDirection.rightToLeft) {
      // 右から左へめくる場合の影
      final double x = size.width * (1.0 - progress);
      final double shadowWidth = 15.0 * progress;

      shadowPath.moveTo(x, 0);

      // 影の曲線
      for (int i = 0; i <= 100; i++) {
        final double y = size.height * (i / 100);
        final double factor = (1 - i / 100);
        final double dx = 20.0 * sin(pi * i / 200) * progress * factor;
        shadowPath.lineTo(x - dx - shadowWidth * factor, y);
      }

      // 折り目のハイライト
      highlightPath.moveTo(x, 0);

      for (int i = 0; i <= 100; i++) {
        final double y = size.height * (i / 100);
        final double factor = (1 - i / 100);
        final double dx = 20.0 * sin(pi * i / 200) * progress * factor;
        highlightPath.lineTo(x - dx + 1.0, y);
      }

      canvas.drawPath(shadowPath, shadowPaint);
      canvas.drawPath(highlightPath, highlightPaint);
    } else {
      // 左から右へめくる場合の影
      final double x = size.width * progress;
      final double shadowWidth = 15.0 * (1 - progress);

      shadowPath.moveTo(x, 0);

      // 影の曲線
      for (int i = 0; i <= 100; i++) {
        final double y = size.height * (i / 100);
        final double factor = (1 - i / 100);
        final double dx = 20.0 * sin(pi * i / 200) * (1.0 - progress) * factor;
        shadowPath.lineTo(x + dx + shadowWidth * factor, y);
      }

      // 折り目のハイライト
      highlightPath.moveTo(x, 0);

      for (int i = 0; i <= 100; i++) {
        final double y = size.height * (i / 100);
        final double factor = (1 - i / 100);
        final double dx = 20.0 * sin(pi * i / 200) * (1.0 - progress) * factor;
        highlightPath.lineTo(x + dx - 1.0, y);
      }

      canvas.drawPath(shadowPath, shadowPaint);
      canvas.drawPath(highlightPath, highlightPaint);
    }
  }

  @override
  bool shouldRepaint(ShadowPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.direction != direction;
  }
}
