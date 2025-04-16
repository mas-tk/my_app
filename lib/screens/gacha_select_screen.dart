// lib/screens/gacha_select_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/gacha_models.dart';
import '../models/coin_models.dart';
import '../repositories/gacha_repository.dart';
import '../repositories/coin_repository.dart';
import 'gacha_screen.dart';

class GachaSelectScreen extends StatefulWidget {
  const GachaSelectScreen({Key? key}) : super(key: key);

  @override
  _GachaSelectScreenState createState() => _GachaSelectScreenState();
}

class _GachaSelectScreenState extends State<GachaSelectScreen> {
  final GachaRepository _gachaRepository = GachaRepository();
  final CoinRepository _coinRepository = CoinRepository();

  List<GachaType> _gachaTypes = [];
  CoinBalance? _coinBalance;
  bool _isLoading = true;

  // ページコントローラーを追加
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _loadData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // ガチャタイプとコイン残高を並行して読み込む
      final gachaTypesFuture = _gachaRepository.getGachaTypes();
      final coinBalanceFuture = _coinRepository.getBalance();

      // 両方の結果を待つ
      final results = await Future.wait([gachaTypesFuture, coinBalanceFuture]);

      setState(() {
        _gachaTypes = results[0] as List<GachaType>;
        _coinBalance = results[1] as CoinBalance;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ガチャ選択時のハンドラー
  Future<void> _selectGacha(GachaType gachaType) async {
    // コイン残高が足りるかチェック
    if (_coinBalance != null && _coinBalance!.balance < gachaType.cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'コインが足りません。あと${gachaType.cost - _coinBalance!.balance}コイン必要です。',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // ガチャ画面に遷移
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => GachaScreen(gachaTypeId: gachaType.id),
          ),
        )
        .then((result) {
          // ガチャ画面から戻ってきたらデータを再読み込み
          _loadData();

          // ガチャの結果を表示
          if (result != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('新しいアイテムを獲得しました: ${result.name}'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        });
  }

  // バイブレーション関数
  Future<void> _generateHapticFeedback() async {
    try {
      // 複数の異なるタイプを使用して効果を高める
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 10));
      await HapticFeedback.lightImpact();
    } catch (e) {
      print('Haptic feedback error: $e');
    }
  }

  // 個別のガチャページを構築するウィジェット
  Widget _buildGachaPage(GachaType gachaType) {
    final bool canAfford =
        _coinBalance != null && _coinBalance!.balance >= gachaType.cost;
    final screenHeight = MediaQuery.of(context).size.height;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ガチャ名称
        Text(
          gachaType.name,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(
                offset: Offset(1, 1),
                blurRadius: 3.0,
                color: Colors.black.withOpacity(0.5),
              ),
            ],
          ),
        ),

        SizedBox(height: 20),

        // ガチャ画像 (縦長の比率を保つ)
        SizedBox(
          height: screenHeight * 0.45, // 画面の高さの45%
          child: Image.asset(
            gachaType.imagePath,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              print('Error loading gacha image: $error');
              return Container(
                color: Colors.amber.shade100,
                child: Center(
                  child: Icon(Icons.casino, size: 80, color: Colors.amber),
                ),
              );
            },
          ),
        ),

        SizedBox(height: 20),

        // ガチャ説明
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Text(
            gachaType.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white,
              shadows: [
                Shadow(
                  offset: Offset(1, 1),
                  blurRadius: 3.0,
                  color: Colors.black.withOpacity(0.5),
                ),
              ],
            ),
          ),
        ),

        SizedBox(height: 30),

        // コスト表示とガチャを回すボタン
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(Icons.monetization_on, color: Colors.amber, size: 24),
                  SizedBox(width: 8),
                  Text(
                    '${gachaType.cost}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: canAfford ? Colors.amber : Colors.red,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(width: 20),

            ElevatedButton(
              onPressed: canAfford ? () => _selectGacha(gachaType) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _getGachaColor(gachaType.id).withOpacity(0.8),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 5,
                shadowColor: Colors.black.withOpacity(0.5),
              ),
              child: Text(
                'ガチャを回す',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),

        SizedBox(height: 20),

        // ページインジケーター
        if (_gachaTypes.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _gachaTypes.length,
              (index) => Container(
                margin: EdgeInsets.symmetric(horizontal: 4),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      _currentPage == index
                          ? Colors.white
                          : Colors.white.withOpacity(0.4),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // スワイプ方向のヒントを表示
  Widget _buildSwipeHint(bool isLeft) {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(
        isLeft ? Icons.arrow_back_ios : Icons.arrow_forward_ios,
        color: Colors.white.withOpacity(0.7),
        size: 24,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ガチャを選ぶ', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.brown.shade900,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // コイン残高表示
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.monetization_on, color: Colors.amber),
                const SizedBox(width: 4),
                Text(
                  _coinBalance != null ? '${_coinBalance!.balance}' : '0',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/wooden-frame-background.jpg'),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      Colors.black.withOpacity(0.2),
                      BlendMode.darken,
                    ),
                  ),
                ),
                child: SafeArea(
                  child: Stack(
                    children: [
                      // コインの説明
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'コインはログインボーナスや本を読むことで獲得できます。ガチャを回して特別なアイテムを手に入れましょう！',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // ガチャリスト（ページビュー）
                      Positioned.fill(
                        top: 80, // 上部の説明の下
                        child:
                            _gachaTypes.isEmpty
                                ? Center(
                                  child: Text(
                                    'ガチャが見つかりません',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                )
                                : PageView.builder(
                                  controller: _pageController,
                                  itemCount: _gachaTypes.length,
                                  onPageChanged: (index) {
                                    setState(() {
                                      _currentPage = index;
                                    });
                                    // バイブレーション
                                    _generateHapticFeedback();
                                  },
                                  itemBuilder: (context, index) {
                                    return _buildGachaPage(_gachaTypes[index]);
                                  },
                                ),
                      ),

                      // 左右のスワイプヒント（複数ガチャがある場合のみ表示）
                      if (_gachaTypes.length > 1) ...[
                        // 左スワイプヒント
                        if (_currentPage > 0)
                          Positioned(
                            left: 16,
                            top: MediaQuery.of(context).size.height / 2,
                            child: _buildSwipeHint(true),
                          ),

                        // 右スワイプヒント
                        if (_currentPage < _gachaTypes.length - 1)
                          Positioned(
                            right: 16,
                            top: MediaQuery.of(context).size.height / 2,
                            child: _buildSwipeHint(false),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
    );
  }
}
