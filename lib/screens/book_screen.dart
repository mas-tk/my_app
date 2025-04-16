// lib/screens/book_screen.dart
import 'dart:io';
import 'dart:async'; // Timer用にimportを追加
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turn_page_transition/turn_page_transition.dart';
import '../models/book_models.dart';
import '../repositories/book_repository.dart';
import 'review_screen.dart';
import 'package:flutter/services.dart' show HapticFeedback;

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
  final VoidCallback? onDispose; // 破棄時に呼び出すコールバックを追加

  const BookScreen({
    Key? key,
    required this.args,
    this.onDispose, // onDisposeパラメータの追加
  }) : super(key: key);

  @override
  _BookScreenState createState() => _BookScreenState();
}

class _BookScreenState extends State<BookScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
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

  // 文字自動表示の設定
  bool _autoTextEnabled = true; // 自動表示のオン/オフ状態
  double _autoTextDelaySeconds = 1.5; // 自動表示の遅延（秒単位）

  // 最終ページ用のタップカウント
  int _lastPageTapCount = 0;

  // アニメーション関連の状態
  bool _isPageTurning = false;
  int _targetPage = 0;
  final Duration _pageTurnDuration = const Duration(milliseconds: 500);

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

  // 自動テキスト表示のタイマー
  Timer? _autoTextTimer;

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
      // 自動表示設定を読み込む
      await _loadAutoTextSettings();

      // デフォルトでサウンドを有効にする
      _soundEnabled = true;

      // 本データを先に読み込み、画面をできるだけ早く表示
      await _loadBookData();

      // 画面表示後、バックグラウンドでリソース初期化を続行
      if (mounted) {
        Future.microtask(() async {
          // BGMプレーヤーを初期設定
          await _setupPlayer();

          // ユーザーのお気に入り状態を取得
          await _loadUserPreferences();

          // 音楽設定を非同期で初期化
          if (mounted) {
            await Future.delayed(const Duration(milliseconds: 100));
            await _setupAudio();
          }
        });
      }

      // 最初のページ表示後に自動でテキストレイヤーを表示するタイマーをセット
      _scheduleAutoTextDisplay();
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

    // キャッシュをクリア
    _imageCache.clear();
    _imagePathCache.clear();

    // 音声を停止して解放
    try {
      _audioPlayer.stop();
    } catch (e) {
      debugPrint('Error stopping audio: $e');
    }

    _audioPlayer.dispose();
    _autoTextTimer?.cancel();

    // コールバックが設定されていれば、次のフレームで呼び出す
    if (widget.onDispose != null) {
      // FrameCallbackを使って安全にコールバックを呼び出す
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onDispose?.call();
      });
    }

    super.dispose();
  }

  // 自動表示設定の保存
  Future<void> _saveAutoTextSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auto_text_enabled', _autoTextEnabled);
      await prefs.setDouble('auto_text_delay_seconds', _autoTextDelaySeconds);
      print(
        '自動表示設定を保存しました: 有効=${_autoTextEnabled}, 遅延=${_autoTextDelaySeconds}秒',
      );
    } catch (e) {
      print('自動表示設定の保存に失敗しました: $e');
    }
  }

  // 自動表示設定の読み込み
  Future<void> _loadAutoTextSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _autoTextEnabled = prefs.getBool('auto_text_enabled') ?? true;
        _autoTextDelaySeconds =
            prefs.getDouble('auto_text_delay_seconds') ?? 1.5;
      });
      print(
        '自動表示設定を読み込みました: 有効=${_autoTextEnabled}, 遅延=${_autoTextDelaySeconds}秒',
      );
    } catch (e) {
      print('自動表示設定の読み込みに失敗しました: $e');
    }
  }

  // 自動テキスト表示のスケジュール
  void _scheduleAutoTextDisplay() {
    if (_book != null && _book!.pages != null && _book!.pages!.isNotEmpty) {
      // 既存のタイマーをキャンセル
      _autoTextTimer?.cancel();

      // 自動表示が無効の場合は何もしない
      if (!_autoTextEnabled) {
        print('自動表示は無効です - タイマーをスケジュールしません');
        return;
      }

      // 現在のページのページIDを取得
      final pageId = _book!.pages![_currentPage].pageId;

      // 既にテキストが表示されている場合はスケジュールしない
      if (_textVisibility[pageId] ?? false) {
        return;
      }

      // タイマーによる遅延表示
      final delayMs = (_autoTextDelaySeconds * 1000).toInt();
      print('タイマーをスケジュール: $_autoTextDelaySeconds秒後にテキストを表示');

      _autoTextTimer = Timer(Duration(milliseconds: delayMs), () {
        if (mounted) {
          setState(() {
            _textVisibility[pageId] = true;
          });
          print('自動表示タイマー実行: テキストを表示');
        }
      });
    }
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

        // リソース読み込みを非同期で行い、UIブロックを防ぐ
        // 最初のページだけ優先的にプリキャッシュ
        if (book.pages!.isNotEmpty) {
          final firstPage = book.pages![0];
          await _cacheImage(firstPage.baseImage);
          await _cacheImage(firstPage.textImage);

          // 残りは別の非同期処理で
          Future.microtask(() => _precacheImages());
        }
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
    try {
      final cachedPath = _imagePathCache[imagePath] ?? imagePath;

      if (_imageCache.containsKey(cachedPath)) {
        return _imageCache[cachedPath]!;
      }

      final image = _createImageWidget(cachedPath, imagePath);
      _imageCache[cachedPath] = image;
      return image;
    } catch (e) {
      print('Error getting image widget: $e');
      // エラー時のフォールバック表示
      return Container(
        color: Colors.grey[300],
        child: const Center(child: Icon(Icons.broken_image, size: 48)),
      );
    }
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

  // 音量のフェードアウト処理
  Future<void> _fadeOutAudio(Duration duration) async {
    if (!_bgmPlaying) return;

    try {
      // 現在の音量を保存
      final startVolume = _volume;
      final steps = 10; // フェードアウトのステップ数

      for (int i = steps; i >= 0; i--) {
        final fadeVolume = startVolume * i / steps;
        await _audioPlayer.setVolume(fadeVolume);
        await Future.delayed(
          Duration(milliseconds: duration.inMilliseconds ~/ steps),
        );
      }
    } catch (e) {
      debugPrint('フェードアウトエラー: $e');
    }
  }

  // 音量のフェードイン処理
  Future<void> _fadeInAudio(Duration duration) async {
    if (!_bgmPlaying) return;

    try {
      // 目標音量
      final targetVolume = _volume;
      final steps = 10; // フェードインのステップ数

      // 一旦音量を0に設定
      await _audioPlayer.setVolume(0);

      for (int i = 0; i <= steps; i++) {
        final fadeVolume = targetVolume * i / steps;
        await _audioPlayer.setVolume(fadeVolume);
        await Future.delayed(
          Duration(milliseconds: duration.inMilliseconds ~/ steps),
        );
      }

      // 最終的に目標音量に設定（念のため）
      await _audioPlayer.setVolume(targetVolume);
    } catch (e) {
      debugPrint('フェードインエラー: $e');
      // エラー時は直接目標音量に設定
      await _audioPlayer.setVolume(_volume);
    }
  }

  // ページに応じてBGMを確認・切り替える関数（フェード効果追加）
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
        // BGMを一旦停止（フェードアウト）
        final wasPlaying = _bgmPlaying;
        if (wasPlaying) {
          // フェードアウト（500ms）
          await _fadeOutAudio(const Duration(milliseconds: 500));
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

        // 再生中だった場合は再開（フェードイン）
        if (wasPlaying) {
          await _audioPlayer.resume();
          // フェードイン（1000ms）
          await _fadeInAudio(const Duration(milliseconds: 1000));
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

  // BGM再生（フェードイン）
  Future<void> _playBackgroundMusic() async {
    try {
      debugPrint('BGM再生開始試行');

      // 音量を一旦0に設定
      final savedVolume = _volume;
      await _audioPlayer.setVolume(0);

      // 再生開始
      await _audioPlayer.resume();
      setState(() {
        _bgmPlaying = true;
      });

      // フェードイン
      await _fadeInAudio(const Duration(milliseconds: 1000));

      debugPrint('BGM再生開始');
    } catch (e) {
      debugPrint('BGM再生エラー: $e');

      // 再試行
      try {
        await Future.delayed(const Duration(milliseconds: 500));
        debugPrint('BGM再生再試行');
        await _audioPlayer.resume();
        await _audioPlayer.setVolume(_volume); // エラー時は直接設定
        setState(() {
          _bgmPlaying = true;
        });
      } catch (retryError) {
        debugPrint('BGM再生再試行エラー: $retryError');
      }
    }
  }

  // BGM一時停止（フェードアウト）
  Future<void> _stopBackgroundMusic() async {
    try {
      debugPrint('BGM停止試行');

      // フェードアウト
      await _fadeOutAudio(const Duration(milliseconds: 500));

      // 停止
      await _audioPlayer.pause();
      setState(() {
        _bgmPlaying = false;
      });

      debugPrint('BGM停止完了');
    } catch (e) {
      debugPrint('BGM停止エラー: $e');
      // エラー時は直接停止
      await _audioPlayer.pause();
      setState(() {
        _bgmPlaying = false;
      });
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

  // 音量を上げるメソッド
  Future<void> _increaseVolume() async {
    if (_volume < 1.0) {
      try {
        final newVolume = (_volume + 0.1).clamp(0.0, 1.0);
        await _audioPlayer.setVolume(newVolume);
        setState(() {
          _volume = newVolume;
        });
        debugPrint('音量を上げました: $_volume');
      } catch (e) {
        debugPrint('音量調整エラー: $e');
      }
    }
  }

  // 音量を下げるメソッド
  Future<void> _decreaseVolume() async {
    if (_volume > 0.0) {
      try {
        final newVolume = (_volume - 0.1).clamp(0.0, 1.0);
        await _audioPlayer.setVolume(newVolume);
        setState(() {
          _volume = newVolume;
        });
        debugPrint('音量を下げました: $_volume');
      } catch (e) {
        debugPrint('音量調整エラー: $e');
      }
    }
  }

  // 自動表示の有効/無効を切り替えるメソッド
  void _toggleAutoTextDisplay() {
    setState(() {
      _autoTextEnabled = !_autoTextEnabled;
    });

    // 設定を保存
    _saveAutoTextSettings();

    // 自動表示の状態変更時の処理
    if (_autoTextEnabled) {
      // 有効になった場合、現在ページの自動表示をスケジュールし直す
      _scheduleAutoTextDisplay();
    } else {
      // 無効になった場合、タイマーをキャンセル
      _autoTextTimer?.cancel();
    }

    // デバッグログ
    print('自動表示設定を変更しました: $_autoTextEnabled');
  }

  // 自動表示の遅延時間を変更するメソッド
  void _changeAutoTextDelay(double newDelaySeconds) {
    setState(() {
      _autoTextDelaySeconds = newDelaySeconds;
    });

    // 設定を保存
    _saveAutoTextSettings();

    // 現在ページの自動表示をスケジュールし直す
    if (_autoTextEnabled) {
      _scheduleAutoTextDisplay();
    }
  }

  // ページを前に移動する
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

  // ページを次に移動する
  Future<void> _turnToNextPage() async {
    if (_book != null &&
        _currentPage < _book!.pages!.length - 1 &&
        !_isPageTurning) {
      // ページめくり時のバイブレーション
      await _generateHapticFeedback();

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

  // 最初のページに戻る
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

  // タッチ開始時のハンドラー
  void _handleTouchStart(DragStartDetails details) {
    _touchStartY = details.globalPosition.dy;
  }

  // 垂直方向スワイプ終了時のハンドラー
  void _handleVerticalSwipeEnd(DragEndDetails details) {
    final touchEndY = details.velocity.pixelsPerSecond.dy;

    // スワイプの強さが一定以上ある場合に反応
    if (touchEndY.abs() > 200) {
      setState(() {
        // 現在の状態と逆にトグル
        _showMenu = !_showMenu;
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

  // コメント画面を開くメソッド
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

  // コメントボタンを表示するウィジェット
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
              'コメントを書く',
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

  // ページタップの処理 - 最終ページかそれ以外かで分岐
  Future<void> _toggleTextLayer(String pageId) async {
    if (_isLastPage) {
      // 現在のテキスト表示状態を取得
      bool isCurrentlyVisible = _textVisibility[pageId] ?? false;

      // 自動表示の場合、最初のタップは既に表示状態なので、次の状態に進める
      if (isCurrentlyVisible && _lastPageTapCount == 0) {
        // 既に表示されていて、まだタップされていない場合は2に
        setState(() {
          _lastPageTapCount = 2;
          // テキスト表示状態は変更しない
        });
        // コメントボタン表示に対応するバイブレーション
        await _generateHapticFeedback();
      } else {
        // 通常の3状態循環
        int newTapCount = (_lastPageTapCount + 1) % 3;
        setState(() {
          _lastPageTapCount = newTapCount;
          // 0: テキスト非表示、1: テキスト表示、2: テキスト表示+コメントボタン表示
          _textVisibility[pageId] = newTapCount == 1 || newTapCount == 2;
        });
        // タップカウントが 2 のときにバイブレーションさせる (コメントボタン表示時)
        if (newTapCount == 2) {
          await _generateHapticFeedback();
        }
      }
    } else {
      // 通常のページでは、単純に表示状態を切り替え
      setState(() {
        _textVisibility[pageId] = !(_textVisibility[pageId] ?? false);
      });
    }
  }

  // ページめくり時の処理
  void _handlePageChanged(int pageIndex) {
    setState(() {
      _currentPage = pageIndex;

      // 最後のページかどうかをチェック
      _isLastPage = (_book != null && pageIndex == _book!.pages!.length - 1);

      // 最終ページに入る場合はタップカウントをリセット
      if (_isLastPage) {
        _lastPageTapCount = 0;

        // 最終ページに入る時はテキストを初期状態（非表示）に
        if (_book != null &&
            _book!.pages != null &&
            pageIndex < _book!.pages!.length) {
          final pageId = _book!.pages![pageIndex].pageId;
          _textVisibility[pageId] = false;
        }
      }
    });

    // ページ変更時にBGMの確認と切り替えを行う
    _checkAndUpdateBGM(pageIndex);

    // 次のページと前のページの画像をプリキャッシュ
    _cacheSurroundingPages(pageIndex);

    // 新しいページに移動したら自動テキスト表示タイマーをセット
    // ただし自動表示が有効な場合のみ
    if (_autoTextEnabled) {
      _scheduleAutoTextDisplay();
    }

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
              // 自動表示（スケジュール）時は600ms、手動（タップ）では200msで適用
              duration: const Duration(milliseconds: 600), // アニメーション時間を延長
              child: _getImageWidget(page.textImage),
            ),
          ],
        ),
      ),
    );
  }

  // ヘッダーオーバーレイを構築
  Widget _buildHeaderOverlay() {
    return AnimatedOpacity(
      opacity: _showMenu ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Visibility(
        visible: _showMenu,
        child: Container(
          width: double.infinity, // 画面全体の幅を使用
          padding: EdgeInsets.fromLTRB(
            16,
            MediaQuery.of(context).padding.top + 8,
            16,
            8,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.95), // より暗い背景色
                Colors.black.withOpacity(0.85), // より暗い背景色
                Colors.black.withOpacity(0.80),
                Colors.transparent,
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 本の情報
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.args.title.isNotEmpty
                              ? widget.args.title
                              : _book?.title ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '${_currentPage + 1} / ${_book?.pages?.length ?? 0} ページ',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            // 修正③: BGMファイル名の表示位置を改善
                            if (_currentAudioPath != null)
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 20.0,
                                ), // 間隔を広げる
                                child: Row(
                                  children: [
                                    const Text(
                                      'BGM: ',
                                      style: TextStyle(
                                        color: Colors.white60,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      _getAudioFileName(_currentAudioPath!),
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // オーディオファイル名を取得
  String _getAudioFileName(String path) {
    // パスからファイル名を抽出
    final fileName = path.split('/').last;
    // 拡張子を除去
    return fileName.split('.').first;
  }

  // フッターオーバーレイを構築
  Widget _buildFooterOverlay() {
    return AnimatedOpacity(
      opacity: _showMenu ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Visibility(
        visible: _showMenu,
        child: Container(
          width: double.infinity, // 画面全体の幅を使用
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withOpacity(0.95), // より暗い背景色
                Colors.black.withOpacity(0.85), // より暗い背景色
                Colors.black.withOpacity(0.80),
                Colors.transparent,
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Single row of controls (previous/next page buttons removed)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 閉じるボタン
                  _buildControlButton(
                    icon: Icons.exit_to_app,
                    label: '絵本を閉じる',
                    onPressed: () => Navigator.pop(context),
                  ),
                  // 最初のページに戻るボタン
                  _buildControlButton(
                    icon: Icons.first_page,
                    label: '最初に戻る',
                    onPressed: _currentPage > 0 ? _restartBook : null,
                    isEnabled: _currentPage > 0,
                  ),
                  // 音量調整ボタン
                  _buildControlButton(
                    icon:
                        _soundEnabled
                            ? (_volume > 0.5
                                ? Icons.volume_up
                                : Icons.volume_down)
                            : Icons.volume_off,
                    label: _soundEnabled ? '音量' : '音声オフ',
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (BuildContext context) {
                          return StatefulBuilder(
                            builder: (
                              BuildContext context,
                              StateSetter setModalState,
                            ) {
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: const BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(20),
                                    topRight: Radius.circular(20),
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        TextButton.icon(
                                          icon: Icon(
                                            _soundEnabled
                                                ? Icons.volume_up
                                                : Icons.volume_off,
                                            color: Colors.white,
                                          ),
                                          label: Text(
                                            _soundEnabled ? 'サウンドオン' : 'サウンドオフ',
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                          onPressed: () {
                                            _toggleBackgroundMusic();
                                            setModalState(() {});
                                            setState(() {});
                                          },
                                        ),
                                        // 閉じるボタン
                                        TextButton(
                                          child: const Text(
                                            '閉じる',
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                          onPressed:
                                              () => Navigator.pop(context),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.volume_down,
                                          color: Colors.white,
                                        ),
                                        Expanded(
                                          child: Slider(
                                            value: _volume,
                                            min: 0.0,
                                            max: 1.0,
                                            activeColor: Colors.white,
                                            inactiveColor: Colors.white24,
                                            onChanged: (value) async {
                                              await _audioPlayer.setVolume(
                                                value,
                                              );
                                              setModalState(() {
                                                _volume = value;
                                              });
                                              setState(() {
                                                _volume = value;
                                              });
                                            },
                                          ),
                                        ),
                                        const Icon(
                                          Icons.volume_up,
                                          color: Colors.white,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                  // 文字表示速度調整ボタン
                  _buildControlButton(
                    icon: Icons.text_fields,
                    label: '文字表示速度',
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (BuildContext context) {
                          return StatefulBuilder(
                            builder: (
                              BuildContext context,
                              StateSetter setModalState,
                            ) {
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: const BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(20),
                                    topRight: Radius.circular(20),
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          '文字表示速度',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        // 閉じるボタン
                                        TextButton(
                                          child: const Text(
                                            '閉じる',
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                          onPressed:
                                              () => Navigator.pop(context),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    // 自動表示のON/OFFスイッチ
                                    SwitchListTile(
                                      title: const Text(
                                        '自動表示',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      value: _autoTextEnabled,
                                      activeColor: Colors.amber,
                                      onChanged: (value) {
                                        setModalState(() {
                                          _autoTextEnabled = value;
                                        });
                                        setState(() {
                                          _autoTextEnabled = value;
                                        });
                                        _toggleAutoTextDisplay();
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                    // 自動表示の遅延時間スライダー（ONの場合のみ表示）
                                    if (_autoTextEnabled) ...[
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 16.0,
                                        ),
                                        child: Text(
                                          '表示までの時間',
                                          style: TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8.0,
                                        ),
                                        child: Row(
                                          children: [
                                            const Text(
                                              '0秒',
                                              style: TextStyle(
                                                color: Colors.white70,
                                              ),
                                            ),
                                            Expanded(
                                              child: Slider(
                                                value: _autoTextDelaySeconds,
                                                min: 0.0,
                                                max: 5.0,
                                                divisions: 10,
                                                activeColor: Colors.amber,
                                                inactiveColor: Colors.white24,
                                                label:
                                                    "${_autoTextDelaySeconds.toStringAsFixed(1)}秒",
                                                onChanged: (value) {
                                                  setModalState(() {
                                                    _autoTextDelaySeconds =
                                                        value;
                                                  });
                                                },
                                                onChangeEnd: (value) {
                                                  setState(() {
                                                    _autoTextDelaySeconds =
                                                        value;
                                                  });
                                                  _changeAutoTextDelay(value);
                                                },
                                              ),
                                            ),
                                            const Text(
                                              '5秒',
                                              style: TextStyle(
                                                color: Colors.white70,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '現在の設定: ${_autoTextDelaySeconds.toStringAsFixed(1)}秒',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 機能ボタンを作成
  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool isEnabled = true,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            icon,
            color: isEnabled ? Colors.white : Colors.white38,
            size: 28,
          ),
          onPressed: onPressed,
        ),
        Text(
          label,
          style: TextStyle(
            color: isEnabled ? Colors.white70 : Colors.white38,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _book == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        bottomNavigationBar: null, // 明示的にnull
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: null, // 不要なら削除
      bottomNavigationBar: null, // 明示的にnull
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: Stack(
        children: [
          // メインのコンテンツ
          GestureDetector(
            // メニュー表示中はジェスチャー無効
            onVerticalDragStart: _handleTouchStart,
            onVerticalDragEnd: (details) {
              // 修正①: メニュー表示・非表示に関わらず上下スワイプで表示状態を切り替え
              if (details.velocity.pixelsPerSecond.dy.abs() > 200) {
                setState(() {
                  _showMenu = !_showMenu;
                });
              }
            },
            onHorizontalDragEnd: _showMenu ? null : _handleHorizontalSwipe,
            // メニュー表示中は一切タップイベントを捕捉しない
            onTap:
                _showMenu
                    ? () {
                      setState(() {
                        _showMenu = false;
                      });
                    }
                    : null,
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

          // メニュー表示中のタップを捕捉するための透明なオーバーレイ
          if (_showMenu)
            Positioned.fill(
              child: GestureDetector(
                // 透明な全画面サイズのオーバーレイ
                behavior: HitTestBehavior.opaque, // 重要: 透明でもタップを捕捉
                onTap: () {
                  setState(() {
                    _showMenu = false;
                  });
                },
                // 修正①: 上下スワイプもメニュー非表示に対応
                onVerticalDragEnd: (details) {
                  if (details.velocity.pixelsPerSecond.dy.abs() > 200) {
                    setState(() {
                      _showMenu = false;
                    });
                  }
                },
                child: Container(color: Colors.transparent),
              ),
            ),

          // 上部オーバーレイメニュー
          _buildHeaderOverlay(),

          // 下部オーバーレイメニュー
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildFooterOverlay(),
          ),

          // ページめくりのナビゲーションボタン（中央部分にのみ表示）
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

          // 最後のページでコメントボタンを表示
          if (_isLastPage && _lastPageTapCount == 2)
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
