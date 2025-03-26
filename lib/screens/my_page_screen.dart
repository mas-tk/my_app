import 'package:flutter/material.dart';

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

// 各棚段（カテゴリ）の情報を管理するクラス
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

// サンプルデータ
final List<BookCategory> categories = [
  BookCategory(
    id: 'my_favorites',
    title: 'お気に入り',
    books: [
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
    ],
  ),
  BookCategory(
    id: 'my_recent',
    title: '最近読んだ本',
    books: [
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
    ],
  ),
  BookCategory(
    id: 'my_collection',
    title: 'マイコレクション',
    books: [
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
    ],
  ),
];

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({Key? key}) : super(key: key);

  @override
  _MyPageScreenState createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  // 表示モード管理
  bool _showBanner = false;

  // サイズ定数（レスポンシブ対応のため実際の画面サイズから計算）
  late double _screenWidth;
  late double _screenHeight;

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

  // ユーザー情報
  final Map<String, dynamic> _userData = {
    'username': 'ユーザー名',
    'readBooks': 12,
    'favoriteBooks': 5,
  };

  @override
  void initState() {
    super.initState();

    // 棚のセクション情報を初期化
    _initializeShelfSections();
  }

  // 棚のセクション情報を初期化
  void _initializeShelfSections() {
    _shelfSections = [
      // 1段目（お気に入り）
      ShelfSection(
        title: 'お気に入り',
        topPosition: 0.12, // 最初の棚位置
        titleToBookGap: 0.04, // タイトルから本までの間隔を増加
        bookToShelfGap: -0.006, // 本から棚板までの間隔
        booksPerScreen: 3, // 1画面あたりの本の数
        bookHeightRatio: 1.3, // 本の幅に対する高さの比率
      ),
      // 2段目（最近読んだ本）
      ShelfSection(
        title: '最近読んだ本',
        topPosition: 0.12 + 0.28, // 1段目の位置 + 段間隔 = 0.40
        titleToBookGap: 0.04, // タイトルから本までの間隔
        bookToShelfGap: -0.006, // 本から棚板までの間隔
        booksPerScreen: 5, // 1画面あたりの本の数
        bookHeightRatio: 1.3, // 本の幅に対する高さの比率
      ),
      // 3段目（マイコレクション）
      ShelfSection(
        title: 'マイコレクション',
        topPosition: 0.12 + 0.28 * 1.7, // 1段目の位置 + (段間隔 × 1.7) = 約0.596
        titleToBookGap: 0.04, // タイトルから本までの間隔
        bookToShelfGap: -0.006, // 本から棚板までの間隔
        booksPerScreen: 5, // 1画面あたりの本の数
        bookHeightRatio: 1.3, // 本の幅に対する高さの比率
      ),
    ];
  }

  // バナー表示を切り替え
  void _toggleBanner(bool show) {
    setState(() {
      _showBanner = show;
    });
  }

  // 本棚ウィジェットの構築
  Widget _buildBookshelfScreen(BuildContext context) {
    // スクリーンのサイズを取得
    _screenWidth = MediaQuery.of(context).size.width;
    _screenHeight = MediaQuery.of(context).size.height;

    // パーセンテージから実際の寸法を計算
    final double sideMargin = _screenWidth * _sideMarginPercent;

    // 棚板の幅を計算
    final double shelfBoardWidth =
        _screenWidth * (1 - _shelfLeftMarginPercent * 2);
    final double shelfLeftMargin = _screenWidth * _shelfLeftMarginPercent;

    // 表示エリアの実質幅（左右マージンを除いた幅）
    final double effectiveWidth = _screenWidth - sideMargin * 2;

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
            // 最背面: 部屋の背景 - Container自体に設定済み

            // 中間層1: 本棚の背景
            Positioned(
              top: _screenHeight * _shelfBackgroundTopPercent,
              bottom: _screenHeight * _shelfBackgroundBottomPercent,
              left: 0,
              width: _screenWidth,
              child: Image.asset(
                'assets/shelf_background.png',
                fit: BoxFit.fill,
              ),
            ),

            // 中間層2: 棚と本
            for (int i = 0; i < _shelfSections.length; i++)
              ..._buildShelfSection(
                section: _shelfSections[i],
                categoryIndex: i,
                sideMargin: sideMargin,
                effectiveWidth: effectiveWidth,
                shelfLeftMargin: shelfLeftMargin,
                shelfBoardWidth: shelfBoardWidth,
              ),

            // 中間層3: 装飾要素（ランプ、ラジオ、ティーカップ）
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

            // 最前面: スワイプインジケーター
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
              top: 40,
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
              padding: const EdgeInsets.fromLTRB(16, 80, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ヘッダータイトル
                  const Padding(
                    padding: EdgeInsets.only(bottom: 20),
                    child: Text(
                      'おすすめ作品',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  _buildBannerItem(
                    'あなたにおすすめ',
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
                  _buildBannerItem(
                    '新作紹介',
                    categories[0].books[1].coverAssetPath,
                    const Color(0xFFF0F0FF),
                  ),
                  _buildBannerItem(
                    '人気ランキング',
                    categories[1].books[1].coverAssetPath,
                    const Color(0xFFFFF0F0),
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
          onTap: () {
            // 本の詳細画面に遷移するなどの処理をここに追加できます
            print('Banner clicked: $title');
          },
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

  // 棚のセクション（本、棚板）を構築するヘルパーメソッド
  List<Widget> _buildShelfSection({
    required ShelfSection section,
    required int categoryIndex,
    required double sideMargin,
    required double effectiveWidth,
    required double shelfLeftMargin,
    required double shelfBoardWidth,
  }) {
    // タイトル位置（タイトルは表示しないが位置計算に使用）
    final double titleY = _screenHeight * section.topPosition;

    // 本の位置と寸法を計算
    double bookWidth;

    if (section.booksPerScreen == 3) {
      bookWidth = (_screenWidth - sideMargin * 2) / 3;
    } else {
      bookWidth = (_screenWidth - sideMargin * 2) / 5;
    }

    final double bookHeight = bookWidth * section.bookHeightRatio;

    // 本の上端位置 - タイトルとの間隔は維持
    final double booksTop = titleY + (_screenHeight * section.titleToBookGap);

    // 棚板の上端位置
    final double shelfY =
        booksTop + bookHeight + (_screenHeight * section.bookToShelfGap);

    return [
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
          mainAxisAlignment: MainAxisAlignment.spaceEvenly, // スペース均等配置に変更
          children: _buildBooksList(
            books: categories[categoryIndex].books,
            bookWidth: bookWidth,
            bookHeight: bookHeight,
            maxBooksToShow: section.booksPerScreen,
          ),
        ),
      ),
    ];
  }

  // 本のリストを作成するヘルパーメソッド（最大表示数を制限）
  List<Widget> _buildBooksList({
    required List<Book> books,
    required double bookWidth,
    required double bookHeight,
    required int maxBooksToShow,
  }) {
    // 表示する本の数を制限
    final displayBooks =
        books.length > maxBooksToShow
            ? books.sublist(0, maxBooksToShow)
            : books;

    return displayBooks.map((book) {
      return GestureDetector(
        onTap: () {
          Navigator.of(
            context,
          ).pushNamed('/bookOverview', arguments: {'bookId': book.id});
        },
        child: Container(
          width: bookWidth,
          height: bookHeight,
          padding: EdgeInsets.symmetric(
            horizontal: bookWidth * 0.05,
          ), // 両側に5%のパディングを追加
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
