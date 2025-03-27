// lib/screens/book_overview_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/book_models.dart';
import '../repositories/book_repository.dart';
import 'book_screen.dart';

class BookOverviewScreen extends StatefulWidget {
  const BookOverviewScreen({Key? key}) : super(key: key);

  @override
  _BookOverviewScreenState createState() => _BookOverviewScreenState();
}

class _BookOverviewScreenState extends State<BookOverviewScreen>
    with SingleTickerProviderStateMixin {
  final BookRepository _bookRepository = BookRepository();
  Book? _book;
  bool _isLoading = true;
  bool _isDownloaded = false;
  bool _isDownloading = false;

  // 表紙拡大表示用の状態
  bool _isZoomed = false;
  bool _isAnimating = false; // アニメーション中かどうかのフラグを追加
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // アニメーションコントローラーを初期化 - より長い時間で実行
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // アニメーション終了のリスナーを追加
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        if (mounted) {
          setState(() {
            _isAnimating = false;
          });
        }
      }
    });

    // スケールアニメーション - より大きく拡大
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.7,
        ).chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 60.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.7,
          end: 1.65,
        ).chain(CurveTween(curve: Curves.easeInOutBack)),
        weight: 40.0,
      ),
    ]).animate(_animationController);

    // 回転アニメーション - 本を少し傾ける効果
    _rotateAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 0.05,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 50.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.05,
          end: -0.01,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50.0,
      ),
    ]).animate(_animationController);

    // スライドアニメーション - 上から少し下へ移動
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.02),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    // 背景と読むボタンのフェードインアニメーション
    _opacityAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadBookData();
  }

  // 本データを読み込む
  Future<void> _loadBookData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 引数を取得
      final Map<String, dynamic> args =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      final String bookId = args['bookId'] as String;

      // 本データを取得
      final book = await _bookRepository.getBookById(bookId);

      if (book != null) {
        setState(() {
          _book = book;
        });

        // 本がダウンロード済みかチェック
        final isDownloaded = await _bookRepository.isBookDownloaded(bookId);
        setState(() {
          _isDownloaded = isDownloaded;
        });
      }
    } catch (e) {
      print('Error loading book data: $e');
      // エラーメッセージを表示
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('本データの読み込みに失敗しました: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 本をダウンロード
  Future<void> _downloadBook() async {
    if (_book == null) return;

    setState(() {
      _isDownloading = true;
    });

    try {
      final success = await _bookRepository.downloadBook(_book!.id);

      if (success) {
        setState(() {
          _isDownloaded = true;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('本のダウンロードが完了しました')));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('本のダウンロードに失敗しました')));
      }
    } catch (e) {
      print('Error downloading book: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('本のダウンロード中にエラーが発生しました: $e')));
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }

  // 絵本を読むボタンのハンドラー
  void _navigateToBookScreen() {
    Navigator.pushNamed(
      context,
      '/book',
      arguments: BookScreenArguments(
        bookId: _book!.id,
        title: _book!.title,
        isTTS: false,
      ),
    );
  }

  // 表紙画像をタップした時の処理 - スムーズなアニメーション
  void _toggleCoverZoom() {
    // アニメーション中は操作をスキップ
    if (_isAnimating) return;

    setState(() {
      _isAnimating = true; // アニメーション開始をマーク

      if (_isZoomed) {
        // 閉じる: アニメーションが完了した後に状態を変更
        _animationController.reverse().then((_) {
          if (mounted) {
            setState(() {
              _isZoomed = false;
            });
          }
        });
      } else {
        // 開く: まず状態を変更してからアニメーション開始
        _isZoomed = true;

        // ティックを待ってからアニメーション開始（チラツキ防止）
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _animationController.forward();
        });
      }
    });
  }

  // 表紙画像ウィジェット - ダイナミックなアニメーション (影なし)
  Widget _buildCoverImage(String coverPath) {
    return GestureDetector(
      onTap: _toggleCoverZoom,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _slideAnimation.value.dy * 100),
            child: Transform.rotate(
              angle: _rotateAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              ),
            ),
          );
        },
        child: Hero(
          tag: 'cover-${_book?.id ?? "loading"}',
          child: FutureBuilder<String>(
            future: _bookRepository.getAssetPath(coverPath),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  width: 100,
                  height: 150,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final imagePath = snapshot.data ?? coverPath;

              // パスに基づいて適切な ImageProvider を選択
              ImageProvider imageProvider;
              if (imagePath.startsWith('assets/')) {
                // プリインストール画像の場合
                imageProvider = AssetImage(imagePath);
              } else if (!imagePath.startsWith('http')) {
                // ダウンロードされたローカルファイルの場合
                imageProvider = FileImage(File(imagePath));
              } else {
                // デフォルトはAssetImageとして扱う
                imageProvider = AssetImage(coverPath);
              }

              // 影を完全に削除するために、ClipRectを使って影がはみ出ないようにする
              return ClipRect(
                child: Image(
                  image: imageProvider,
                  width: MediaQuery.of(context).size.width * 0.6,
                  height: 200,
                  fit: BoxFit.contain,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_book == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '本データが見つかりませんでした',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('戻る'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 背景
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/wooden-frame-background.jpg'),
                fit: BoxFit.cover,
              ),
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // 本のイメージとタイトル
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Container(
                            decoration: const BoxDecoration(
                              image: DecorationImage(
                                image: AssetImage('assets/blackboard.png'),
                                fit: BoxFit.fill,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // 本のカバー画像
                                _buildCoverImage(_book!.coverAssetPath),
                                const SizedBox(height: 15),

                                // 本のタイトル - アニメーション時にチラつかないようにする
                                AnimatedOpacity(
                                  // アニメーション中またはズームモードならタイトルを非表示
                                  opacity:
                                      _isAnimating || _isZoomed ? 0.0 : 1.0,
                                  duration: const Duration(milliseconds: 150),
                                  child: Text(
                                    _book!.title,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ジャンルタグ
                      if (_book!.genres != null)
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children:
                              _book!.genres!
                                  .map((genre) => _buildGenreTag(genre))
                                  .toList(),
                        ),

                      const SizedBox(height: 20),

                      // 閲覧数と評価
                      if (_book!.views != null &&
                          _book!.rating != null &&
                          _book!.comments != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // 閲覧数
                            Row(
                              children: [
                                const Text(
                                  '👁️',
                                  style: TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _book!.views.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),

                            // 星評価
                            _buildRatingStars(_book!.rating!),

                            // コメント数
                            Row(
                              children: [
                                const Text(
                                  '💬',
                                  style: TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _book!.comments.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                      const SizedBox(height: 20),

                      // 概要テキスト
                      if (_book!.summary != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF8B4513),
                              width: 2,
                            ),
                          ),
                          child: Text(
                            _book!.summary!,
                            style: const TextStyle(fontSize: 14, height: 1.5),
                          ),
                        ),

                      const SizedBox(height: 30),

                      // ダウンロードステータス
                      if (_isDownloaded)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, color: Colors.green),
                              SizedBox(width: 8),
                              Text(
                                'ダウンロード済み',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        )
                      else if (_isDownloading)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'ダウンロード中...',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        )
                      else
                        ElevatedButton.icon(
                          onPressed: _downloadBook,
                          icon: const Icon(Icons.download),
                          label: const Text('オフライン読書用にダウンロード'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),

                      const SizedBox(height: 20),

                      // 読むボタン
                      GestureDetector(
                        onTap: _navigateToBookScreen,
                        child: Container(
                          width: 240,
                          height: 84,
                          decoration: const BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage('assets/button-frame.png'),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 拡大表示オーバーレイ - アニメーション付き
          if (_isZoomed)
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Opacity(
                  opacity: _opacityAnimation.value,
                  child: GestureDetector(
                    onTap: _toggleCoverZoom, // 背景タップで閉じる
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.9),
                        gradient: RadialGradient(
                          colors: [
                            Colors.black.withOpacity(0.85),
                            Colors.black.withOpacity(0.95),
                          ],
                          center: Alignment.center,
                          radius: 1.2,
                        ),
                      ),
                      width: double.infinity,
                      height: double.infinity,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // 閉じるボタン
                          Align(
                            alignment: Alignment.topRight,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 30,
                                ),
                                onPressed: _toggleCoverZoom,
                              ),
                            ),
                          ),

                          // 拡大表紙画像
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                              child: Hero(
                                tag: 'cover-${_book!.id}',
                                child: FutureBuilder<String>(
                                  future: _bookRepository.getAssetPath(
                                    _book!.coverAssetPath,
                                  ),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const Center(
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                        ),
                                      );
                                    }

                                    final imagePath =
                                        snapshot.data ?? _book!.coverAssetPath;

                                    // パスに基づいて適切な ImageProvider を選択
                                    ImageProvider imageProvider;
                                    if (imagePath.startsWith('assets/')) {
                                      imageProvider = AssetImage(imagePath);
                                    } else if (!imagePath.startsWith('http')) {
                                      imageProvider = FileImage(
                                        File(imagePath),
                                      );
                                    } else {
                                      imageProvider = AssetImage(
                                        _book!.coverAssetPath,
                                      );
                                    }

                                    // 拡大表示でも影なし
                                    return ClipRect(
                                      child: Image(
                                        image: imageProvider,
                                        fit: BoxFit.contain,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),

                          // 読むボタン - button-frame.png画像を使用
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: 40.0,
                              top: 20.0,
                            ),
                            child: AnimatedBuilder(
                              animation: _animationController,
                              builder: (context, child) {
                                return Transform.translate(
                                  offset: Offset(
                                    0,
                                    50 * (1 - _opacityAnimation.value),
                                  ),
                                  child: Opacity(
                                    opacity: _opacityAnimation.value,
                                    child: child,
                                  ),
                                );
                              },
                              child: GestureDetector(
                                onTap: _navigateToBookScreen,
                                child: Container(
                                  width: 240,
                                  height: 84,
                                  decoration: const BoxDecoration(
                                    image: DecorationImage(
                                      image: AssetImage(
                                        'assets/button-frame.png',
                                      ),
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ジャンルタグウィジェット
  Widget _buildGenreTag(String genre) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        genre,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // 星評価ウィジェット
  Widget _buildRatingStars(double rating) {
    final int fullStars = rating.floor();
    final bool hasHalfStar = rating - fullStars >= 0.5;
    final int emptyStars = 5 - fullStars - (hasHalfStar ? 1 : 0);

    return Row(
      children: [
        ...List.generate(
          fullStars,
          (index) => const Text(
            '★',
            style: TextStyle(color: Color(0xFFFFD700), fontSize: 24),
          ),
        ),
        if (hasHalfStar)
          const Text(
            '★',
            style: TextStyle(color: Color(0xFFFFD700), fontSize: 24),
          ),
        ...List.generate(
          emptyStars,
          (index) => const Text(
            '★',
            style: TextStyle(color: Color(0xFF444444), fontSize: 24),
          ),
        ),
      ],
    );
  }
}
