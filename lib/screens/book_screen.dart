// lib/screens/book_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turn_page_transition/turn_page_transition.dart';
import '../models/book_models.dart';
import '../repositories/book_repository.dart';
import 'review_screen.dart';

// BookScreenに渡すパラメータ
class BookScreenArguments {
  final String bookId;
  final String title;
  final bool isTTS;

  BookScreenArguments({
    required this.bookId,
    this.title = '',
    this.isTTS = false,
  });
}

class BookScreen extends StatefulWidget {
  final BookScreenArguments args;

  const BookScreen({Key? key, required this.args}) : super(key: key);

  @override
  _BookScreenState createState() => _BookScreenState();
}

class _BookScreenState extends State<BookScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  // レポジトリ
  final BookRepository _bookRepository = BookRepository();

  // ページコントローラー
  late PageController _pageController;

  // アニメーションコントローラー
  late AnimationController _animationController;
  late Animation<double> _animation;

  // 音楽プレーヤー
  final AudioPlayer _audioPlayer = AudioPlayer();

  // 状態管理
  bool _showMenu = false;
  double _volume = 0.5;
  bool _soundEnabled = true;
  bool _bgmPlaying = false;
  bool _isChangingTrack = false;
  bool _isLoading = true;
  Map<String, bool> _textVisibility = {};
  Book? _book;
  int _currentPage = 0;
  String? _currentAudioPath;
  AudioTrack? _currentTrack;

  // アニメーション関連の状態
  bool _isPageTurning = false;
  int _targetPage = 0;
  final Duration _pageTurnDuration = const Duration(milliseconds: 600);

  // ページめくりの方向
  TurnDirection _turnDirection = TurnDirection.rightToLeft;

  // 最後のページの検出用
  bool _isLastPage = false;

  // お気に入り状態
  bool _isFavorite = false;
  double _userRating = 0;

  // 画像キャッシュ
  final Map<String, String> _imagePathCache = {};
  final Map<String, Image> _imageCache = {};

  // スワイプ検出用
  double _touchStartY = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(viewportFraction: 1.0, keepPage: true);

    // アニメーションコントローラーの初期化
    _animationController = AnimationController(
      vsync: this,
      duration: _pageTurnDuration,
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // 初期化を非同期で安全に行う
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      debugPrint('初期化: アプリの初期化を開始します');

      // デフォルトでサウンドを有効にする
      _soundEnabled = true;

      await _loadBookData();

      debugPrint('初期化: 本データのロードが完了しました');

      // BGMプレーヤーを初期設定
      await _setupPlayer();

      // 事前に画像パスを解決しておく
      await _precacheImages();

      // ユーザーのお気に入り状態を取得
      await _loadUserPreferences();

      // 音楽設定を非同期で初期化
      // 少し遅延させることで準備が確実に完了するようにする
      await Future.delayed(const Duration(milliseconds: 300));
      await _setupAudio();

      debugPrint('初期化: アプリの初期化が完了しました');
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      if (_bgmPlaying) {
        _audioPlayer.pause();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_bgmPlaying) {
        _audioPlayer.resume();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _animationController.dispose();

    // 音声を停止して解放
    try {
      _audioPlayer.stop();
    } catch (e) {
      debugPrint('Error stopping audio: $e');
    }

    _audioPlayer.dispose();

    // キャッシュをクリア
    _imagePathCache.clear();
    _imageCache.clear();

    super.dispose();
  }

  // 本データを読み込む
  Future<void> _loadBookData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final book = await _bookRepository.getBookById(widget.args.bookId);

      if (book != null && book.pages != null) {
        setState(() {
          _book = book;

          // すべてのページでテキスト非表示に初期化
          for (var page in book.pages!) {
            _textVisibility[page.pageId] = false;
          }
        });
      } else {
        throw Exception('本データが見つかりませんでした');
      }
    } catch (e) {
      print('Error loading book data: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('本データの読み込みに失敗しました: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ユーザー設定を読み込む
  Future<void> _loadUserPreferences() async {
    try {
      // SharedPreferences などを使ってユーザー設定を読み込む実装
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _isFavorite = prefs.getBool('favorite_${widget.args.bookId}') ?? false;
        _userRating = prefs.getDouble('rating_${widget.args.bookId}') ?? 0;
      });
    } catch (e) {
      print('Error loading user preferences: $e');
    }
  }

  // 画像パスを解決してキャッシュに保存
  Future<String> _resolveImagePath(String remotePath) async {
    if (_imagePathCache.containsKey(remotePath)) {
      return _imagePathCache[remotePath]!;
    }

    try {
      final localPath = await _bookRepository.getAssetPath(remotePath);
      _imagePathCache[remotePath] = localPath;
      return localPath;
    } catch (e) {
      print('Error resolving image path: $e');
      return remotePath; // 失敗した場合は元のパスを返す
    }
  }

  // 画像を事前にキャッシュする
  Future<void> _precacheImages() async {
    if (_book == null || _book!.pages == null) return;

    try {
      // 最初のページとその次のページをキャッシュ
      int pagesToCache = _book!.pages!.length > 2 ? 2 : _book!.pages!.length;

      for (int i = 0; i < pagesToCache; i++) {
        final page = _book!.pages![i];
        await _cacheImage(page.baseImage);
        await _cacheImage(page.textImage);
      }
    } catch (e) {
      print('Error precaching images: $e');
    }
  }

  // 1つの画像をキャッシュする
  Future<void> _cacheImage(String remotePath) async {
    try {
      final localPath = await _resolveImagePath(remotePath);

      if (!_imageCache.containsKey(localPath)) {
        final image = _createImageWidget(localPath, remotePath);
        _imageCache[localPath] = image;

        // 画像をプリロード
        await precacheImage(image.image, context);
      }
    } catch (e) {
      print('Error caching image: $e');
    }
  }

  // 画像ウィジェットを作成
  Image _createImageWidget(String imagePath, String defaultPath) {
    if (imagePath.startsWith('assets/')) {
      return Image.asset(imagePath, fit: BoxFit.contain, gaplessPlayback: true);
    } else if (!imagePath.startsWith('http')) {
      return Image.file(
        File(imagePath),
        fit: BoxFit.contain,
        gaplessPlayback: true,
      );
    } else {
      return Image.asset(
        defaultPath,
        fit: BoxFit.contain,
        gaplessPlayback: true,
      );
    }
  }

  // キャッシュから画像ウィジェットを取得
  Widget _getImageWidget(String imagePath) {
    final cachedPath = _imagePathCache[imagePath] ?? imagePath;

    if (_imageCache.containsKey(cachedPath)) {
      return _imageCache[cachedPath]!;
    }

    final image = _createImageWidget(cachedPath, imagePath);
    _imageCache[cachedPath] = image;
    return image;
  }

  // 現在のページの周辺ページをキャッシュする
  void _cacheSurroundingPages(int currentIndex) {
    if (_book == null || _book!.pages == null) return;

    // 次のページをキャッシュ
    if (currentIndex < _book!.pages!.length - 1) {
      final nextPage = _book!.pages![currentIndex + 1];
      _cacheImage(nextPage.baseImage);
      _cacheImage(nextPage.textImage);
    }

    // 2ページ先をキャッシュ
    if (currentIndex < _book!.pages!.length - 2) {
      final nextNextPage = _book!.pages![currentIndex + 2];
      _cacheImage(nextNextPage.baseImage);
      _cacheImage(nextNextPage.textImage);
    }
  }

  // プレーヤーの初期設定
  Future<void> _setupPlayer() async {
    try {
      debugPrint('初期化: オーディオプレーヤーをセットアップします');

      // BGMプレーヤーの設定
      await _audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);
      await _audioPlayer.setVolume(_volume);
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);

      // グローバルAudioContextの設定
      AudioPlayer.global.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: true,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gain,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {AVAudioSessionOptions.mixWithOthers},
          ),
        ),
      );

      debugPrint('初期化: オーディオプレーヤーのセットアップ完了');
    } catch (e) {
      debugPrint('エラー: オーディオプレーヤーのセットアップ失敗: $e');
    }
  }

  // 音楽の初期設定 - よりシンプルに
  Future<void> _setupAudio() async {
    if (_book?.audio == null) {
      debugPrint('注意: この本にはオーディオデータがありません');
      return;
    }

    try {
      // 初期ページに対応するトラックを取得
      _currentTrack = _book!.audio!.getTrackForPage(_currentPage + 1);
      if (_currentTrack == null) {
        debugPrint('注意: 現在のページに対応するトラックが見つかりません');
        return;
      }

      // ローカルパスを取得
      final localPath = await _bookRepository.getAssetPath(
        _currentTrack!.assetPath,
      );
      _currentAudioPath = localPath;
      debugPrint('オーディオトラックパス: $localPath');

      // ソースタイプに基づいて適切な方法でオーディオをセット
      try {
        if (localPath.startsWith('assets/')) {
          // アセットパスを適切に処理
          final normalizedPath = localPath.substring(7); // 'assets/'の部分を削除
          debugPrint('アセットからオーディオをセット: $normalizedPath');
          await _audioPlayer.setSourceAsset(normalizedPath);
        } else if (!localPath.startsWith('http')) {
          // ローカルファイルパス
          debugPrint('ローカルファイルからオーディオをセット: $localPath');
          await _audioPlayer.setSourceDeviceFile(localPath);
        } else {
          // URL（実装していない）
          debugPrint('URLからのオーディオは現在サポートされていません');
          throw Exception('Unsupported audio source type');
        }

        // 自動再生
        if (_soundEnabled) {
          await Future.delayed(const Duration(milliseconds: 300));
          await _playBackgroundMusic();
        }
      } catch (e) {
        debugPrint('オーディオソース設定エラー: $e');

        // フォールバック - サンプルオーディオファイル
        try {
          debugPrint('フォールバックオーディオを試みます');
          await _audioPlayer.setSourceAsset('audio/sample.mp3');
          _currentAudioPath = 'audio/sample.mp3';

          if (_soundEnabled) {
            await Future.delayed(const Duration(milliseconds: 300));
            await _playBackgroundMusic();
          }
        } catch (fallbackError) {
          debugPrint('フォールバックオーディオ設定エラー: $fallbackError');
        }
      }
    } catch (e) {
      debugPrint('オーディオセットアップエラー: $e');
    }
  }

  // ページに応じてBGMを確認・切り替える関数
  Future<void> _checkAndUpdateBGM(int pageNumber) async {
    if (_isChangingTrack || _book?.audio == null) return;

    // ページ番号は0-indexedなので1を加える
    final int actualPageNumber = pageNumber + 1;

    // 現在のページに対応するトラックを取得
    final newTrack = _book!.audio!.getTrackForPage(actualPageNumber);

    // トラックが見つからない場合や、BGMが無効の場合は何もしない
    if (newTrack == null || !_soundEnabled) return;

    // 現在と異なるトラックの場合、BGMを切り替える
    if (_currentTrack == null ||
        _currentTrack!.assetPath != newTrack.assetPath) {
      _isChangingTrack = true;

      try {
        // BGMを一旦停止
        final wasPlaying = _bgmPlaying;
        if (wasPlaying) {
          await _audioPlayer.pause();
        }

        // ローカルパスを取得
        final localPath = await _bookRepository.getAssetPath(
          newTrack.assetPath,
        );
        _currentAudioPath = localPath;

        // 新しいトラックをセット
        if (localPath.startsWith('assets/')) {
          // アセットパスを適切に処理
          final normalizedPath = localPath.substring(7); // 'assets/'の部分を削除
          debugPrint('次のアセットに変更: $normalizedPath');
          await _audioPlayer.setSourceAsset(normalizedPath);
        } else if (!localPath.startsWith('http')) {
          // ローカルファイルパス
          debugPrint('次のローカルファイルに変更: $localPath');
          await _audioPlayer.setSourceDeviceFile(localPath);
        }

        _currentTrack = newTrack;
        debugPrint('トラック変更: ${newTrack.assetPath} (ページ: $actualPageNumber)');

        // 再生中だった場合は再開
        if (wasPlaying) {
          await _audioPlayer.resume();
          setState(() {
            _bgmPlaying = true;
          });
        }
      } catch (e) {
        debugPrint('トラック変更エラー: $e');
      } finally {
        _isChangingTrack = false;
      }
    }
  }

  // BGM再生 - シンプルに
  Future<void> _playBackgroundMusic() async {
    try {
      debugPrint('BGM再生開始試行');
      await _audioPlayer.resume();
      setState(() {
        _bgmPlaying = true;
      });
      debugPrint('BGM再生開始');
    } catch (e) {
      debugPrint('BGM再生エラー: $e');

      // 再試行
      try {
        await Future.delayed(const Duration(milliseconds: 500));
        debugPrint('BGM再生再試行');
        await _audioPlayer.resume();
        setState(() {
          _bgmPlaying = true;
        });
      } catch (retryError) {
        debugPrint('BGM再生再試行エラー: $retryError');
      }
    }
  }

  // BGM一時停止 - シンプルに
  Future<void> _stopBackgroundMusic() async {
    try {
      debugPrint('BGM停止試行');
      await _audioPlayer.pause();
      setState(() {
        _bgmPlaying = false;
      });
      debugPrint('BGM停止完了');
    } catch (e) {
      debugPrint('BGM停止エラー: $e');
    }
  }

  // BGMのオン/オフを切り替え
  Future<void> _toggleBackgroundMusic() async {
    debugPrint('BGM切り替え: 現在の状態=${_bgmPlaying}');
    if (_bgmPlaying) {
      await _stopBackgroundMusic();
      setState(() {
        _soundEnabled = false;
      });
    } else {
      setState(() {
        _soundEnabled = true;
      });
      await _playBackgroundMusic();
    }
  }

  // ページを前に移動する (シンプル版)
  void _turnToPreviousPage() {
    if (_currentPage > 0 && !_isPageTurning) {
      setState(() {
        _isPageTurning = true;
        _targetPage = _currentPage - 1;
        _turnDirection = TurnDirection.leftToRight;
      });

      // アニメーションを開始
      _animationController.reset();
      _animationController.forward().then((_) {
        setState(() {
          _currentPage = _targetPage;
          _isPageTurning = false;
          _pageController = PageController(initialPage: _currentPage);
        });
        _handlePageChanged(_currentPage);
      });
    }
  }

  // ページを次に移動する (シンプル版)
  void _turnToNextPage() {
    if (_book != null &&
        _currentPage < _book!.pages!.length - 1 &&
        !_isPageTurning) {
      setState(() {
        _isPageTurning = true;
        _targetPage = _currentPage + 1;
        _turnDirection = TurnDirection.rightToLeft;
      });

      // アニメーションを開始
      _animationController.reset();
      _animationController.forward().then((_) {
        setState(() {
          _currentPage = _targetPage;
          _isPageTurning = false;
          _pageController = PageController(initialPage: _currentPage);
        });
        _handlePageChanged(_currentPage);
      });
    }
  }

  // 最初のページに戻る (シンプル版)
  void _restartBook() {
    if (_currentPage > 0 && !_isPageTurning) {
      setState(() {
        _isPageTurning = true;
        _targetPage = 0;
        _turnDirection = TurnDirection.leftToRight;
      });

      // アニメーションを開始
      _animationController.reset();
      _animationController.forward().then((_) {
        setState(() {
          _currentPage = 0;
          _isPageTurning = false;
          _pageController = PageController(initialPage: 0);
        });
        _handlePageChanged(0);
      });
    }
  }

  // タッチ開始時のハンドラー（垂直方向のみを監視）
  void _handleTouchStart(DragStartDetails details) {
    _touchStartY = details.globalPosition.dy;
  }

  // スワイプ終了時のハンドラー（垂直方向）
  void _handleVerticalSwipeEnd(DragEndDetails details) {
    final touchEndY = details.velocity.pixelsPerSecond.dy;

    // 上向きスワイプ（メニュー表示）
    if (touchEndY.abs() > 200 && touchEndY < 0) {
      setState(() {
        _showMenu = true;
      });
    }
    // 下向きスワイプ（メニュー非表示）
    else if (touchEndY.abs() > 200 && touchEndY > 0) {
      setState(() {
        _showMenu = false;
      });
    }
  }

  // 水平方向のスワイプをハンドリングする
  void _handleHorizontalSwipe(DragEndDetails details) {
    if (_isPageTurning) return;

    final velocity = details.velocity.pixelsPerSecond.dx;
    // 速度閾値を設定
    const velocityThreshold = 200.0;

    // 右から左へのスワイプ（進む）
    if (velocity < -velocityThreshold) {
      _turnToNextPage();
    }
    // 左から右へのスワイプ（戻る）
    else if (velocity > velocityThreshold) {
      _turnToPreviousPage();
    }
  }

  // レビュー画面を開くメソッド
  void _openReviewScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => ReviewScreen(
              args: ReviewScreenArguments(
                bookId: widget.args.bookId,
                title: _book?.title ?? widget.args.title,
                isFavorite: _isFavorite,
                userRating: _userRating,
              ),
            ),
      ),
    );
  }

  // レビューボタンを表示するウィジェット
  Widget _buildReviewButton() {
    return GestureDetector(
      onTap: _openReviewScreen,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.amber,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.rate_review, color: Colors.black, size: 20),
            SizedBox(width: 8),
            Text(
              'レビューを書く',
              style: TextStyle(
                color: Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ページタップでテキスト表示/非表示を切り替え
  void _toggleTextLayer(String pageId) {
    setState(() {
      _textVisibility[pageId] = !(_textVisibility[pageId] ?? false);
    });
  }

  // ページめくり時の処理
  void _handlePageChanged(int pageIndex) {
    setState(() {
      _currentPage = pageIndex;

      // 最後のページかどうかをチェック
      _isLastPage = (_book != null && pageIndex == _book!.pages!.length - 1);
    });

    // ページ変更時にBGMの確認と切り替えを行う
    _checkAndUpdateBGM(pageIndex);

    // 次のページと前のページの画像をプリキャッシュ
    _cacheSurroundingPages(pageIndex);

    debugPrint('Page changed to: $pageIndex');
  }

  // ページコンテンツを構築
  Widget _buildPageContent(int index) {
    if (_book == null ||
        _book!.pages == null ||
        index >= _book!.pages!.length) {
      return Container(color: Colors.black);
    }

    final page = _book!.pages![index];
    bool isTextVisible = _textVisibility[page.pageId] ?? false;

    return GestureDetector(
      onTap: () => _toggleTextLayer(page.pageId),
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ベースイメージ（イラスト）
            _getImageWidget(page.baseImage),

            // テキストレイヤー（アニメーション付きの表示/非表示）
            AnimatedOpacity(
              opacity: isTextVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: _getImageWidget(page.textImage),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _book == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // メインのコンテンツ
          GestureDetector(
            onVerticalDragStart: _handleTouchStart,
            onVerticalDragEnd: _handleVerticalSwipeEnd,
            onHorizontalDragEnd: _handleHorizontalSwipe,
            child:
                _isPageTurning
                    ? AnimatedBuilder(
                      animation: _animation,
                      builder: (context, child) {
                        return TurnPageTransition(
                          animation: _animation,
                          overleafColor: Colors.white,
                          direction: _turnDirection,
                          child: _buildPageContent(
                            _targetPage,
                          ), // 常にめくった先のページを表示
                        );
                      },
                    )
                    : PageView.builder(
                      controller: _pageController,
                      itemCount: _book!.pages!.length,
                      onPageChanged: _handlePageChanged,
                      pageSnapping: true,
                      physics:
                          const NeverScrollableScrollPhysics(), // 手動制御するため無効化
                      itemBuilder: (context, index) => _buildPageContent(index),
                    ),
          ),

          // ページめくりのナビゲーションボタン
          if (!_showMenu && !_isPageTurning)
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).size.height * 0.5,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 前のページへ
                  if (_currentPage > 0)
                    GestureDetector(
                      onTap: _turnToPreviousPage,
                      child: Container(
                        width: 40,
                        height: 60,
                        color: Colors.transparent,
                        child: Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white.withOpacity(0.3),
                          size: 24,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 40),

                  // 次のページへ
                  if (_currentPage < _book!.pages!.length - 1)
                    GestureDetector(
                      onTap: _turnToNextPage,
                      child: Container(
                        width: 40,
                        height: 60,
                        color: Colors.transparent,
                        child: Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white.withOpacity(0.3),
                          size: 24,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 40),
                ],
              ),
            ),

          // 上部メニュー - オーバーレイとして表示（表示/非表示の切り替えはアニメーション）
          if (_showMenu)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
                color: Colors.black.withOpacity(0.5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, // 高さを最小限に抑える
                  children: [
                    // 戻るボタン
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: const Text(
                        '戻る',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // タイトル表示
                    Text(
                      widget.args.title.isNotEmpty
                          ? widget.args.title
                          : _book!.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // 追加情報
                    Text(
                      '絵本ID: ${widget.args.bookId}' +
                          (widget.args.isTTS ? ' [読み聞かせモード]' : ''),
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    // ページ番号表示
                    const SizedBox(height: 8),
                    Text(
                      'ページ: ${_currentPage + 1}/${_book!.pages!.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    // 現在のBGM情報
                    if (_currentTrack != null)
                      Text(
                        '現在のBGM: ${_currentAudioPath?.split('/').last ?? '未設定'}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
              ),
            ),

          // 下部メニュー - オーバーレイとして表示（BGMボタンのみ）
          if (_showMenu)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(20),
                color: Colors.black.withOpacity(0.5),
                child: Column(
                  mainAxisSize: MainAxisSize.min, // 高さを最小限に抑える
                  children: [
                    // ナビゲーションボタン
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 最初に戻るボタン
                        ElevatedButton(
                          onPressed: _currentPage > 0 ? _restartBook : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          child: const Icon(
                            Icons.first_page,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),

                        // 前のページボタン
                        ElevatedButton(
                          onPressed:
                              _currentPage > 0 ? _turnToPreviousPage : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          child: const Icon(
                            Icons.navigate_before,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),

                        // 次のページボタン
                        ElevatedButton(
                          onPressed:
                              _currentPage < _book!.pages!.length - 1
                                  ? _turnToNextPage
                                  : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          child: const Icon(
                            Icons.navigate_next,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // BGMボタン
                    ElevatedButton(
                      onPressed: _toggleBackgroundMusic,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        'BGM: ${_bgmPlaying ? 'オン' : 'オフ'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 現在の音量表示
                    Text(
                      '現在の音量: ${(_volume * 100).toInt()}%',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),

          // 最後のページでレビューボタンを表示
          if (_isLastPage)
            Positioned(bottom: 20, right: 20, child: _buildReviewButton()),

          // ページ番号インジケーター
          if (!_showMenu && !_isPageTurning)
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_currentPage + 1} / ${_book!.pages!.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
