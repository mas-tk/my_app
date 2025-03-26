import 'package:flutter/material.dart';
import 'dart:math';

// 本のデータモデル
class Book {
  final String id;
  final String title;
  final String coverAssetPath;

  Book({required this.id, required this.title, required this.coverAssetPath});
}

// カテゴリー（棚）のデータモデル
class BookCategory {
  final String id;
  final String title;
  final List<Book> books;

  BookCategory({required this.id, required this.title, required this.books});
}

// 各棚段（カテゴリ）の情報を管理するクラス - クラスを外に出す
class ShelfSection {
  final String title; // カテゴリタイトル
  final double topPosition; // 画面の上端からの相対位置（画面高さの割合）
  final double titleToBookGap; // タイトルから本までの間隔（画面高さの割合）
  final double bookToShelfGap; // 本から棚板までの間隔（画面高さの割合）
  final int booksPerScreen; // 1画面あたりの本の数
  final double bookHeightRatio; // 本の幅に対する高さの比率

  ShelfSection({
    required this.title,
    required this.topPosition,
    required this.titleToBookGap,
    required this.bookToShelfGap,
    required this.booksPerScreen,
    this.bookHeightRatio = 1.3, // デフォルト値
  });
}

// サンプルデータをより多くの本で拡張
final List<BookCategory> categories = [
  BookCategory(
    id: 'featured',
    title: '注目の作品',
    books: [
      // 第1画面 - 3冊
      Book(
        id: '1',
        title: '～大人のための"もしも"童話再解釈～ ヘンゼルとグレーテル',
        coverAssetPath: 'assets/bookcovers/cover1.png',
      ),
      Book(
        id: '2',
        title: '夜の図書館',
        coverAssetPath: 'assets/bookcovers/cover2.png',
      ),
      Book(
        id: '3',
        title: '仕事を辞めた魔女',
        coverAssetPath: 'assets/bookcovers/cover3.png',
      ),
      // 第2画面 - 3冊
      Book(
        id: '1-2',
        title: '～大人のための"もしも"童話再解釈～ ヘンゼルとグレーテル',
        coverAssetPath: 'assets/bookcovers/cover1.png',
      ),
      Book(
        id: '2-2',
        title: '夜の図書館',
        coverAssetPath: 'assets/bookcovers/cover2.png',
      ),
      Book(
        id: '3-2',
        title: '仕事を辞めた魔女',
        coverAssetPath: 'assets/bookcovers/cover3.png',
      ),
      // 第3画面 - 3冊
      Book(
        id: '1-3',
        title: '～大人のための"もしも"童話再解釈～ ヘンゼルとグレーテル',
        coverAssetPath: 'assets/bookcovers/cover1.png',
      ),
      Book(
        id: '2-3',
        title: '夜の図書館',
        coverAssetPath: 'assets/bookcovers/cover2.png',
      ),
      Book(
        id: '3-3',
        title: '仕事を辞めた魔女',
        coverAssetPath: 'assets/bookcovers/cover3.png',
      ),
    ],
  ),
  BookCategory(
    id: 'new',
    title: '新着作品',
    books: [
      // 第1画面 - 5冊
      Book(
        id: '6',
        title: '夜の図書館',
        coverAssetPath: 'assets/bookcovers/cover2.png',
      ),
      Book(
        id: '7',
        title: '仕事を辞めた魔女',
        coverAssetPath: 'assets/bookcovers/cover3.png',
      ),
      Book(
        id: '8',
        title: '～大人のための"もしも"童話再解釈～ ヘンゼルとグレーテル',
        coverAssetPath: 'assets/bookcovers/cover1.png',
      ),
      Book(
        id: '9',
        title: '夜の図書館',
        coverAssetPath: 'assets/bookcovers/cover2.png',
      ),
      Book(
        id: '10',
        title: '仕事を辞めた魔女',
        coverAssetPath: 'assets/bookcovers/cover3.png',
      ),
      // 第2画面 - 5冊
      Book(
        id: '6-2',
        title: '夜の図書館',
        coverAssetPath: 'assets/bookcovers/cover2.png',
      ),
      Book(
        id: '7-2',
        title: '仕事を辞めた魔女',
        coverAssetPath: 'assets/bookcovers/cover3.png',
      ),
      Book(
        id: '8-2',
        title: '～大人のための"もしも"童話再解釈～ ヘンゼルとグレーテル',
        coverAssetPath: 'assets/bookcovers/cover1.png',
      ),
      Book(
        id: '9-2',
        title: '夜の図書館',
        coverAssetPath: 'assets/bookcovers/cover2.png',
      ),
      Book(
        id: '10-2',
        title: '仕事を辞めた魔女',
        coverAssetPath: 'assets/bookcovers/cover3.png',
      ),
      // 第3画面 - 5冊
      Book(
        id: '6-3',
        title: '夜の図書館',
        coverAssetPath: 'assets/bookcovers/cover2.png',
      ),
      Book(
        id: '7-3',
        title: '仕事を辞めた魔女',
        coverAssetPath: 'assets/bookcovers/cover3.png',
      ),
      Book(
        id: '8-3',
        title: '～大人のための"もしも"童話再解釈～ ヘンゼルとグレーテル',
        coverAssetPath: 'assets/bookcovers/cover1.png',
      ),
      Book(
        id: '9-3',
        title: '夜の図書館',
        coverAssetPath: 'assets/bookcovers/cover2.png',
      ),
      Book(
        id: '10-3',
        title: '仕事を辞めた魔女',
        coverAssetPath: 'assets/bookcovers/cover3.png',
      ),
    ],
  ),
  BookCategory(
    id: 'popular',
    title: '人気作品',
    books: [
      // 第1画面 - 5冊
      Book(
        id: '11',
        title: '仕事を辞めた魔女',
        coverAssetPath: 'assets/bookcovers/cover3.png',
      ),
      Book(
        id: '12',
        title: '～大人のための"もしも"童話再解釈～ ヘンゼルとグレーテル',
        coverAssetPath: 'assets/bookcovers/cover1.png',
      ),
      Book(
        id: '13',
        title: '夜の図書館',
        coverAssetPath: 'assets/bookcovers/cover2.png',
      ),
      Book(
        id: '14',
        title: '仕事を辞めた魔女',
        coverAssetPath: 'assets/bookcovers/cover3.png',
      ),
      Book(
        id: '15',
        title: '～大人のための"もしも"童話再解釈～ ヘンゼルとグレーテル',
        coverAssetPath: 'assets/bookcovers/cover1.png',
      ),
      // 第2画面 - 5冊
      Book(
        id: '11-2',
        title: '仕事を辞めた魔女',
        coverAssetPath: 'assets/bookcovers/cover3.png',
      ),
      Book(
        id: '12-2',
        title: '～大人のための"もしも"童話再解釈～ ヘンゼルとグレーテル',
        coverAssetPath: 'assets/bookcovers/cover1.png',
      ),
      Book(
        id: '13-2',
        title: '夜の図書館',
        coverAssetPath: 'assets/bookcovers/cover2.png',
      ),
      Book(
        id: '14-2',
        title: '仕事を辞めた魔女',
        coverAssetPath: 'assets/bookcovers/cover3.png',
      ),
      Book(
        id: '15-2',
        title: '～大人のための"もしも"童話再解釈～ ヘンゼルとグレーテル',
        coverAssetPath: 'assets/bookcovers/cover1.png',
      ),
      // 第3画面 - 5冊
      Book(
        id: '11-3',
        title: '仕事を辞めた魔女',
        coverAssetPath: 'assets/bookcovers/cover3.png',
      ),
      Book(
        id: '12-3',
        title: '～大人のための"もしも"童話再解釈～ ヘンゼルとグレーテル',
        coverAssetPath: 'assets/bookcovers/cover1.png',
      ),
      Book(
        id: '13-3',
        title: '夜の図書館',
        coverAssetPath: 'assets/bookcovers/cover2.png',
      ),
      Book(
        id: '14-3',
        title: '仕事を辞めた魔女',
        coverAssetPath: 'assets/bookcovers/cover3.png',
      ),
      Book(
        id: '15-3',
        title: '～大人のための"もしも"童話再解釈～ ヘンゼルとグレーテル',
        coverAssetPath: 'assets/bookcovers/cover1.png',
      ),
    ],
  ),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 表示モード管理
  bool _showBanner = false;

  // スクロールコントローラー
  late ScrollController _horizontalScrollController;

  // サイズ定数（レスポンシブ対応のため実際の画面サイズから計算）
  late double _screenWidth;
  late double _screenHeight;
  final int _screens = 3; // 横に表示する画面数

  // 各段の棚情報
  late List<ShelfSection> _shelfSections;

  // パーセンテージによる定義（レイアウトの一貫性を保つため）
  // 左右のマージン
  final double _sideMarginPercent = 0.03; // 画面幅の3%

  // 本棚背景の位置
  final double _shelfBackgroundTopPercent = 0.05; // 画面高さの5%
  final double _shelfBackgroundBottomPercent = 0.05; // 画面高さの5%

  // 棚板の位置関係
  final double _shelfLeftMarginPercent = 0.005; // 棚板の左マージン（全体幅の0.5%）

  // 初期スクロール位置
  final double _initialScrollPercentage = 1.005; // 初期スクロール位置（画面幅の97%）

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

    // 初期スクロール設定を遅延実行
    Future.delayed(const Duration(milliseconds: 500), () {
      _setInitialScrollPosition();
    });
  }

  // 棚のセクション情報を初期化
  void _initializeShelfSections() {
    _shelfSections = [
      // 1段目（注目の作品）
      ShelfSection(
        title: '注目の作品',
        topPosition: 0.12, // 元の_topPaddingPercent 0.097,
        titleToBookGap: 0.04, //0.025,
        bookToShelfGap: -0.006,
        booksPerScreen: 3,
      ),
      // 2段目（新着作品）
      ShelfSection(
        title: '新着作品',
        topPosition: 0.12 + 0.28, // 1段目 + 段間隔
        titleToBookGap: 0.04,
        bookToShelfGap: -0.006,
        booksPerScreen: 5,
      ),
      // 3段目（人気作品）
      ShelfSection(
        title: '人気作品',
        topPosition: 0.12 + 0.28 * 1.7, // 1段目 + 段間隔 × 2
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
    print('スクロール位置: ${_horizontalScrollController.offset}');
  }

  // 初期スクロール位置を設定
  void _setInitialScrollPosition() {
    if (mounted) {
      try {
        if (_horizontalScrollController.hasClients) {
          // 少し左右の本が見えるようにスクロール位置を調整
          _horizontalScrollController.jumpTo(_initialScrollOffset);
          print('スクロール位置を設定: $_initialScrollOffset');
        } else {
          print('スクロールコントローラーにクライアントがありません');
        }
      } catch (e) {
        print('スクロール位置設定エラー: $e');
      }
    }
  }

  // バナー表示を切り替え
  void _toggleBanner(bool show) {
    setState(() {
      _showBanner = show;
    });
  }

  // バナーウィジェットの構築
  Widget _buildBannerScreen() {
    return GestureDetector(
      onVerticalDragEnd: (details) {
        // 下方向へのスワイプを検出
        if (details.velocity.pixelsPerSecond.dy > 0) {
          _toggleBanner(false);
        }
      },
      child: Container(
        color: const Color(0xFFF8F8F8),
        child: Stack(
          children: [
            // 閉じるボタン
            Positioned(
              top: 10,
              right: 16,
              child: IconButton(
                icon: Image.asset(
                  'assets/down_arrow.png',
                  width: 24,
                  height: 24,
                ),
                onPressed: () => _toggleBanner(false),
              ),
            ),

            // バナーコンテンツ
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
              child: Column(
                children: [
                  _buildBannerItem(
                    '今月のおすすめ',
                    categories[0].books[0].coverAssetPath,
                    const Color(0xFFE0F7E0),
                  ),
                  _buildBannerItem(
                    '特集',
                    categories[1].books[0].coverAssetPath,
                    Colors.white,
                  ),
                  _buildBannerItem(
                    'キャンペーン',
                    categories[2].books[0].coverAssetPath,
                    Colors.white,
                  ),

                  // デバッグ用ボタン
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6347),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => _toggleBanner(false),
                    child: const Text(
                      '本棚に戻る',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // バナーアイテムウィジェット
  Widget _buildBannerItem(String title, String imagePath, Color bgColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDDDDD)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => print('Banner clicked: $title'),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Image.asset(
                  imagePath,
                  width: 60,
                  height: 80,
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 本棚ウィジェットの構築
  Widget _buildBookshelfScreen(BuildContext context) {
    // スクリーンのサイズを取得
    _screenWidth = MediaQuery.of(context).size.width;
    _screenHeight = MediaQuery.of(context).size.height;

    // パーセンテージから実際の寸法を計算
    final double sideMargin = _screenWidth * _sideMarginPercent;

    // 全体のコンテナ幅を計算
    final double totalWidth = _screenWidth * _screens;

    // 棚板の幅を計算
    final double shelfBoardWidth =
        totalWidth * (1 - _shelfLeftMarginPercent * 2);
    final double shelfLeftMargin = totalWidth * _shelfLeftMarginPercent;

    // 表示エリアの実質幅（左右マージンを除いた幅）
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
      // 背景画像を設定
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/room_background.png'),
          fit: BoxFit.fill, // 画面いっぱいに引き伸ばし
        ),
      ),
      child: GestureDetector(
        onVerticalDragEnd: (details) {
          // 上方向へのスワイプを検出
          if (details.velocity.pixelsPerSecond.dy < 0) {
            _toggleBanner(true);
          }
        },
        child: Stack(
          children: [
            // 横スクロール可能な本棚
            SingleChildScrollView(
              controller: _horizontalScrollController,
              scrollDirection: Axis.horizontal,
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                // 全体の幅
                width: totalWidth,
                height: _screenHeight,
                child: Stack(
                  children: [
                    // 本棚の背景
                    Positioned(
                      top: _screenHeight * _shelfBackgroundTopPercent,
                      bottom: _screenHeight * _shelfBackgroundBottomPercent,
                      left: 0,
                      width: totalWidth,
                      child: Image.asset(
                        'assets/shelf_background.png',
                        fit: BoxFit.fill,
                      ),
                    ),

                    // 棚のセクションごとに動的に生成
                    for (int i = 0; i < _shelfSections.length; i++)
                      ..._buildShelfSection(
                        section: _shelfSections[i],
                        categoryIndex: i,
                        sideMargin: sideMargin,
                        effectiveWidth: effectiveWidth,
                        shelfLeftMargin: shelfLeftMargin,
                        shelfBoardWidth: shelfBoardWidth,
                      ),
                  ],
                ),
              ),
            ),

            // 装飾要素
            // 左上のランプ
            Positioned(
              top: 0,
              left: 0,
              child: Image.asset(
                'assets/lamp_left.png',
                width: _screenWidth * 0.25, // 画面幅の25%
                height: _screenHeight * 0.12, // 画面高さの12%
              ),
            ),

            // 右上のランプ
            Positioned(
              top: 0,
              right: 0,
              child: Image.asset(
                'assets/lamp_right.png',
                width: _screenWidth * 0.25, // 画面幅の25%
                height: _screenHeight * 0.12, // 画面高さの12%
              ),
            ),

            // 左下のラジオ
            Positioned(
              bottom: 0,
              left: 0,
              child: Image.asset(
                'assets/radio.png',
                width: _screenWidth * 0.3, // 画面幅の30%
                height: _screenHeight * 0.15, // 画面高さの15%
              ),
            ),

            // 右下のティーカップ
            Positioned(
              bottom: 0,
              right: 0,
              child: Image.asset(
                'assets/teacup.png',
                width: _screenWidth * 0.3, // 画面幅の30%
                height: _screenHeight * 0.15, // 画面高さの15%
              ),
            ),

            // 上スワイプインジケーター
            Positioned(
              bottom: _screenHeight * 0.02, // 画面高さの2%
              left: 0,
              right: 0,
              child: Center(
                child: Opacity(
                  opacity: 0.7,
                  child: Image.asset(
                    'assets/up_arrow.png',
                    width: _screenWidth * 0.08, // 画面幅の8%
                    height: _screenWidth * 0.08, // 画面幅の8%
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 棚のセクション（タイトル、本、棚板）を構築するヘルパーメソッド
  List<Widget> _buildShelfSection({
    required ShelfSection section,
    required int categoryIndex,
    required double sideMargin,
    required double effectiveWidth,
    required double shelfLeftMargin,
    required double shelfBoardWidth,
  }) {
    // タイトルの位置を計算
    final double titleY = _screenHeight * section.topPosition;

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

    return [
      // カテゴリのタイトル
      Positioned(
        top: titleY,
        left: 0,
        width: effectiveWidth,
        child: Center(
          child: Text(
            section.title,
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
          height: _screenHeight * 0.04, // 画面高さの4%
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
            books: categories[categoryIndex].books,
            bookWidth: bookWidth,
            bookHeight: bookHeight,
          ),
        ),
      ),
    ];
  }

  // 本のリストを作成するヘルパーメソッド（マージンなしでシームレスに配置）
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
          // マージンをなくし、シームレスに表示
          child: Image.asset(book.coverAssetPath, fit: BoxFit.contain),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // スクリーンのサイズを更新
    _screenWidth = MediaQuery.of(context).size.width;
    _screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(0), // ほぼ見えないヘッダー
        child: AppBar(
          elevation: 0, // 影なし
          backgroundColor: Colors.transparent, // 透明背景
          toolbarHeight: 0, // ツールバーの高さをゼロに
        ),
      ),
      body: _showBanner ? _buildBannerScreen() : _buildBookshelfScreen(context),
    );
  }
}
