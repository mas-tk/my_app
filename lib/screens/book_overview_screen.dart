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

  // Navigate to book screen
  void _navigateToBookScreen() {
    HapticFeedback.mediumImpact();

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

  // Toggle favorite status
  Future<void> _toggleFavorite() async {
    if (_book == null) return;

    try {
      // Toggle state immediately for responsive UI
      setState(() {
        _isFavorite = !_isFavorite;
      });

      if (_isFavorite) {
        HapticFeedback.lightImpact();
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

  Widget _buildFavoriteButton() {
    return GestureDetector(
      onTap: _toggleFavorite,
      child: Container(
        width: 70,
        height: 70,
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
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
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Book image and title
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
                                // Book cover
                                _buildCoverImage(_book!.coverAssetPath),
                                const SizedBox(height: 15),

                                // Book title
                                AnimatedOpacity(
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

                      // Genre tags
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

                            // Star rating
                            _buildRatingStars(_book!.rating!),

                            // Comments
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

                      // Summary
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

                      // Download status
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

                      // Button section
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Read button
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
                        ],
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Favorite button (bottom left)
          Positioned(
            left: screenWidth * 0.1,
            bottom: MediaQuery.of(context).size.height * 0.05,
            child: _buildFavoriteButton(),
          ),

          // Zoomed overlay
          if (_isZoomed)
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Opacity(
                  opacity: _opacityAnimation.value,
                  child: GestureDetector(
                    onTap: _toggleCoverZoom, // Close on tap
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
                          // Close button
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

                          // Enlarged cover
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

                          // Read button
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
}
