// lib/screens/home_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/book_models.dart';
import '../repositories/book_repository.dart';

// 各棚段（カテゴリ）の情報を管理するクラス
class ShelfSection {
  final String title;
  final double topPosition;
  final double titleToBookGap;
  final double bookToShelfGap;
  final int booksPerScreen;
  final double bookHeightRatio;

  ShelfSection({
    required this.title,
    required this.topPosition,
    required this.titleToBookGap,
    required this.bookToShelfGap,
    required this.booksPerScreen,
    this.bookHeightRatio = 1.3,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ブックレポジトリ
  final BookRepository _bookRepository = BookRepository();

  // スクロールコントローラー
  late ScrollController _horizontalScrollController;

  // サイズ定数
  late double _screenWidth;
  late double _screenHeight;
  final int _screens = 3; // 横に表示する画面数

  // カテゴリーとその本のデータ
  List<BookCategory> _categories = [];
  Map<String, List<Book>> _categoryBooks = {};
  bool _isLoading = true;

  // 各段の棚情報
  late List<ShelfSection> _shelfSections;

  // パーセンテージによる定義
  final double _sideMarginPercent = 0.03;
  final double _shelfBackgroundTopPercent = 0.05;
  final double _shelfBackgroundBottomPercent = 0.05;
  final double _shelfLeftMarginPercent = 0.005;
  final double _initialScrollPercentage = 1.005;

  // スクロール位置
  late double _initialScrollOffset;

  @override
  void initState() {
    super.initState();

    // スクロールコントローラーを初期化
    _horizontalScrollController = ScrollController();
    _horizontalScrollController.addListener(_scrollListener);

    // 棚のセクション情報を初期化
    _initializeShelfSections();

    // データをロード
    _loadData();

    // 初期スクロール設定を遅延実行
    Future.delayed(const Duration(milliseconds: 500), () {
      _setInitialScrollPosition();
    });
  }

  // データのロード
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // カテゴリーを取得
      final categories = await _bookRepository.getAllCategories();

      if (categories.isNotEmpty) {
        setState(() {
          _categories = categories;
        });

        // 各カテゴリーの本を取得
        for (var category in categories) {
          final books = await _bookRepository.getBooksByCategory(category.id);

          setState(() {
            _categoryBooks[category.id] = books;
          });
        }
      }
    } catch (e) {
      print('Error loading data: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('データの読み込みに失敗しました: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 棚のセクション情報を初期化
  void _initializeShelfSections() {
    _shelfSections = [
      // 1段目
      ShelfSection(
        title: '注目の作品',
        topPosition: 0.12,
        titleToBookGap: 0.04,
        bookToShelfGap: -0.006,
        booksPerScreen: 3,
      ),
      // 2段目
      ShelfSection(
        title: '新着作品',
        topPosition: 0.12 + 0.28,
        titleToBookGap: 0.04,
        bookToShelfGap: -0.006,
        booksPerScreen: 5,
      ),
      // 3段目
      ShelfSection(
        title: '人気作品',
        topPosition: 0.12 + 0.28 * 1.7,
        titleToBookGap: 0.04,
        bookToShelfGap: -0.006,
        booksPerScreen: 5,
      ),
    ];
  }

  @override
  void dispose() {
    _horizontalScrollController.removeListener(_scrollListener);
    _horizontalScrollController.dispose();
    super.dispose();
  }

  // スクロールリスナー
  void _scrollListener() {
    // 必要に応じてスクロール位置を使用
  }

  // 初期スクロール位置を設定
  void _setInitialScrollPosition() {
    if (mounted) {
      try {
        if (_horizontalScrollController.hasClients) {
          _horizontalScrollController.jumpTo(_initialScrollOffset);
        }
      } catch (e) {
        print('スクロール位置設定エラー: $e');
      }
    }
  }

  // 本棚ウィジェットの構築
  Widget _buildBookshelfScreen(BuildContext context) {
    // スクリーンのサイズを取得
    _screenWidth = MediaQuery.of(context).size.width;
    _screenHeight = MediaQuery.of(context).size.height;

    // シェルフセクションを動的に初期化
    _shelfSections = _getShelfSections(context);

    // デバイスの安全でない領域のパディングを取得
    final EdgeInsets padding = MediaQuery.of(context).padding;
    // 上部の安全でない領域（ノッチ/Dynamic Island）の高さ
    final double topPadding = padding.top;

    // パーセンテージから実際の寸法を計算
    final double sideMargin = _screenWidth * _sideMarginPercent;

    // 全体のコンテナ幅を計算
    final double totalWidth = _screenWidth * _screens;

    // 棚板の幅を計算
    final double shelfBoardWidth =
        totalWidth * (1 - _shelfLeftMarginPercent * 2);
    final double shelfLeftMargin = totalWidth * _shelfLeftMarginPercent;

    // 表示エリアの実質幅
    final double effectiveWidth = totalWidth - sideMargin * 2;

    // スクロール位置の調整
    _initialScrollOffset = _screenWidth * _initialScrollPercentage;

    // 遅延設定
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setInitialScrollPosition();
    });

    return Container(
      width: _screenWidth,
      height: _screenHeight,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/room_background.png'),
          fit: BoxFit.fill,
        ),
      ),
      child:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                children: [
                  // 横スクロール可能な本棚
                  SingleChildScrollView(
                    controller: _horizontalScrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      width: totalWidth,
                      height: _screenHeight,
                      child: Stack(
                        children: [
                          // 本棚の背景
                          Positioned(
                            //top: _screenHeight * _shelfBackgroundTopPercent,
                            top:
                                topPadding +
                                (_screenHeight * 0.03), // ノッチの高さ + 少し余裕を持たせる
                            bottom:
                                _screenHeight * _shelfBackgroundBottomPercent,
                            left: 0,
                            width: totalWidth,
                            child: Image.asset(
                              'assets/shelf_background.png',
                              fit: BoxFit.fill,
                            ),
                          ),

                          // タイトルプレート - 追加
                          Positioned(
                            //top:_screenHeight * _shelfBackgroundTopPercent +(_screenHeight * 0.01), // 位置を調整
                            top:
                                topPadding +
                                (_screenHeight * 0.04), // ノッチの高さ + 適切な余白
                            left: 0,
                            width: totalWidth,
                            child: Center(
                              child: Image.asset(
                                'assets/plate_home_1.png', // 画像を追加
                                width: _screenWidth * 0.5, // 幅を調整
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),

                          // 棚のセクションごとに動的に生成
                          for (
                            int i = 0;
                            i < _shelfSections.length && i < _categories.length;
                            i++
                          )
                            ..._buildShelfSection(
                              section: _shelfSections[i],
                              category: _categories[i],
                              sideMargin: sideMargin,
                              effectiveWidth: effectiveWidth,
                              shelfLeftMargin: shelfLeftMargin,
                              shelfBoardWidth: shelfBoardWidth,
                              topPadding: topPadding, // topPaddingを渡す
                            ),
                        ],
                      ),
                    ),
                  ),

                  // 装飾要素
                  // 左上のランプ
                  Positioned(
                    top: _screenWidth * 0.05,
                    left: 0,
                    child: Image.asset(
                      'assets/lamp_left.png',
                      width: _screenWidth * 0.25,
                      height: _screenHeight * 0.12,
                    ),
                  ),

                  // 右上のランプ
                  Positioned(
                    top: _screenWidth * 0.05,
                    right: 0,
                    child: Image.asset(
                      'assets/lamp_right.png',
                      width: _screenWidth * 0.25,
                      height: _screenHeight * 0.12,
                    ),
                  ),

                  // 左下のラジオ
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: Image.asset(
                      'assets/radio.png',
                      width: _screenWidth * 0.3,
                      height: _screenHeight * 0.15,
                    ),
                  ),

                  // 右下のティーカップ
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Image.asset(
                      'assets/teacup.png',
                      width: _screenWidth * 0.3,
                      height: _screenHeight * 0.15,
                    ),
                  ),
                ],
              ),
    );
  }

  // initStateで初期化する代わりに、buildメソッドでシェルフセクションを初期化する関数を作成
  List<ShelfSection> _getShelfSections(BuildContext context) {
    // デバイスのセーフエリアパディングを取得
    final EdgeInsets padding = MediaQuery.of(context).padding;
    final double topPadding = padding.top;

    // スクリーンサイズに基づく相対的な位置調整
    final double screenHeight = MediaQuery.of(context).size.height;

    // トップパディングの割合を計算（この値を元にシェルフの位置を調整）
    final double topPaddingPercent = topPadding / screenHeight;

    return [
      // 1段目
      ShelfSection(
        title: '注目の作品',
        // topPositionはノッチの高さに応じて動的に調整
        // 基本位置は0.12だが、ノッチの高さに基づいて調整
        topPosition: 0.12 + (topPaddingPercent * 0.5), // ノッチ高さの半分程度を加算
        titleToBookGap: 0.04,
        bookToShelfGap: -0.006,
        booksPerScreen: 3,
      ),
      // 2段目
      ShelfSection(
        title: '新着作品',
        // 1段目からの相対位置を維持
        topPosition: 0.12 + (topPaddingPercent * 0.5) + 0.28, // 1段目 + 段間隔
        titleToBookGap: 0.04,
        bookToShelfGap: -0.006,
        booksPerScreen: 5,
      ),
      // 3段目
      ShelfSection(
        title: '人気作品',
        // 2段目からの相対位置を維持
        topPosition:
            0.12 + (topPaddingPercent * 0.5) + 0.28 * 1.7, // 1段目 + 段間隔×1.7
        titleToBookGap: 0.04,
        bookToShelfGap: -0.006,
        booksPerScreen: 5,
      ),
    ];
  }

  // 棚のセクション（タイトル、本、棚板）を構築するヘルパーメソッド
  List<Widget> _buildShelfSection({
    required ShelfSection section,
    required BookCategory category,
    required double sideMargin,
    required double effectiveWidth,
    required double shelfLeftMargin,
    required double shelfBoardWidth,
    required double topPadding, // ノッチの高さ
  }) {
    // タイトルの位置を計算
    //final double titleY = _screenHeight * section.topPosition;
    final double titleY = topPadding + (_screenHeight * section.topPosition);

    // 本の位置と寸法を計算
    double bookWidth;

    if (section.booksPerScreen == 3) {
      bookWidth = (_screenWidth - sideMargin * 2) / 3;
    } else {
      bookWidth = (_screenWidth - sideMargin * 2) / 5;
    }

    final double bookHeight = bookWidth * section.bookHeightRatio;

    // 本の上端位置
    final double booksTop = titleY + (_screenHeight * section.titleToBookGap);

    // 棚板の上端位置
    final double shelfY =
        booksTop + bookHeight + (_screenHeight * section.bookToShelfGap);

    // カテゴリーの本を取得
    final books = _categoryBooks[category.id] ?? [];

    return [
      // カテゴリのタイトル
      Positioned(
        top: titleY,
        left: 0,
        width: effectiveWidth,
        child: Center(
          child: Text(
            category.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.black,
                  offset: Offset(1, 1),
                  blurRadius: 3,
                ),
              ],
            ),
          ),
        ),
      ),

      // 棚板
      Positioned(
        top: shelfY,
        left: shelfLeftMargin,
        width: shelfBoardWidth,
        child: Image.asset(
          'assets/shelf_board.png',
          height: _screenHeight * 0.04,
          fit: BoxFit.fill,
        ),
      ),

      // 本のリスト
      Positioned(
        top: booksTop,
        left: sideMargin,
        width: effectiveWidth,
        height: bookHeight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _buildBooksList(
            books: books,
            bookWidth: bookWidth,
            bookHeight: bookHeight,
          ),
        ),
      ),
    ];
  }

  // 本のリストを作成するヘルパーメソッド
  List<Widget> _buildBooksList({
    required List<Book> books,
    required double bookWidth,
    required double bookHeight,
  }) {
    return books.map((book) {
      return GestureDetector(
        onTap: () {
          Navigator.of(
            context,
          ).pushNamed('/bookOverview', arguments: {'bookId': book.id});
        },
        child: SizedBox(
          width: bookWidth,
          height: bookHeight,
          child: FutureBuilder<String>(
            future: _bookRepository.getAssetPath(book.coverAssetPath),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final imagePath = snapshot.data ?? book.coverAssetPath;
              final isLocal =
                  !imagePath.startsWith('assets/') &&
                  !imagePath.startsWith('http');

              return Image(
                image:
                    isLocal
                        ? FileImage(File(imagePath)) as ImageProvider
                        : AssetImage(imagePath),
                fit: BoxFit.contain,
              );
            },
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // スクリーンのサイズを更新
    _screenWidth = MediaQuery.of(context).size.width;
    _screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(body: _buildBookshelfScreen(context));
  }
}
