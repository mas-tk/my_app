// lib/screens/book_overview_screen.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, HapticFeedback;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/book_models.dart';
import '../repositories/book_repository.dart';
import '../services/file_storage_service.dart'; // Import the file storage service
import 'book_screen.dart';
import 'package:audioplayers/audioplayers.dart';

class BookOverviewScreen extends StatefulWidget {
  const BookOverviewScreen({Key? key}) : super(key: key);

  @override
  _BookOverviewScreenState createState() => _BookOverviewScreenState();
}

class _BookOverviewScreenState extends State<BookOverviewScreen>
    with SingleTickerProviderStateMixin {
  // Constants for file names
  static const String FAVORITE_BOOKS_FILE = 'favorite_books.json';
  static const String FAVORITE_BOOKS_ASSET = 'assets/data/favorite_books.json';

  // Add FileStorageService instance
  final FileStorageService _fileStorageService = FileStorageService();

  final BookRepository _bookRepository = BookRepository();
  Book? _book;
  bool _isLoading = true;
  bool _isDownloaded = false;
  bool _isDownloading = false;
  bool _isFavorite = false;

  // Animation properties
  bool _isZoomed = false;
  bool _isAnimating = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

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

    // Rotation animation
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

    // Slide animation
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.02),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    // Opacity animation
    _opacityAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
    );

    // Check favorite status after initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFavoriteStatus();
    });
  }

  // Load favorite status
  Future<void> _loadFavoriteStatus() async {
    if (_book != null) {
      await _checkFavoriteStatus();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load book data after route arguments are available
    _loadBookData().then((_) {
      if (_book != null) {
        _checkFavoriteStatus();
      }
    });
  }

  // Load book data
  Future<void> _loadBookData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get route arguments
      final Map<String, dynamic> args =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      final String bookId = args['bookId'] as String;

      // Get book data
      final book = await _bookRepository.getBookById(bookId);

      if (book != null) {
        setState(() {
          _book = book;
        });

        // Check if book is downloaded
        final isDownloaded = await _bookRepository.isBookDownloaded(bookId);
        setState(() {
          _isDownloaded = isDownloaded;
        });
      }
    } catch (e) {
      print('Error loading book data: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('本データの読み込みに失敗しました: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Download book
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

  // _navigateToBookScreen メソッドの修正版
  Future<void> _navigateToBookScreen() async {
    // 拡大表示がまだなら拡大表示
    if (!_isZoomed) {
      _toggleCoverZoom();
      return;
    }

    // 効果音再生と同時に、バックグラウンドで最初のページの画像をプリロードしておく
    if (_book != null && _book!.pages != null && _book!.pages!.isNotEmpty) {
      final firstPage = _book!.pages![0];
      // 非同期で画像をプリロード - 完了を待たない
      _bookRepository.getAssetPath(firstPage.baseImage).then((path) {
        if (path != null) {
          precacheImage(
            path.startsWith('assets/')
                ? AssetImage(path)
                : FileImage(File(path)) as ImageProvider,
            context,
          );
        }
      });
    }

    // バイブレーション実行
    await _generateHapticFeedback();

    // 効果音再生（ページめくり音）
    final AudioPlayer soundPlayer = AudioPlayer();
    try {
      await soundPlayer.setSourceAsset('page_flip.mp3');
      await soundPlayer.resume();

      // 1秒後に効果音を停止
      Future.delayed(const Duration(seconds: 1), () {
        soundPlayer.stop();
        soundPlayer.dispose();
      });
    } catch (e) {
      print('Error playing sound: $e');
    }

    // ★ 直接 PageRouteBuilder を使う代わりに pushNamed を使用
    Navigator.of(context).pushNamed(
      '/book',
      arguments: BookScreenArguments(
        bookId: _book!.id,
        title: _book!.title,
        isTTS: false,
      ),
    );
  }

  // Check if book is in favorites
  Future<void> _checkFavoriteStatus() async {
    if (_book == null) return;

    try {
      // Ensure local favorites file exists
      await _fileStorageService.ensureLocalJsonFileExists(
        FAVORITE_BOOKS_FILE,
        FAVORITE_BOOKS_ASSET,
      );

      // Read favorites data from local file
      final favoritesData = await _fileStorageService.readJsonFromFile(
        FAVORITE_BOOKS_FILE,
      );

      if (favoritesData != null) {
        // Check if this book is in favorites
        final List<dynamic> favoriteBooks = favoritesData as List;
        final isFavorite = favoriteBooks.any(
          (favorite) => favorite['bookId'] == _book!.id,
        );

        print('Book ${_book!.id} favorite status: $isFavorite');

        if (mounted) {
          setState(() {
            _isFavorite = isFavorite;
          });
        }

        // Also update SharedPreferences for compatibility
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('favorite_books', jsonEncode(favoriteBooks));
      } else {
        // Initialize favorites data if not present
        await _initializeFavoriteData();
      }
    } catch (e) {
      print('Error checking favorite status: $e');
    }
  }

  // Initialize favorite data from assets if needed
  Future<void> _initializeFavoriteData() async {
    try {
      print('Initializing favorite data for book ${_book?.id}');

      // Load favorite books from asset
      final List<Map<String, dynamic>> favoriteBooks =
          await _loadFavoriteBooks();

      // Check if this book is a favorite
      final isFavorite = favoriteBooks.any(
        (favorite) => favorite['bookId'] == _book!.id,
      );

      print('Book ${_book!.id} initial favorite status: $isFavorite');

      if (mounted) {
        setState(() {
          _isFavorite = isFavorite;
        });
      }

      // Save to local file and SharedPreferences
      await _saveFavoriteBooks(favoriteBooks);
    } catch (e) {
      print('Error initializing favorite data: $e');
    }
  }

  // Toggle favorite status - asyncに変更
  Future<void> _toggleFavorite() async {
    if (_book == null) return;

    try {
      // Toggle state immediately for responsive UI
      setState(() {
        _isFavorite = !_isFavorite;
      });

      if (_isFavorite) {
        // バイブレーション実行
        await _generateHapticFeedback();

        await _addToFavorites();
      } else {
        await _removeFromFavorites();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isFavorite
                ? '「${_book!.title}」をお気に入りに追加しました'
                : '「${_book!.title}」をお気に入りから削除しました',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      print('Error toggling favorite: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('お気に入り操作に失敗しました: $e')));
    }
  }

  // Load favorite books from file or asset
  Future<List<Map<String, dynamic>>> _loadFavoriteBooks() async {
    try {
      // Check local file first
      final favoritesData = await _fileStorageService.readJsonFromFile(
        FAVORITE_BOOKS_FILE,
      );

      if (favoritesData != null) {
        return (favoritesData as List).cast<Map<String, dynamic>>();
      }

      // Fallback to asset
      final jsonString = await rootBundle.loadString(FAVORITE_BOOKS_ASSET);
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error loading favorite books: $e');
      return [];
    }
  }

  // Add current book to favorites
  Future<void> _addToFavorites() async {
    try {
      // Get current favorites
      final favoriteBooks = await _loadFavoriteBooks();

      // Check if book already exists
      final existingIndex = favoriteBooks.indexWhere(
        (item) => item['bookId'] == _book!.id,
      );

      if (existingIndex >= 0) {
        // Update existing entry
        favoriteBooks[existingIndex] = {
          'id': favoriteBooks[existingIndex]['id'],
          'bookId': _book!.id,
          'registeredAt': DateTime.now().toIso8601String(),
        };
      } else {
        // Add new entry
        final newFavorite = {
          'id': 'fav${DateTime.now().millisecondsSinceEpoch}',
          'bookId': _book!.id,
          'registeredAt': DateTime.now().toIso8601String(),
        };
        favoriteBooks.add(newFavorite);
      }

      // Save updated list
      await _saveFavoriteBooks(favoriteBooks);
    } catch (e) {
      print('Error adding to favorites: $e');
      rethrow;
    }
  }

  // Remove book from favorites
  Future<void> _removeFromFavorites() async {
    try {
      // Get current favorites
      final favoriteBooks = await _loadFavoriteBooks();

      // Remove book
      final newList =
          favoriteBooks.where((item) => item['bookId'] != _book!.id).toList();

      // Save updated list
      await _saveFavoriteBooks(newList);
    } catch (e) {
      print('Error removing from favorites: $e');
      rethrow;
    }
  }

  // Save favorites to both file and SharedPreferences
  Future<void> _saveFavoriteBooks(
    List<Map<String, dynamic>> favoriteBooks,
  ) async {
    try {
      // Save to local file
      await _fileStorageService.writeJsonToFile(
        FAVORITE_BOOKS_FILE,
        favoriteBooks,
      );

      // Also update SharedPreferences for compatibility
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(favoriteBooks);
      await prefs.setString('favorite_books', jsonString);

      print('Favorite books saved successfully');
    } catch (e) {
      print('Error saving favorite books: $e');
      rethrow;
    }
  }

  // The rest of the methods remain the same...
  void _toggleCoverZoom() {
    if (_isAnimating) return;

    setState(() {
      _isAnimating = true;

      if (_isZoomed) {
        _animationController.reverse().then((_) {
          if (mounted) {
            setState(() {
              _isZoomed = false;
            });
          }
        });
      } else {
        _isZoomed = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _animationController.forward();
        });
      }
    });
  }

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
              ImageProvider imageProvider;

              if (imagePath.startsWith('assets/')) {
                imageProvider = AssetImage(imagePath);
              } else if (!imagePath.startsWith('http')) {
                imageProvider = FileImage(File(imagePath));
              } else {
                imageProvider = AssetImage(coverPath);
              }

              return ClipRect(
                child: Image(
                  image: imageProvider,
                  width:
                      MediaQuery.of(context).size.width *
                      0.7, // 拡大 (0.6 -> 0.7)
                  height: 240, // 高さを大きく (180 -> 240)
                  fit: BoxFit.contain,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // お気に入りボタンのウィジェット
  Widget _buildFavoriteButton() {
    // 画面サイズを取得
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return GestureDetector(
      onTap: _toggleFavorite,
      child: Container(
        width: screenWidth * 0.15, // 画面幅の10%
        height: screenHeight * 0.15, // 画面高さの10%
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color:
              _isFavorite ? Colors.amber.withOpacity(0.05) : Colors.transparent,
          boxShadow:
              _isFavorite
                  ? [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.08),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ]
                  : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset(
            _isFavorite ? 'assets/bookmark.png' : 'assets/bookmark_off.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  // Genre tag widget
  Widget _buildGenreTag(String genre) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 6,
      ), // 垂直方向のパディングを小さく
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        genre,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 12, // フォントサイズを小さく
        ),
      ),
    );
  }

  // Star rating widget
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
            style: TextStyle(color: Color(0xFFFFD700), fontSize: 20), // サイズを小さく
          ),
        ),
        if (hasHalfStar)
          const Text(
            '★',
            style: TextStyle(color: Color(0xFFFFD700), fontSize: 20), // サイズを小さく
          ),
        ...List.generate(
          emptyStars,
          (index) => const Text(
            '★',
            style: TextStyle(color: Color(0xFF444444), fontSize: 20), // サイズを小さく
          ),
        ),
      ],
    );
  }

  // 拡大表示オーバーレイウィジェット
  Widget _buildZoomedOverlay() {
    // Screen size
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: GestureDetector(
            onTap: _toggleCoverZoom, // タップで閉じる
            onHorizontalDragEnd: (details) {
              // スワイプの方向を判定
              if (details.primaryVelocity != null) {
                if (details.primaryVelocity! > 0) {
                  // 左スワイプ - 拡大表示を閉じる
                  _toggleCoverZoom();
                } else if (details.primaryVelocity! < 0) {
                  // 右スワイプ - 本の画面へ移動
                  _navigateToBookScreen();
                }
              }
            },
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

                  // 拡大表紙（クリックで本画面へ）
                  Expanded(
                    child: GestureDetector(
                      onTap: _navigateToBookScreen,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
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
                              ImageProvider imageProvider;

                              if (imagePath.startsWith('assets/')) {
                                imageProvider = AssetImage(imagePath);
                              } else if (!imagePath.startsWith('http')) {
                                imageProvider = FileImage(File(imagePath));
                              } else {
                                imageProvider = AssetImage(
                                  _book!.coverAssetPath,
                                );
                              }

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
                  ),

                  // 読むボタン
                  Padding(
                    padding: const EdgeInsets.only(bottom: 40.0, top: 20.0),
                    child: AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, 50 * (1 - _opacityAnimation.value)),
                          child: Opacity(
                            opacity: _opacityAnimation.value,
                            child: child,
                          ),
                        );
                      },
                      child: GestureDetector(
                        onTap: _navigateToBookScreen,
                        child: Container(
                          width: screenWidth * 0.30,
                          height: screenHeight * 0.15,

                          decoration: const BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage('assets/button-frame-on.png'),
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

    // Screen size
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // ナビゲーションバーの高さを考慮（およそ56dp）
    final bottomPadding = MediaQuery.of(context).padding.bottom + 56;

    return Scaffold(
      backgroundColor: Colors.black,
      // スワイプして戻る機能を追加
      body: GestureDetector(
        // 左から右へのスワイプを検出
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
            // 右方向へのスワイプ
            Navigator.pop(context); // 前の画面に戻る
          }
        },
        child: Stack(
          children: [
            // Background
            Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/wooden-frame-background.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
              child: SafeArea(
                // SafeAreaで下部のパディングを含めない（ナビゲーションバーはアプリ独自のもののため）
                bottom: false,
                child: Column(
                  children: [
                    // 絵本タイトルと表紙（画面上部）- 高さ固定
                    Container(
                      height: screenHeight * 0.42, // タイトル削除のため高さを増加
                      width: double.infinity,
                      padding: const EdgeInsets.all(15), // パディングを小さく
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
                              // Book cover - 拡大 (タイトル削除)
                              _buildCoverImage(_book!.coverAssetPath),
                              // タイトル削除
                            ],
                          ),
                        ),
                      ),
                    ),

                    // ジャンルタグとレビュー情報（中央部分）- ジャンルタグは横スクロール可能に
                    Container(
                      height: screenHeight * 0.14, // 少し小さく調整（16% → 14%）
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min, // 必要最小限の高さに
                        children: [
                          // Genre tags - 横スクロール可能に
                          if (_book!.genres != null &&
                              _book!.genres!.isNotEmpty)
                            Container(
                              height: 60, // 高さを増加（40 -> 60）- 2行分確保
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children:
                                      _book!.genres!.map((genre) {
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            right: 8.0,
                                            bottom: 8.0, // 下部にも余白を追加して行間を確保
                                          ),
                                          child: _buildGenreTag(genre),
                                        );
                                      }).toList(),
                                ),
                              ),
                            ),

                          const SizedBox(height: 12), // 間隔を小さく
                          // Views and rating
                          if (_book!.views != null &&
                              _book!.rating != null &&
                              _book!.comments != null)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Views
                                Row(
                                  children: [
                                    const Text(
                                      '👁️',
                                      style: TextStyle(fontSize: 14), // 小さく
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      _book!.views.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14, // 小さく
                                      ),
                                    ),
                                  ],
                                ),

                                // Star rating
                                _buildRatingStars(_book!.rating!),

                                // Comments
                                Row(
                                  children: [
                                    const Text(
                                      '💬',
                                      style: TextStyle(fontSize: 14), // 小さく
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      _book!.comments.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14, // 小さく
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),

                    // 説明欄 - スクロール可能セクション
                    if (_book!.summary != null)
                      Container(
                        height: screenHeight * 0.12, // 高さを縮小（0.16 -> 0.12）
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF8B4513),
                              width: 2,
                            ),
                          ),
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              _book!.summary!,
                              style: const TextStyle(fontSize: 13, height: 1.4),
                            ),
                          ),
                        ),
                      ),

                    // ダウンロードステータス表示 - 別コンテナに分割 (修正: iOS対応)
                    Container(
                      height: screenHeight * 0.03, // 高さを固定
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      margin: const EdgeInsets.symmetric(
                        vertical: 3,
                        horizontal: 10,
                      ),
                      child: Center(
                        child:
                            _isDownloaded
                                ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                        size: 18,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'ダウンロード済み',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                : _isDownloading
                                ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'ダウンロード中...',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                : ElevatedButton.icon(
                                  onPressed: _downloadBook,
                                  icon: const Icon(Icons.download, size: 16),
                                  label: const Text(
                                    'オフライン読書用にダウンロード',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                  ),
                                ),
                      ),
                    ),
                    // 読むボタンとお気に入りボタンの親コンテナ (修正: iOS対応)
                    Container(
                      height: screenHeight * 0.15, // 高さを小さく (0.14 -> 0.10)
                      margin: const EdgeInsets.only(top: 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // スペース
                          SizedBox(width: screenWidth * 0.10),

                          // お気に入りボタン - 左側に配置
                          //Padding(
                          //padding: EdgeInsets.only(left: screenWidth * 0.08),
                          //child:
                          _buildFavoriteButton(),
                          //),

                          // スペース
                          SizedBox(width: screenWidth * 0.10),

                          // 読むボタン - 中央に配置
                          GestureDetector(
                            onTap: _navigateToBookScreen,
                            child: Container(
                              width: screenWidth * 0.30,
                              height: screenHeight * 0.15,
                              decoration: const BoxDecoration(
                                image: DecorationImage(
                                  image: AssetImage('assets/button-frame.png'),
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),

                          // バランスのためのスペース
                          //SizedBox(width: screenWidth * 0.15),
                          // スペース
                          SizedBox(width: screenWidth * 0.35),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 戻るボタンをより控えめにサイド中央に配置
            Positioned(
              left: 5,
              top: MediaQuery.of(context).size.height * 0.5 - 20, // 画面の中央よりやや上
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0), // 透明に
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.arrow_back_ios,
                    color: Colors.white.withOpacity(0.3), // アイコンも少し透明に
                    size: 30,
                  ),
                ),
              ),
            ),

            // 拡大表示のオーバーレイ (修正)
            if (_isZoomed) _buildZoomedOverlay(),
          ],
        ),
      ),
    );
  }
}
