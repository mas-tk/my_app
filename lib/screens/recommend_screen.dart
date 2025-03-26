// ---- recommend_screen.dart ----

import 'package:flutter/material.dart';

class RecommendScreen extends StatelessWidget {
  const RecommendScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // バナー画像のサンプルパス
    final coverPaths = [
      'assets/bookcovers/cover1.png',
      'assets/bookcovers/cover2.png',
      'assets/bookcovers/cover3.png',
    ];

    return Scaffold(
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          // 下向きスワイプを検出してホーム画面に戻る
          if (details.velocity.pixelsPerSecond.dy > 0) {
            Navigator.pop(context);
          }
        },
        child: Column(
          children: [
            // ヘッダー部分
            Container(
              color: const Color(0xFF388E3C),
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // 閉じるボタン
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Image.asset(
                      'assets/down_arrow.png',
                      width: 24,
                      height: 24,
                    ),
                  ),
                ],
              ),
            ),

            // バナーリスト
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildBanner(
                    '今月のおすすめ',
                    coverPaths[0],
                    const Color(0xFFE0F7E0),
                  ),
                  _buildBanner('特集', coverPaths[1], Colors.white),
                  _buildBanner('キャンペーン', coverPaths[2], Colors.white),
                  _buildBanner('新作紹介', coverPaths[1], const Color(0xFFF0F0FF)),
                  _buildBanner(
                    '人気ランキング',
                    coverPaths[2],
                    const Color(0xFFFFF0F0),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // バナーアイテムウィジェット
  Widget _buildBanner(String title, String imagePath, Color bgColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDDDDD)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => print('Banner clicked: $title'),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Image.asset(
                  imagePath,
                  width: 60,
                  height: 80,
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
