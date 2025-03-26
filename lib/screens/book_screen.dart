// lib/screens/book_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/book_models.dart';
import '../repositories/book_repository.dart';
import 'review_screen.dart'; // レビュー画面をインポート

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

class _BookScreenState extends State<BookScreen> with WidgetsBindingObserver {
  // レポジトリ
  final BookRepository _bookRepository = BookRepository();

  // ページコントローラー
  late PageController _pageController;

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

    // 初期化を非同期で安全に行う
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadBookData();

      // BGMプレーヤーを初期設定
      await _setupPlayer();

      // 音楽設定を非同期で初期化
      await _setupAudio();

      // 事前に画像パスを解決しておく
      await _precacheImages();

      // ユーザーのお気に入り状態を取得
      _loadUserPreferences();
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

      debugPrint('Audio player setup completed');
    } catch (e) {
      debugPrint('Error setting up audio player: $e');
    }
  }

  // 音楽の初期設定
  Future<void> _setupAudio() async {
    if (_book?.audio == null) return;

    try {
      // ボリューム設定
      await _audioPlayer.setVolume(_volume);

      // 初期ページに対応するトラックを取得
      _currentTrack = _book!.audio!.getTrackForPage(_currentPage + 1);

      if (_currentTrack != null) {
        // ローカルパスを取得
        final localPath = await _bookRepository.getAssetPath(
          _currentTrack!.assetPath,
        );
        _currentAudioPath = localPath;

        debugPrint(
          'Initial audio: $_currentAudioPath for page: ${_currentPage + 1}',
        );

        // プレーヤーの初期化
        try {
          final isLocalFile =
              !localPath.startsWith('assets/') && !localPath.startsWith('http');

          if (isLocalFile) {
            // ローカルファイルの場合
            await _audioPlayer.setSourceDeviceFile(localPath);
          } else {
            // アセットの場合 - assets/ の重複を解消
            final String normalizedPath =
                localPath.startsWith('assets/')
                    ? localPath.substring(7) // 'assets/'の部分を削除
                    : localPath;

            debugPrint('Loading audio asset: $normalizedPath');
            await _audioPlayer.setSourceAsset(normalizedPath);
          }

          debugPrint('Audio source set successfully');
        } catch (e) {
          debugPrint('Error setting audio source: $e');
          // フォールバック - 基本的なオーディオファイルを試す
          try {
            await _audioPlayer.setSourceAsset('audio/sample.mp3');
            _currentAudioPath = 'audio/sample.mp3';
            debugPrint('Fallback to sample audio file');
          } catch (fallbackError) {
            debugPrint('Error setting fallback audio source: $fallbackError');
          }
        }

        // 自動再生（soundEnabled が true の場合）
        if (_soundEnabled) {
          await _playBackgroundMusic();
        }
      }
    } catch (e) {
      debugPrint('Error setting up audio: $e');
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
        final isLocalFile =
            !localPath.startsWith('assets/') && !localPath.startsWith('http');

        if (isLocalFile) {
          // ローカルファイルの場合
          await _audioPlayer.setSourceDeviceFile(localPath);
        } else {
          // アセットの場合 - assets/ の重複を解消
          final String normalizedPath =
              localPath.startsWith('assets/')
                  ? localPath.substring(7) // 'assets/'の部分を削除
                  : localPath;

          debugPrint('Changing audio to asset: $normalizedPath');
          await _audioPlayer.setSourceAsset(normalizedPath);
        }

        _currentTrack = newTrack;

        debugPrint(
          'Changing audio to: ${newTrack.assetPath} for page: $actualPageNumber',
        );

        // 再生中だった場合は再開
        if (wasPlaying) {
          await _audioPlayer.resume();
          setState(() {
            _bgmPlaying = true;
          });
        }
      } catch (e) {
        debugPrint('Error changing audio source: $e');
      } finally {
        _isChangingTrack = false;
      }
    }
  }

  // BGM再生
  Future<void> _playBackgroundMusic() async {
    try {
      await _audioPlayer.resume();
      setState(() {
        _bgmPlaying = true;
      });
      debugPrint('Background music started playing');
    } catch (e) {
      debugPrint('Error playing background music: $e');
    }
  }

  // BGM一時停止
  Future<void> _stopBackgroundMusic() async {
    try {
      await _audioPlayer.pause();
      setState(() {
        _bgmPlaying = false;
      });
      debugPrint('Background music paused');
    } catch (e) {
      debugPrint('Error stopping background music: $e');
    }
  }

  // BGMのオン/オフを切り替え
  Future<void> _toggleBackgroundMusic() async {
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

  // 最初のページに戻る
  void _restartBook() {
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
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
          // メインのコンテンツ - ページビュー
          GestureDetector(
            onVerticalDragStart: _handleTouchStart,
            onVerticalDragEnd: _handleVerticalSwipeEnd,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _book!.pages!.length,
              onPageChanged: _handlePageChanged,
              pageSnapping: true,
              allowImplicitScrolling: true,
              physics: const ClampingScrollPhysics(),
              itemBuilder: (context, index) {
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
              },
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
                    // BGMボタン - シンプル化
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
        ],
      ),
    );
  }
}
