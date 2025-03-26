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

class _BookOverviewScreenState extends State<BookOverviewScreen> {
  final BookRepository _bookRepository = BookRepository();
  Book? _book;
  bool _isLoading = true;
  bool _isDownloaded = false;
  bool _isDownloading = false;

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
      body: Container(
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
                            FutureBuilder<String>(
                              future: _bookRepository.getAssetPath(
                                _book!.coverAssetPath,
                              ),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const SizedBox(
                                    width: 100,
                                    height: 150,
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }

                                final imagePath =
                                    snapshot.data ?? _book!.coverAssetPath;

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
                                  imageProvider = AssetImage(
                                    _book!.coverAssetPath,
                                  );
                                }

                                return Image(
                                  image: imageProvider,
                                  width:
                                      MediaQuery.of(context).size.width * 0.6,
                                  height: 200,
                                  fit: BoxFit.contain,
                                );
                              },
                            ),
                            const SizedBox(height: 15),

                            // 本のタイトル
                            Text(
                              _book!.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
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
                            const Text('👁️', style: TextStyle(fontSize: 16)),
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
                            const Text('💬', style: TextStyle(fontSize: 16)),
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
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/book',
                        arguments: BookScreenArguments(
                          bookId: _book!.id,
                          title: _book!.title,
                          isTTS: false,
                        ),
                      );
                    },
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
