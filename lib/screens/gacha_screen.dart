// lib/screens/gacha_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/object_models.dart';
import '../models/gacha_models.dart';
import '../repositories/object_repository.dart';
import '../repositories/gacha_repository.dart';
import '../repositories/coin_repository.dart';
import 'favorites_screen.dart'; // FavoritesScreenをインポート

class GachaScreen extends StatefulWidget {
  final String gachaTypeId;

  const GachaScreen({Key? key, required this.gachaTypeId}) : super(key: key);

  @override
  _GachaScreenState createState() => _GachaScreenState();
}

class _GachaScreenState extends State<GachaScreen>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _dropController;
  late AnimationController _glowController; // 光るエフェクト用のコントローラー
  late Animation<double> _rotationAnimation;
  late Animation<double> _dropAnimation;
  late Animation<double> _glowAnimation; // 光るエフェクト用のアニメーション

  bool _isGachaPlaying = false;
  bool _showResult = false;
  DecorationObject? _gachaResult;
  GachaType? _gachaType;

  final ObjectRepository _objectRepository = ObjectRepository();
  final GachaRepository _gachaRepository = GachaRepository();
  final CoinRepository _coinRepository = CoinRepository();

  // スワイプの開始位置と現在位置
  double _dragStartX = 0;
  double _currentDragX = 0;

  // ガチャを引けるかどうか
  bool _canPlayGacha = true;

  // コイン残高
  int _coinBalance = 0;

  @override
  void initState() {
    super.initState();

    // アニメーションコントローラ初期化
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _dropController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // 光るエフェクト用のコントローラー
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _rotationAnimation = CurvedAnimation(
      parent: _rotationController,
      curve: Curves.easeInOut,
    );

    _dropAnimation = CurvedAnimation(
      parent: _dropController,
      curve: Curves.bounceOut,
    );

    // 光るエフェクト用のアニメーション
    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // アニメーション完了時のリセット
    _rotationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // 一旦戻してリセット
        _rotationController.reset();
      }
    });

    _dropController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // ドロップアニメーションが完了したらリセット
        _dropController.reset();
      }
    });

    // 光るエフェクトは繰り返し実行
    _glowController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _glowController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _glowController.forward();
      }
    });

    // ガチャタイプとコイン残高の読み込み
    _loadInitialData();
  }

  // ガチャタイプとコイン残高を読み込む
  Future<void> _loadInitialData() async {
    try {
      // ガチャタイプの読み込み
      final gachaType = await _gachaRepository.getGachaTypeById(
        widget.gachaTypeId,
      );

      // コイン残高の読み込み
      final coinBalance = await _coinRepository.getBalance();

      if (mounted) {
        setState(() {
          _gachaType = gachaType;
          _coinBalance = coinBalance.balance;
        });
      }
    } catch (e) {
      print('Error loading initial data: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('データの読み込みに失敗しました: $e')));
      }
    }
  }

  void _playGacha() async {
    if (_isGachaPlaying || _gachaType == null || !_canPlayGacha) {
      return;
    }

    setState(() {
      _isGachaPlaying = true;
      _showResult = false;
      _canPlayGacha = false; // ガチャプレイ中は再度引けないようにする
    });

    // コインを消費
    final success = await _coinRepository.spendCoins(
      _gachaType!.cost,
      '${_gachaType!.name}を引く',
    );

    if (!success) {
      // コイン消費に失敗した場合
      setState(() {
        _isGachaPlaying = false;
        _canPlayGacha = true;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('コインが足りません')));
      return;
    }

    // コイン残高を更新
    final coinBalance = await _coinRepository.getBalance();
    setState(() {
      _coinBalance = coinBalance.balance;
    });

    // バイブレーション
    try {
      HapticFeedback.mediumImpact();
    } catch (e) {
      print('Failed to generate haptic feedback: $e');
    }

    // ガチャノブを回すアニメーション
    _rotationController.forward().then((_) async {
      // ガチャを引く
      final result = await _gachaRepository.pullGacha(_gachaType!.id);

      if (result == null) {
        // ガチャ失敗時
        setState(() {
          _isGachaPlaying = false;
          _canPlayGacha = true;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ガチャの実行に失敗しました')));
        return;
      }

      setState(() {
        _gachaResult = result;
      });

      // 玉が落ちるアニメーション
      _dropController.forward().then((_) {
        setState(() {
          _showResult = true;
          _isGachaPlaying = false;
        });

        // 光るエフェクトを開始
        _glowController.forward();
      });
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _dropController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  // マイアイテム画面に遷移するメソッド
  void _navigateToMyItems() async {
    // オブジェクトの状態を購入済みに変更
    if (_gachaResult != null && !_gachaResult!.isPurchased) {
      await _objectRepository.purchaseObject(_gachaResult!.id);
    }

    // マイアイテム画面に直接遷移（FavoritesScreen）
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const FavoritesScreen()));
  }

  // 獲得したアイテムのオーバーレイを構築
  Widget _buildResultOverlay() {
    if (!_showResult || _gachaResult == null) return const SizedBox.shrink();

    return GestureDetector(
      // 背景タップで戻る機能を追加
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        color: Colors.black.withOpacity(0.7),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // アイテム名
              Text(
                '${_gachaResult!.name}をゲット！',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      offset: Offset(1, 1),
                      blurRadius: 2,
                      color: Colors.black,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // 光るエフェクト付きのアイテム表示
              Stack(
                alignment: Alignment.center,
                children: [
                  // 光るエフェクト（後ろ）
                  AnimatedBuilder(
                    animation: _glowAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 200 * _glowAnimation.value,
                        height: 200 * _glowAnimation.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              _getGachaColor(_gachaType!.id),
                              _getGachaColor(_gachaType!.id).withOpacity(0.7),
                              _getGachaColor(_gachaType!.id).withOpacity(0.0),
                            ],
                            stops: const [0.2, 0.5, 1.0],
                          ),
                        ),
                      );
                    },
                  ),

                  // キラキラ効果 - 透過度を下げた放射線状の光
                  AnimatedBuilder(
                    animation: _glowAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 220,
                        height: 220,
                        child: CustomPaint(
                          painter: StarBurstPainter(
                            progress: _glowAnimation.value,
                            color: Colors.white,
                            opacity: 0.1, // 透過度を大幅に下げる
                          ),
                        ),
                      );
                    },
                  ),

                  // アイテム画像 - サイズ調整とfit修正
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(
                            0.5 * _glowAnimation.value,
                          ),
                          blurRadius: 10,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        _gachaResult!.imagePath,
                        fit: BoxFit.contain, // containに変更して全体表示
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.amber.shade100,
                            child: const Center(
                              child: Icon(
                                Icons.emoji_objects,
                                size: 50,
                                color: Colors.brown,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // アイテム説明
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _gachaResult!.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),

              const SizedBox(height: 40),

              // ボタン
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 「続ける」を「戻る」に変更
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('戻る'),
                  ),
                  const SizedBox(width: 24),
                  // 「本棚へ追加」を「マイアイテムを見る」に変更
                  ElevatedButton(
                    onPressed: _navigateToMyItems,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('マイアイテムを見る'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // コイン残高表示ウィジェット
  Widget _buildCoinBalance() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.shade700, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.monetization_on, color: Colors.amber.shade700, size: 20),
          const SizedBox(width: 4),
          Text(
            '$_coinBalance',
            style: TextStyle(
              color: Colors.amber.shade900,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasGachaType = _gachaType != null;

    return Scaffold(
      backgroundColor: Colors.brown.shade800,
      appBar: AppBar(
        title: Text(
          hasGachaType ? _gachaType!.name : 'ガチャ',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.brown.shade900,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // 右上にコイン残高を表示
          _buildCoinBalance(),
        ],
      ),
      body: GestureDetector(
        // スワイプを詳細に検出するための各種ハンドラー
        onHorizontalDragStart: (details) {
          _dragStartX = details.globalPosition.dx;
        },
        onHorizontalDragUpdate: (details) {
          _currentDragX = details.globalPosition.dx;
        },
        onHorizontalDragEnd: (details) {
          // 左から右への十分な距離のスワイプがあった場合（距離でも判定）
          final dragDistance = _currentDragX - _dragStartX;
          if ((dragDistance > 50 ||
                  (details.primaryVelocity != null &&
                      details.primaryVelocity! > 100)) &&
              _canPlayGacha) {
            _playGacha();
          }
        },
        child: Stack(
          children: [
            // ガチャ背景
            Positioned.fill(
              child: Image.asset(
                'assets/wooden-frame-background.jpg',
                fit: BoxFit.cover,
              ),
            ),

            // メインコンテンツ
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ガチャタイプの画像（新しく追加）- サイズと表示方法を調整
                  if (hasGachaType)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _getGachaColor(
                                _gachaType!.id,
                              ).withOpacity(0.6),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Padding(
                            padding: const EdgeInsets.all(5.0), // 内側に余白を追加
                            child: Image.asset(
                              _gachaType!.imagePath,
                              fit: BoxFit.contain, // coverからcontainに変更して全体表示
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: _getGachaColor(
                                    _gachaType!.id,
                                  ).withOpacity(0.5),
                                  child: Icon(
                                    Icons.casino,
                                    color: Colors.white,
                                    size: 60,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),

                  // ガチャマシン
                  Container(
                    width: 250,
                    height: 400,
                    decoration: BoxDecoration(
                      color: Colors.brown.shade700,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // ガチャマシンの本体
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // GACHA文字プレート
                              Container(
                                width: 140,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      hasGachaType
                                          ? _getGachaColor(_gachaType!.id)
                                          : Colors.amber.shade800,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 5,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    hasGachaType ? _gachaType!.name : 'GACHA',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // ガラス玉の部分
                              Container(
                                width: 180,
                                height: 180,
                                decoration: BoxDecoration(
                                  color: Colors.black12,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color:
                                        hasGachaType
                                            ? _getGachaColor(_gachaType!.id)
                                            : Colors.amber.shade900,
                                    width: 10,
                                  ),
                                ),
                                child: ClipOval(
                                  child:
                                      _showResult && _gachaResult != null
                                          ? Padding(
                                            padding: const EdgeInsets.all(
                                              15.0,
                                            ), // 内側に余白を追加
                                            child: Image.asset(
                                              _gachaResult!.imagePath,
                                              fit:
                                                  BoxFit
                                                      .contain, // coverからcontainに変更して全体表示
                                              errorBuilder: (
                                                context,
                                                error,
                                                stackTrace,
                                              ) {
                                                print(
                                                  'Error loading gacha result image: $error',
                                                );
                                                return Container(
                                                  color: Colors.amber.shade100,
                                                  child: const Center(
                                                    child: Icon(
                                                      Icons.emoji_objects,
                                                      size: 50,
                                                      color: Colors.brown,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          )
                                          : _isGachaPlaying
                                          ? AnimatedBuilder(
                                            animation: _dropAnimation,
                                            builder: (context, child) {
                                              return Transform.translate(
                                                offset: Offset(
                                                  0,
                                                  _dropAnimation.value * 150,
                                                ),
                                                child: Container(
                                                  width: 50,
                                                  height: 50,
                                                  decoration: BoxDecoration(
                                                    color:
                                                        hasGachaType
                                                            ? _getGachaColor(
                                                              _gachaType!.id,
                                                            ).withOpacity(0.8)
                                                            : Colors
                                                                .amber
                                                                .shade300,
                                                    shape: BoxShape.circle,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withOpacity(0.3),
                                                        blurRadius: 5,
                                                        spreadRadius: 1,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          )
                                          : Container(
                                            color: Colors.transparent,
                                            child: Image.asset(
                                              'assets/gacha_balls.png',
                                              fit:
                                                  BoxFit
                                                      .contain, // coverからcontainに変更
                                              errorBuilder: (
                                                context,
                                                error,
                                                stackTrace,
                                              ) {
                                                return const Center(
                                                  child: Icon(
                                                    Icons.casino,
                                                    color: Colors.white30,
                                                    size: 80,
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                ),
                              ),

                              const SizedBox(height: 30),

                              // ガチャノブ
                              GestureDetector(
                                onTap: _canPlayGacha ? _playGacha : null,
                                child: AnimatedBuilder(
                                  animation: _rotationAnimation,
                                  builder: (context, child) {
                                    return Transform.rotate(
                                      angle: _rotationAnimation.value * 2 * pi,
                                      child: Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color:
                                              hasGachaType
                                                  ? _getGachaColor(
                                                    _gachaType!.id,
                                                  )
                                                  : Colors.amber.shade800,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.5,
                                              ),
                                              blurRadius: 5,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            Icons.arrow_forward,
                                            color: Colors.white,
                                            size: 30,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ガチャ操作説明
                  const Text(
                    '左から右にスワイプしてガチャを回す',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          offset: Offset(1, 1),
                          blurRadius: 2,
                          color: Colors.black,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ガチャを回すボタン
                  ElevatedButton.icon(
                    onPressed: _canPlayGacha ? _playGacha : null,
                    icon: const Icon(Icons.touch_app),
                    label: Text(
                      'ガチャを回す (${hasGachaType ? _gachaType!.cost : 0}コイン)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          hasGachaType
                              ? _getGachaColor(_gachaType!.id).withOpacity(0.8)
                              : Colors.amber.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      disabledBackgroundColor: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

            // インジケーター
            if (_isGachaPlaying)
              Positioned(
                right: 20,
                top: 20,
                child: SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      hasGachaType
                          ? _getGachaColor(_gachaType!.id)
                          : Colors.amber.shade600,
                    ),
                  ),
                ),
              ),

            // 結果オーバーレイ
            _buildResultOverlay(),
          ],
        ),
      ),
    );
  }

  // ガチャタイプによって色を変更
  Color _getGachaColor(String gachaTypeId) {
    switch (gachaTypeId) {
      case 'standard':
        return Colors.amber.shade800;
      case 'premium':
        return Colors.blue.shade700;
      case 'limited':
        return Colors.purple.shade700;
      default:
        return Colors.amber.shade800;
    }
  }
}

// キラキラエフェクト用のカスタムペインター
class StarBurstPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double opacity; // 透過度パラメータを追加

  StarBurstPainter({
    required this.progress,
    required this.color,
    this.opacity = 0.6, // デフォルト値を0.6から0.1に変更
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;

    final paint =
        Paint()
          ..color = color.withOpacity(progress * opacity) // 透過度を適用
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke;

    // 複数の光線を描画
    for (int i = 0; i < 12; i++) {
      final angle = (i * pi / 6);
      final length = radius * (0.5 + progress * 0.5);

      final start = Offset(
        center.dx + cos(angle) * radius * 0.3,
        center.dy + sin(angle) * radius * 0.3,
      );

      final end = Offset(
        center.dx + cos(angle) * length,
        center.dy + sin(angle) * length,
      );

      canvas.drawLine(start, end, paint);
    }

    // 星形のエフェクト
    for (int i = 0; i < 6; i++) {
      final angle = (i * pi / 3) + (progress * pi / 6);
      final length = radius * (0.3 + progress * 0.7);

      final point = Offset(
        center.dx + cos(angle) * length,
        center.dy + sin(angle) * length,
      );

      canvas.drawCircle(
        point,
        3.0 * progress,
        Paint()..color = color.withOpacity(opacity * 0.8), // 透過度を適用
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
