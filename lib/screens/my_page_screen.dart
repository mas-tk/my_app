// lib/screens/my_page_screen.dart
import 'package:flutter/material.dart';
import 'dart:math' show sin;
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle, HapticFeedback;
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/book_repository.dart';
import '../repositories/object_repository.dart';
import '../models/book_models.dart' as app_models;
import '../models/object_models.dart';
import '../models/shelf_models.dart';
import '../services/file_storage_service.dart';
import 'favorites_screen.dart';

// 編集用の空のスロットを表現するクラス
class EmptyBookSlot {
  final String id;

  EmptyBookSlot({required this.id});
}

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({Key? key}) : super(key: key);

  @override
  _MyPageScreenState createState() => _MyPageScreenState();
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

class _MyPageScreenState extends State<MyPageScreen>
    with SingleTickerProviderStateMixin {
  // Constants for file names
  static const String SHELF_CATEGORIES_FILE = 'shelf_categories.json';
  static const String SHELF_CATEGORIES_ASSET =
      'assets/data/shelf_categories.json';
  static const String FAVORITE_BOOKS_FILE = 'favorite_books.json';
  static const String FAVORITE_BOOKS_ASSET = 'assets/data/favorite_books.json';

  // Add FileStorageService instance
  final FileStorageService _fileStorageService = FileStorageService();

  // 表示モード管理
  bool _isEditMode = false; // 編集モード状態

  // BookRepositoryインスタンス - 本の詳細情報を取得するため
  final BookRepository _bookRepository = BookRepository();

  // ObjectRepositoryインスタンス - オブジェクトの詳細情報を取得するため
  final ObjectRepository _objectRepository = ObjectRepository();

  // 本の情報キャッシュ
  final Map<String, app_models.Book> _bookCache = {};

  // オブジェクトの情報キャッシュ
  final Map<String, DecorationObject> _objectCache = {};

  // カテゴリーとお気に入りデータ
  List<ShelfCategory> categories = [];
  List<FavoriteBookReference> favoriteBooksForAddDialog = [];
  List<DecorationObject> purchasedObjectsForAddDialog = [];

  // アニメーションコントローラー（震える効果用）
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  // サイズ定数（レスポンシブ対応のため実際の画面サイズから計算）
  late double _screenWidth;
  late double _screenHeight;

  // 各段の棚情報
  late List<ShelfSection> _shelfSections;

  // ドラッグ＆ドロップ操作のための変数
  String? _draggedItemId;
  ShelfItemType? _draggedItemType;
  int _draggedCategoryIndex = -1;
  int _draggedItemIndex = -1;
  int _targetCategoryIndex = -1;
  int _targetItemIndex = -1;

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

  // 各カテゴリの最大アイテム数
  final Map<String, int> _maxItemsPerCategory = {
    'my_favorites': 3,
    'my_recent': 5,
    'my_collection': 5,
  };

  // 本の読み込み状態
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    // 棚のセクション情報を初期化
    _initializeShelfSections();

    // 震える効果のアニメーションコントローラーを初期化 - より長い時間でスムーズに
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 800), // より長い時間でスムーズに
      vsync: this,
    );

    // アニメーションを繰り返し実行
    _shakeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _shakeController.repeat(reverse: true);
      }
    });

    // データをロード
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 画面が表示されるたびにデータをリロード
    if (!_isLoading && !_isEditMode) {
      _loadData();
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  // ここからデータロードのメソッド
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // キャッシュをクリアしてから読み込み
      _objectRepository.clearCache();

      // Ensure local files exist
      await _fileStorageService.ensureLocalJsonFileExists(
        SHELF_CATEGORIES_FILE,
        SHELF_CATEGORIES_ASSET,
      );

      await _fileStorageService.ensureLocalJsonFileExists(
        FAVORITE_BOOKS_FILE,
        FAVORITE_BOOKS_ASSET,
      );

      // Load categories from local file
      final categoriesData = await _fileStorageService.readJsonFromFile(
        SHELF_CATEGORIES_FILE,
      );
      if (categoriesData != null) {
        categories =
            (categoriesData as List)
                .map((json) => ShelfCategory.fromJson(json))
                .toList();
      } else {
        // Fallback to asset if local file read fails
        final String categoriesJson = await rootBundle.loadString(
          SHELF_CATEGORIES_ASSET,
        );
        final List<dynamic> assetCategoriesData = json.decode(categoriesJson);
        categories =
            assetCategoriesData
                .map((json) => ShelfCategory.fromJson(json))
                .toList();

        // Save to local file for future use
        await _fileStorageService.writeJsonToFile(
          SHELF_CATEGORIES_FILE,
          assetCategoriesData,
        );
      }

      // Load favorite books
      final favoritesData = await _fileStorageService.readJsonFromFile(
        FAVORITE_BOOKS_FILE,
      );
      if (favoritesData != null) {
        favoriteBooksForAddDialog =
            (favoritesData as List)
                .map((json) => FavoriteBookReference.fromJson(json))
                .toList();
      } else {
        // Fallback to asset
        final String favoritesJson = await rootBundle.loadString(
          FAVORITE_BOOKS_ASSET,
        );
        final List<dynamic> assetFavoritesData = json.decode(favoritesJson);
        favoriteBooksForAddDialog =
            assetFavoritesData
                .map((json) => FavoriteBookReference.fromJson(json))
                .toList();

        // Save to local file
        await _fileStorageService.writeJsonToFile(
          FAVORITE_BOOKS_FILE,
          assetFavoritesData,
        );
      }

      // Load purchased objects with clear cache
      _objectRepository.clearCache();
      purchasedObjectsForAddDialog =
          await _objectRepository.getPurchasedObjects();

      // デバッグ用に購入済みオブジェクト情報を出力
      print(
        'Loaded ${purchasedObjectsForAddDialog.length} purchased objects for dialog',
      );
      for (var obj in purchasedObjectsForAddDialog) {
        print(
          '  - ${obj.name}: ${obj.imagePath} (isPurchased: ${obj.isPurchased})',
        );
      }

      // Also sync with SharedPreferences for compatibility with other screens
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(
        favoriteBooksForAddDialog.map((f) => f.toJson()).toList(),
      );
      await prefs.setString('favorite_books', jsonString);

      // Preload books and objects
      await _preloadBooks();
      await _preloadObjects();

      _updateCategoryTitles();
    } catch (e) {
      print('データのロード中にエラーが発生しました: $e');
      await _loadDefaultData();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Update this method to write changes to file storage
  Future<void> _saveData() async {
    try {
      // Save categories to local file
      final List<Map<String, dynamic>> categoriesJson =
          categories.map((category) => category.toJson()).toList();

      await _fileStorageService.writeJsonToFile(
        SHELF_CATEGORIES_FILE,
        categoriesJson,
      );

      // Save favorites to SharedPreferences for compatibility
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(
        favoriteBooksForAddDialog.map((f) => f.toJson()).toList(),
      );
      await prefs.setString('favorite_books', jsonString);

      // Also save to file
      await _fileStorageService.writeJsonToFile(
        FAVORITE_BOOKS_FILE,
        favoriteBooksForAddDialog.map((f) => f.toJson()).toList(),
      );

      print('Saved all data successfully to local files');
    } catch (e) {
      print('データの保存中にエラーが発生しました: $e');
    }
  }

  // カテゴリ名を更新（マイコレクション → お気に入りに統一）
  void _updateCategoryTitles() {
    for (var i = 0; i < categories.length; i++) {
      if (categories[i].id == 'my_collection') {
        categories[i] = ShelfCategory(
          id: categories[i].id,
          title: 'お気に入り',
          items: categories[i].items,
        );
        break;
      }
    }

    // 棚のセクション情報も更新
    for (var i = 0; i < _shelfSections.length; i++) {
      if (_shelfSections[i].title == 'マイコレクション') {
        _shelfSections[i] = ShelfSection(
          title: 'お気に入り',
          topPosition: _shelfSections[i].topPosition,
          titleToBookGap: _shelfSections[i].titleToBookGap,
          bookToShelfGap: _shelfSections[i].bookToShelfGap,
          booksPerScreen: _shelfSections[i].booksPerScreen,
          bookHeightRatio: _shelfSections[i].bookHeightRatio,
        );
      }
    }
  }

  // デフォルトデータをロード（JSONファイルがない場合のフォールバック）
  Future<void> _loadDefaultData() async {
    // Default favorite data
    favoriteBooksForAddDialog = [
      FavoriteBookReference(
        id: 'fav1',
        bookId: '1', // "裏路地の不思議なバー"
        registeredAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      FavoriteBookReference(
        id: 'fav2',
        bookId: '2', // "踊る影と、静かなわたし"
        registeredAt: DateTime.now().subtract(const Duration(days: 25)),
      ),
      FavoriteBookReference(
        id: 'fav3',
        bookId: '3', // "夜行バスの窓から"
        registeredAt: DateTime.now().subtract(const Duration(days: 20)),
      ),
      FavoriteBookReference(
        id: 'fav4',
        bookId: '4', // "夜の図書館"
        registeredAt: DateTime.now().subtract(const Duration(days: 15)),
      ),
      FavoriteBookReference(
        id: 'fav5',
        bookId: '3', // "夜行バスの窓から"
        registeredAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
    ];

    // デフォルトデータをSharedPreferencesにも保存
    try {
      // Save to local file
      await _fileStorageService.writeJsonToFile(
        FAVORITE_BOOKS_FILE,
        favoriteBooksForAddDialog.map((f) => f.toJson()).toList(),
      );

      // Also update SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(
        favoriteBooksForAddDialog.map((f) => f.toJson()).toList(),
      );
      await prefs.setString('favorite_books', jsonString);

      print('デフォルトのお気に入りデータを保存しました');
    } catch (e) {
      print('デフォルトデータの保存中にエラーが発生しました: $e');
    }

    // デフォルトカテゴリーデータ (新しいモデルに更新)
    categories = [
      ShelfCategory(
        id: 'my_favorites',
        title: 'お気に入り',
        items: [
          ShelfItemReference(
            id: '1_position_0',
            itemId: '1', // "裏路地の不思議なバー"
            type: ShelfItemType.book,
          ),
          ShelfItemReference(
            id: '2_position_1',
            itemId: '4', // "夜の図書館"
            type: ShelfItemType.book,
          ),
          ShelfItemReference(
            id: '3_position_2',
            itemId: '3', // "夜行バスの窓から"
            type: ShelfItemType.book,
          ),
        ],
      ),
      ShelfCategory(
        id: 'my_recent',
        title: '最近読んだ本',
        items: [
          ShelfItemReference(
            id: '6_position_0',
            itemId: '4', // "夜の図書館"
            type: ShelfItemType.book,
          ),
          ShelfItemReference(
            id: '7_position_1',
            itemId: '3', // "夜行バスの窓から"
            type: ShelfItemType.book,
          ),
          ShelfItemReference(
            id: '8_position_2',
            itemId: '1', // "裏路地の不思議なバー"
            type: ShelfItemType.book,
          ),
          ShelfItemReference(
            id: '9_position_3',
            itemId: '4', // "夜の図書館"
            type: ShelfItemType.book,
          ),
          ShelfItemReference(
            id: '10_position_4',
            itemId: '3', // "夜行バスの窓から"
            type: ShelfItemType.book,
          ),
        ],
      ),
      ShelfCategory(
        id: 'my_collection',
        title: 'お気に入り', // "マイコレクション"から"お気に入り"に変更
        items: [
          ShelfItemReference(
            id: '11_position_0',
            itemId: '3', // "夜行バスの窓から"
            type: ShelfItemType.book,
          ),
          ShelfItemReference(
            id: '12_position_2',
            itemId: '1', // "裏路地の不思議なバー"
            type: ShelfItemType.book,
          ),
          ShelfItemReference(
            id: '13_position_4',
            itemId: '4', // "夜の図書館"
            type: ShelfItemType.book,
          ),
        ],
      ),
    ];

    // Save default categories to file
    await _fileStorageService.writeJsonToFile(
      SHELF_CATEGORIES_FILE,
      categories.map((c) => c.toJson()).toList(),
    );

    _updateCategoryTitles();

    // オブジェクトデータを読み込み - キャッシュをクリアしてから
    try {
      _objectRepository.clearCache();

      // オブジェクトリポジトリから直接取得 (decoration_objects.jsonから)
      purchasedObjectsForAddDialog =
          await _objectRepository.getPurchasedObjects();

      print(
        'デフォルトデータロード時に ${purchasedObjectsForAddDialog.length} 個の購入済みオブジェクトを読み込みました',
      );
      for (var obj in purchasedObjectsForAddDialog) {
        print(
          '  - ${obj.name}: ${obj.imagePath} (isPurchased: ${obj.isPurchased})',
        );
      }
    } catch (e) {
      print('オブジェクトデータの読み込みに失敗しました: $e');
      // ここではデフォルトデータを使わず、空のリストにする
      // ハードコーディングされた値を使わないようにする
      purchasedObjectsForAddDialog = [];
    }
  }

  // 本の情報を事前にロード
  Future<void> _preloadBooks() async {
    try {
      // 必要な本のIDを収集
      final Set<String> neededBookIds = {};

      // カテゴリーからの本のID
      for (var category in categories) {
        for (var item in category.items) {
          if (item.type == ShelfItemType.book) {
            neededBookIds.add(item.itemId);
          }
        }
      }

      // お気に入りバナーからの本のID
      for (var favorite in favoriteBooksForAddDialog) {
        neededBookIds.add(favorite.bookId);
      }

      // 各本の情報をロード
      for (var bookId in neededBookIds) {
        final book = await _bookRepository.getBookById(bookId);
        if (book != null) {
          _bookCache[bookId] = book;
        }
      }
    } catch (e) {
      print('本のプリロード中にエラーが発生しました: $e');
    }
  }

  // オブジェクトイメージを事前にロードする
  Future<void> _preloadObjects() async {
    try {
      // 必要なオブジェクトのIDを収集
      final Set<String> neededObjectIds = {};

      // カテゴリーからのオブジェクトのID
      for (var category in categories) {
        for (var item in category.items) {
          if (item.type == ShelfItemType.object) {
            neededObjectIds.add(item.itemId);
          }
        }
      }

      // 購入済みオブジェクトのキャッシュを更新
      for (var obj in purchasedObjectsForAddDialog) {
        print('Caching object: ${obj.id} - ${obj.name} (${obj.imagePath})');
        _objectCache[obj.id] = obj;
        neededObjectIds.remove(obj.id); // すでに読み込み済みなので除外
      }

      // まだ読み込まれていないオブジェクトを取得
      if (neededObjectIds.isNotEmpty) {
        print(
          'Loading ${neededObjectIds.length} additional objects: ${neededObjectIds.join(', ')}',
        );
        for (var objectId in neededObjectIds) {
          final object = await _objectRepository.getObjectById(objectId);
          if (object != null) {
            print(
              'Loaded additional object: ${object.id} - ${object.name} (${object.imagePath})',
            );
            _objectCache[objectId] = object;
          } else {
            print('Failed to load object with ID: $objectId');
          }
        }
      }

      // オブジェクトの総数を出力
      print('Total cached objects: ${_objectCache.length}');
    } catch (e) {
      print('オブジェクトのプリロード中にエラーが発生しました: $e');
    }
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
      // 3段目（お気に入り）- マイコレクションから変更
      ShelfSection(
        title: 'お気に入り',
        topPosition: 0.12 + 0.28 * 1.7, // 1段目の位置 + (段間隔 × 1.7) = 約0.596
        titleToBookGap: 0.04, // タイトルから本までの間隔
        bookToShelfGap: -0.006, // 本から棚板までの間隔
        booksPerScreen: 5, // 1画面あたりの本の数
        bookHeightRatio: 1.3, // 本の幅に対する高さの比率
      ),
    ];
  }

  // バイブレーション関数を追加
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

  // 編集モードの切り替え - asyncに変更
  Future<void> _toggleEditMode() async {
    // 編集モードがONになるときはバイブレーション
    if (!_isEditMode) {
      await _generateHapticFeedback();
    }

    setState(() {
      _isEditMode = !_isEditMode;

      if (_isEditMode) {
        // 編集モードをオンにしたらアニメーション開始
        _shakeController.forward();
      } else {
        // 編集モードをオフにしたらアニメーション停止
        _shakeController.stop();
        _shakeController.reset();

        // 編集モードを終了したら変更を保存
        _saveData();
      }
    });
  }

  // 本棚からアイテムを削除
  void _removeItem(int categoryIndex, int itemIndex) {
    setState(() {
      categories[categoryIndex].items.removeAt(itemIndex);
    });

    // Save changes immediately
    _saveData();
  }

  // 本を追加
  void _addBook(int categoryIndex, String bookId, int position) {
    setState(() {
      // 位置情報を含むIDを追加
      final String newId =
          '${DateTime.now().millisecondsSinceEpoch}_position_$position';
      final newItemRef = ShelfItemReference(
        id: newId,
        itemId: bookId,
        type: ShelfItemType.book,
      );

      // 既存の位置にアイテムがある場合は入れ替え、なければ追加
      bool replaced = false;
      for (int i = 0; i < categories[categoryIndex].items.length; i++) {
        if (categories[categoryIndex].items[i].id.contains(
          '_position_$position',
        )) {
          categories[categoryIndex].items[i] = newItemRef;
          replaced = true;
          break;
        }
      }

      if (!replaced) {
        categories[categoryIndex].items.add(newItemRef);
      }
    });

    // Save changes immediately
    _saveData();
  }

  // オブジェクトを追加
  void _addObject(int categoryIndex, String objectId, int position) {
    setState(() {
      // 位置情報を含むIDを追加
      final String newId =
          '${DateTime.now().millisecondsSinceEpoch}_position_$position';
      final newItemRef = ShelfItemReference(
        id: newId,
        itemId: objectId,
        type: ShelfItemType.object,
      );

      // 既存の位置にアイテムがある場合は入れ替え、なければ追加
      bool replaced = false;
      for (int i = 0; i < categories[categoryIndex].items.length; i++) {
        if (categories[categoryIndex].items[i].id.contains(
          '_position_$position',
        )) {
          categories[categoryIndex].items[i] = newItemRef;
          replaced = true;
          break;
        }
      }

      if (!replaced) {
        categories[categoryIndex].items.add(newItemRef);
      }
    });

    // Save changes immediately
    _saveData();
  }

  // お気に入り一覧画面に遷移
  void _navigateToFavoritesScreen() async {
    final result = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const FavoritesScreen()));

    // 結果がオブジェクトの場合、そのオブジェクトを配置するためのダイアログを表示
    if (result != null && result is DecorationObject) {
      _showSelectPositionDialog(result);
    } else {
      // 結果がない場合やキャンセルされた場合は、データを再読み込み
      _loadData();
    }
  }

  // オブジェクトを配置する位置を選択するダイアログ
  Future<void> _showSelectPositionDialog(DecorationObject object) async {
    // 各カテゴリの利用可能な位置を取得
    Map<String, List<int>> availablePositions = {};

    for (var i = 0; i < categories.length; i++) {
      final category = categories[i];
      final maxItems = _maxItemsPerCategory[category.id] ?? 5;

      // 既存の位置を取得
      Set<int> usedPositions = {};
      for (var item in category.items) {
        final posMatch = RegExp(r'_position_(\d+)').firstMatch(item.id);
        if (posMatch != null) {
          final pos = int.parse(posMatch.group(1)!);
          usedPositions.add(pos);
        }
      }

      // 利用可能な位置を計算
      List<int> available = [];
      for (var j = 0; j < maxItems; j++) {
        if (!usedPositions.contains(j)) {
          available.add(j);
        }
      }

      availablePositions[category.id] = available;
    }

    // 空きがある棚だけを表示用に抽出
    List<PositionOption> options = [];

    for (var i = 0; i < categories.length; i++) {
      final category = categories[i];
      final available = availablePositions[category.id] ?? [];

      if (available.isNotEmpty) {
        for (var pos in available) {
          options.add(
            PositionOption(
              categoryIndex: i,
              position: pos,
              categoryName: category.title,
              positionName: '位置 ${pos + 1}',
            ),
          );
        }
      }
    }

    // 選択肢がない場合
    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('配置できる空きスペースがありません。不要なアイテムを削除してください。')),
      );
      return;
    }

    // 配置位置選択ダイアログを表示
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('「${object.name}」を配置する場所を選択'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: options.length,
              itemBuilder: (context, index) {
                final option = options[index];
                return ListTile(
                  title: Text(
                    '${option.categoryName} - ${option.positionName}',
                  ),
                  onTap: () {
                    // 選択された位置にオブジェクトを配置
                    _addObject(
                      option.categoryIndex,
                      object.id,
                      option.position,
                    );
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('キャンセル'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // 削除確認ダイアログを表示
  Future<void> _showDeleteConfirmDialog(
    int categoryIndex,
    int itemIndex,
  ) async {
    final itemRef = categories[categoryIndex].items[itemIndex];
    String itemName = "";
    String itemType = "";

    // アイテムの種類に応じて表示内容を変更
    if (itemRef.type == ShelfItemType.book) {
      final app_models.Book? book = _bookCache[itemRef.itemId];
      itemName = book?.title ?? "この本";
      itemType = "本";
    } else {
      final DecorationObject? object = _objectCache[itemRef.itemId];
      itemName = object?.name ?? "このオブジェクト";
      itemType = "オブジェクト";
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('${itemType}の削除'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('「$itemName」を本棚から削除しますか？'),
                const SizedBox(height: 10),
                Text('※${itemType}自体は倉庫に残ります'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('キャンセル'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('削除する', style: TextStyle(color: Colors.red)),
              onPressed: () {
                _removeItem(categoryIndex, itemIndex);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // 日付のフォーマット
  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }

  // アイテム追加ダイアログを表示
  Future<void> _showAddItemDialog(int categoryIndex, int position) async {
    // ダイアログを表示する前にお気に入りデータとオブジェクトデータを再読み込み
    try {
      // お気に入り絵本データの読み込み
      final favoritesData = await _fileStorageService.readJsonFromFile(
        FAVORITE_BOOKS_FILE,
      );
      if (favoritesData != null) {
        setState(() {
          favoriteBooksForAddDialog =
              (favoritesData as List)
                  .map((json) => FavoriteBookReference.fromJson(json))
                  .toList();
        });
      }

      // キャッシュをクリアしてから読み込み直す
      _objectRepository.clearCache();

      // 購入済みオブジェクトデータの読み込み
      purchasedObjectsForAddDialog =
          await _objectRepository.getPurchasedObjects();

      print(
        'ダイアログ表示前に ${purchasedObjectsForAddDialog.length} 個の購入済みオブジェクトを読み込みました',
      );
      for (var obj in purchasedObjectsForAddDialog) {
        print(
          '  - ${obj.name}: ${obj.imagePath} (isPurchased: ${obj.isPurchased})',
        );
      }

      // データの再読み込み
      await _preloadBooks();
      await _preloadObjects();
    } catch (e) {
      print('Error reloading data for dialog: $e');
    }

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        // タブコントローラー
        final tabController = DefaultTabController(
          length: 2,
          child: AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // タブバー
                const TabBar(
                  tabs: [
                    Tab(text: 'お気に入り絵本', icon: Icon(Icons.book)),
                    Tab(text: 'インテリア', icon: Icon(Icons.emoji_objects)),
                  ],
                  labelColor: Colors.blue,
                  unselectedLabelColor: Colors.grey,
                ),

                // タブビュー
                SizedBox(
                  width: double.maxFinite,
                  height: 300,
                  child: TabBarView(
                    children: [
                      // お気に入り絵本リスト
                      favoriteBooksForAddDialog.isEmpty
                          ? const Center(child: Text('お気に入りに登録された本がありません'))
                          : ListView.builder(
                            itemCount: favoriteBooksForAddDialog.length,
                            itemBuilder: (context, index) {
                              final favoriteRef =
                                  favoriteBooksForAddDialog[index];
                              final app_models.Book? book =
                                  _bookCache[favoriteRef.bookId];

                              return ListTile(
                                leading:
                                    book != null
                                        ? Image.asset(
                                          book.coverAssetPath,
                                          width: 40,
                                          height: 60,
                                          fit: BoxFit.cover,
                                        )
                                        : const Icon(Icons.book),
                                title: Text(book?.title ?? 'タイトル不明'),
                                subtitle: Text(
                                  '登録日: ${_formatDate(favoriteRef.registeredAt)}',
                                ),
                                onTap: () {
                                  _addBook(
                                    categoryIndex,
                                    favoriteRef.bookId,
                                    position,
                                  );
                                  Navigator.of(context).pop();
                                },
                              );
                            },
                          ),

                      // オブジェクトリスト
                      purchasedObjectsForAddDialog.isEmpty
                          ? const Center(child: Text('購入済みのインテリアがありません'))
                          : ListView.builder(
                            itemCount: purchasedObjectsForAddDialog.length,
                            itemBuilder: (context, index) {
                              final object =
                                  purchasedObjectsForAddDialog[index];

                              return ListTile(
                                leading: Image.asset(
                                  object.imagePath,
                                  width: 40,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    print(
                                      'Image error in dialog: ${object.imagePath}: $error',
                                    );
                                    return Container(
                                      color: Colors.amber[100],
                                      width: 40,
                                      height: 60,
                                      child: const Icon(
                                        Icons.emoji_objects,
                                        color: Colors.brown,
                                      ),
                                    );
                                  },
                                ),
                                title: Text(object.name),
                                subtitle: Text(
                                  object.purchaseDate != null
                                      ? '購入日: ${_formatDate(object.purchaseDate!)}'
                                      : object.description.substring(
                                            0,
                                            object.description.length > 20
                                                ? 20
                                                : object.description.length,
                                          ) +
                                          (object.description.length > 20
                                              ? '...'
                                              : ''),
                                ),
                                onTap: () {
                                  _addObject(
                                    categoryIndex,
                                    object.id,
                                    position,
                                  );
                                  Navigator.of(context).pop();
                                },
                              );
                            },
                          ),
                    ],
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('キャンセル'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );

        return tabController;
      },
    );
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
          image: AssetImage('assets/room_background_my_1.png'),
          fit: BoxFit.fill, // 画面いっぱいに引き伸ばし
        ),
      ),
      child: GestureDetector(
        onLongPress: () {
          // 長押しで編集モード開始
          if (!_isEditMode) {
            _toggleEditMode(); // asyncメソッドを呼び出す
          }
        },
        onTap: () {
          // 編集モード時は画面タップで編集モードを終了
          if (_isEditMode) {
            _toggleEditMode(); // asyncメソッドを呼び出す
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
                'assets/shelf_background_my_1.png',
                fit: BoxFit.fill,
              ),
            ),

            // 本棚タイトルプレート
            Positioned(
              top:
                  _screenHeight *
                  _shelfBackgroundTopPercent *
                  1.2, // 画面上部から適切な位置に調整
              left: 0,
              right: 0,
              child: Center(
                child: Image.asset(
                  'assets/plate_my_1.png',
                  width: _screenWidth * 0.5, // プレートの幅（調整可能）
                  fit: BoxFit.contain,
                ),
              ),
            ),

            // 中間層2: 棚と本
            for (
              int i = 0;
              i < _shelfSections.length && i < categories.length;
              i++
            )
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

            // マイアイテム一覧へのボタン
            Positioned(
              bottom: _screenHeight * 0.07,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 150, // 固定幅を設定
                  child: ElevatedButton.icon(
                    icon: const Icon(
                      Icons.favorite,
                      color: Colors.red,
                      size: 18,
                    ),
                    label: Text(
                      'Myアイテム',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          // 上方向のぼかし
                          Shadow(
                            offset: const Offset(0, -1.5),
                            blurRadius: 3.0,
                            color: Colors.grey.shade800.withOpacity(0.7),
                          ),
                          // 下方向のぼかし
                          Shadow(
                            offset: const Offset(0, 1.5),
                            blurRadius: 3.0,
                            color: Colors.grey.shade800.withOpacity(0.7),
                          ),
                          // 左方向のぼかし
                          Shadow(
                            offset: const Offset(-1.5, 0),
                            blurRadius: 3.0,
                            color: Colors.grey.shade800.withOpacity(0.7),
                          ),
                          // 右方向のぼかし
                          Shadow(
                            offset: const Offset(1.5, 0),
                            blurRadius: 3.0,
                            color: Colors.grey.shade800.withOpacity(0.7),
                          ),
                        ],
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent, // 完全透過
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                        side: const BorderSide(color: Colors.white, width: 1.5),
                      ),
                    ),
                    onPressed: _navigateToFavoritesScreen,
                  ),
                ),
              ),
            ),

            // シェアボタン（Myアイテムボタンの下に配置）
            Positioned(
              bottom: _screenHeight * 0.01,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 150, // 同じ固定幅を設定
                  child: ElevatedButton.icon(
                    icon: const Icon(
                      Icons.share,
                      color: Colors.white,
                      size: 17,
                    ),
                    label: Text(
                      'シェアする',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          // 上方向のぼかし
                          Shadow(
                            offset: const Offset(0, -1.5),
                            blurRadius: 3.0,
                            color: Colors.grey.shade800.withOpacity(0.7),
                          ),
                          // 下方向のぼかし
                          Shadow(
                            offset: const Offset(0, 1.5),
                            blurRadius: 3.0,
                            color: Colors.grey.shade800.withOpacity(0.7),
                          ),
                          // 左方向のぼかし
                          Shadow(
                            offset: const Offset(-1.5, 0),
                            blurRadius: 3.0,
                            color: Colors.grey.shade800.withOpacity(0.7),
                          ),
                          // 右方向のぼかし
                          Shadow(
                            offset: const Offset(1.5, 0),
                            blurRadius: 3.0,
                            color: Colors.grey.shade800.withOpacity(0.7),
                          ),
                        ],
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent, // 完全透過
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                        side: const BorderSide(color: Colors.white, width: 1.5),
                      ),
                    ),
                    onPressed: () {
                      // SNSシェア機能を実装
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('SNSシェアが押されました')),
                      );
                    },
                  ),
                ),
              ),
            ),

            // ローディングインジケーター
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
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
    double itemWidth;

    if (section.booksPerScreen == 3) {
      itemWidth = (_screenWidth - sideMargin * 2) / 3;
    } else {
      itemWidth = (_screenWidth - sideMargin * 2) / 5;
    }

    final double itemHeight = itemWidth * section.bookHeightRatio;

    // 本の上端位置 - タイトルとの間隔は維持
    final double itemsTop = titleY + (_screenHeight * section.titleToBookGap);

    // 棚板の上端位置
    final double shelfY =
        itemsTop + itemHeight + (_screenHeight * section.bookToShelfGap);

    // このカテゴリの最大アイテム数を取得
    final int maxItems =
        _maxItemsPerCategory[categories[categoryIndex].id] ??
        section.booksPerScreen;

    return [
      // 棚板
      Positioned(
        top: shelfY,
        left: shelfLeftMargin,
        width: shelfBoardWidth,
        child: Image.asset(
          categoryIndex == 0
              ? 'assets/shelf_board_my_1.png'
              : 'assets/shelf_board_my_1-23.png',
          height:
              categoryIndex == 0
                  ? _screenHeight *
                      0.04 // 1段目の棚板は従来のサイズ
                  : _screenHeight * 0.08, // 2・3段目の棚板は大きくする
          fit: BoxFit.fill,
        ),
      ),

      // アイテムのリスト
      Positioned(
        top: itemsTop,
        left: sideMargin,
        width: effectiveWidth,
        height: itemHeight,
        child: _buildItemsList(
          items: categories[categoryIndex].items,
          maxItems: maxItems,
          itemWidth: itemWidth,
          itemHeight: itemHeight,
          categoryIndex: categoryIndex,
        ),
      ),
    ];
  }

  // アイテムのリストを作成するヘルパーメソッド
  Widget _buildItemsList({
    required List<ShelfItemReference> items,
    required int maxItems,
    required double itemWidth,
    required double itemHeight,
    required int categoryIndex,
  }) {
    // 固定位置のグリッドを作成するための配列
    List<Widget> gridSlots = List.generate(maxItems, (index) {
      // 現在のインデックスにアイテムがあるかどうかチェック
      ShelfItemReference? currentItemRef;
      int? itemIndexInList;

      for (int i = 0; i < items.length; i++) {
        if (items[i].id.contains('_position_${index}')) {
          currentItemRef = items[i];
          itemIndexInList = i;
          break;
        }
      }

      // 該当位置にアイテムがある場合はそのアイテムを、なければ空のスロットを表示
      if (currentItemRef != null && itemIndexInList != null) {
        return _buildItemWidget(
          itemRef: currentItemRef,
          width: itemWidth,
          height: itemHeight,
          itemIndex: itemIndexInList,
          categoryIndex: categoryIndex,
          position: index,
        );
      } else {
        return _buildEmptySlot(
          width: itemWidth,
          height: itemHeight,
          slotIndex: index,
          categoryIndex: categoryIndex,
        );
      }
    });

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: gridSlots,
    );
  }

  // アイテム（本またはオブジェクト）ウィジェット（編集モード対応）
  Widget _buildItemWidget({
    required ShelfItemReference itemRef,
    required double width,
    required double height,
    required int itemIndex,
    required int categoryIndex,
    required int position,
  }) {
    // アイテムが本の場合
    if (itemRef.type == ShelfItemType.book) {
      return _buildBookItem(
        itemRef: itemRef,
        width: width,
        height: height,
        itemIndex: itemIndex,
        categoryIndex: categoryIndex,
        position: position,
      );
    } else {
      // アイテムがオブジェクトの場合
      return _buildObjectItem(
        itemRef: itemRef,
        width: width,
        height: height,
        itemIndex: itemIndex,
        categoryIndex: categoryIndex,
        position: position,
      );
    }
  }

  // 本アイテムウィジェット
  Widget _buildBookItem({
    required ShelfItemReference itemRef,
    required double width,
    required double height,
    required int itemIndex,
    required int categoryIndex,
    required int position,
  }) {
    // 本の詳細情報をキャッシュから取得
    final app_models.Book? book = _bookCache[itemRef.itemId];

    if (book == null) {
      // 本の情報が見つからない場合はプレースホルダーを表示
      return Container(
        width: width,
        height: height,
        color: Colors.grey[300],
        child: const Center(
          child: Text('本のデータ\nが見つかりません', textAlign: TextAlign.center),
        ),
      );
    }

    // 各本ごとに異なる初期オフセットを計算（本のIDに基づいて）
    final offset =
        (int.parse(itemRef.id.replaceAll(RegExp(r'[^0-9]'), '')) % 10) /
        10; // 0.0～0.9の値を生成

    // 編集モード時の震える効果
    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        // 回転エフェクトを適用（編集モード時のみ、本ごとに位相をずらす）
        return Transform.rotate(
          angle:
              _isEditMode
                  ? sin((_shakeController.value + offset) * 2 * 3.14159) * 0.03
                  : 0,
          child: child,
        );
      },
      child: Stack(
        children: [
          // 本のコンテンツ
          DragTarget<Object>(
            onWillAccept: (data) {
              // 編集モード時のみドラッグを許可
              return _isEditMode && data != null;
            },
            onAccept: (data) {
              if (data is FavoriteBookReference) {
                // お気に入り一覧からの本をドロップした場合
                setState(() {
                  // 既存の本を取得
                  final existingItemRef = itemRef;

                  // 新しい本を作成して追加
                  final newItemRef = ShelfItemReference(
                    id:
                        '${DateTime.now().millisecondsSinceEpoch}_position_$position',
                    itemId: data.bookId,
                    type: ShelfItemType.book,
                  );

                  // 既存の本を削除
                  for (
                    int i = 0;
                    i < categories[categoryIndex].items.length;
                    i++
                  ) {
                    if (categories[categoryIndex].items[i].id ==
                        existingItemRef.id) {
                      categories[categoryIndex].items.removeAt(i);
                      break;
                    }
                  }

                  // 新しい本を追加
                  categories[categoryIndex].items.add(newItemRef);
                });

                // Save changes
                _saveData();
              } else if (data is DecorationObject) {
                // お気に入り一覧からのオブジェクトをドロップした場合
                setState(() {
                  // 既存のアイテムを取得
                  final existingItemRef = itemRef;

                  // 新しいオブジェクトを作成して追加
                  final newItemRef = ShelfItemReference(
                    id:
                        '${DateTime.now().millisecondsSinceEpoch}_position_$position',
                    itemId: data.id,
                    type: ShelfItemType.object,
                  );

                  // 既存のアイテムを削除
                  for (
                    int i = 0;
                    i < categories[categoryIndex].items.length;
                    i++
                  ) {
                    if (categories[categoryIndex].items[i].id ==
                        existingItemRef.id) {
                      categories[categoryIndex].items.removeAt(i);
                      break;
                    }
                  }

                  // 新しいオブジェクトを追加
                  categories[categoryIndex].items.add(newItemRef);
                });

                // Save changes
                _saveData();
              } else if (data is Map<String, dynamic>) {
                // 同じアイテムを同じ場所に置く場合は何もしない
                if (data['categoryIndex'] == categoryIndex &&
                    data['position'] == position)
                  return;

                setState(() {
                  // 元のアイテムを取得
                  final draggedItemRef =
                      categories[data['categoryIndex']]
                          .items[data['itemIndex']];

                  // 新しい位置情報を持つアイテムのコピーを作成
                  final updatedItemRef = ShelfItemReference(
                    id:
                        draggedItemRef.id.split('_position_')[0] +
                        '_position_$position',
                    itemId: draggedItemRef.itemId,
                    type: draggedItemRef.type,
                  );

                  // 元のアイテムを削除
                  categories[data['categoryIndex']].items.removeAt(
                    data['itemIndex'],
                  );

                  // 現在の位置のアイテムを一時保存
                  final existingItemRef = itemRef;

                  // 既存のアイテムを削除
                  for (
                    int i = 0;
                    i < categories[categoryIndex].items.length;
                    i++
                  ) {
                    if (categories[categoryIndex].items[i].id ==
                        existingItemRef.id) {
                      categories[categoryIndex].items.removeAt(i);
                      break;
                    }
                  }

                  // 新しいアイテムを現在の位置に追加
                  categories[categoryIndex].items.add(updatedItemRef);

                  // 元の位置に既存のアイテムを追加
                  final updatedExistingItemRef = ShelfItemReference(
                    id:
                        existingItemRef.id.split('_position_')[0] +
                        '_position_${data['position']}',
                    itemId: existingItemRef.itemId,
                    type: existingItemRef.type,
                  );
                  categories[data['categoryIndex']].items.add(
                    updatedExistingItemRef,
                  );
                });

                // Save changes
                _saveData();
              }
            },
            builder: (context, candidateData, rejectedData) {
              return Draggable<Map<String, dynamic>>(
                // ドラッグ＆ドロップで本を移動
                data:
                    _isEditMode
                        ? {
                          'itemIndex': itemIndex,
                          'categoryIndex': categoryIndex,
                          'position': position,
                        }
                        : null,
                feedback:
                    _isEditMode
                        ? Container(
                          width: width,
                          height: height,
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Image.asset(
                            book.coverAssetPath,
                            fit: BoxFit.contain,
                          ),
                        )
                        : const SizedBox(),
                childWhenDragging: Opacity(
                  opacity: 0.3,
                  child: Container(
                    width: width,
                    height: height,
                    padding: EdgeInsets.symmetric(horizontal: width * 0.05),
                    child: Image.asset(
                      book.coverAssetPath,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                child: GestureDetector(
                  onTap:
                      !_isEditMode
                          ? () {
                            Navigator.of(context).pushNamed(
                              '/bookOverview',
                              arguments: {'bookId': book.id},
                            );
                          }
                          : null,
                  onLongPress: () async {
                    // 長押しで編集モードを開始（バブリングを防止）
                    if (!_isEditMode) {
                      await _generateHapticFeedback(); // バイブレーション追加
                      _toggleEditMode();
                    }
                  },
                  child: Container(
                    width: width,
                    height: height,
                    padding: EdgeInsets.symmetric(horizontal: width * 0.05),
                    child: Image.asset(
                      book.coverAssetPath,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              );
            },
          ),

          // 削除ボタン（編集モード時のみ表示）
          if (_isEditMode)
            Positioned(
              top: 0,
              left: width * 0.05,
              child: GestureDetector(
                onTap: () => _showDeleteConfirmDialog(categoryIndex, itemIndex),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.remove,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),

          // アイテムのID表示（デバッグ用 - 実際のアプリでは非表示にする）
          if (_isEditMode && false) // falseを設定して非表示
            Positioned(
              bottom: 5,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black.withOpacity(0.5),
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  'ID: ${book.id}',
                  style: const TextStyle(color: Colors.white, fontSize: 8),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // オブジェクトアイテムウィジェット
  Widget _buildObjectItem({
    required ShelfItemReference itemRef,
    required double width,
    required double height,
    required int itemIndex,
    required int categoryIndex,
    required int position,
  }) {
    // オブジェクトの詳細情報をキャッシュから取得
    final DecorationObject? object = _objectCache[itemRef.itemId];

    if (object == null) {
      // オブジェクトの情報が見つからない場合はプレースホルダーを表示
      return Container(
        width: width,
        height: height,
        color: Colors.amber[100],
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.emoji_objects, color: Colors.brown, size: 30),
              Text(
                'オブジェクトデータ\nが見つかりません',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.brown),
              ),
            ],
          ),
        ),
      );
    }

    // デバッグログを追加
    print(
      'Building object item in shelf: ${object.name}, imagePath: ${object.imagePath}',
    );

    // 各オブジェクトごとに異なる初期オフセットを計算（オブジェクトのIDに基づいて）
    final offset =
        (int.parse(itemRef.id.replaceAll(RegExp(r'[^0-9]'), '')) % 10) /
        10; // 0.0～0.9の値を生成

    // 編集モード時の震える効果
    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        // 回転エフェクトを適用（編集モード時のみ、オブジェクトごとに位相をずらす）
        return Transform.rotate(
          angle:
              _isEditMode
                  ? sin((_shakeController.value + offset) * 2 * 3.14159) * 0.03
                  : 0,
          child: child,
        );
      },
      child: Stack(
        children: [
          // オブジェクトのコンテンツ
          DragTarget<Object>(
            onWillAccept: (data) {
              // 編集モード時のみドラッグを許可
              return _isEditMode && data != null;
            },
            onAccept: (data) {
              if (data is FavoriteBookReference) {
                // お気に入り一覧からの本をドロップした場合
                setState(() {
                  // 既存のオブジェクトを取得
                  final existingItemRef = itemRef;

                  // 新しい本を作成して追加
                  final newItemRef = ShelfItemReference(
                    id:
                        '${DateTime.now().millisecondsSinceEpoch}_position_$position',
                    itemId: data.bookId,
                    type: ShelfItemType.book,
                  );

                  // 既存のオブジェクトを削除
                  for (
                    int i = 0;
                    i < categories[categoryIndex].items.length;
                    i++
                  ) {
                    if (categories[categoryIndex].items[i].id ==
                        existingItemRef.id) {
                      categories[categoryIndex].items.removeAt(i);
                      break;
                    }
                  }

                  // 新しい本を追加
                  categories[categoryIndex].items.add(newItemRef);
                });

                // Save changes
                _saveData();
              } else if (data is DecorationObject) {
                // お気に入り一覧からのオブジェクトをドロップした場合
                setState(() {
                  // 既存のアイテムを取得
                  final existingItemRef = itemRef;

                  // 新しいオブジェクトを作成して追加
                  final newItemRef = ShelfItemReference(
                    id:
                        '${DateTime.now().millisecondsSinceEpoch}_position_$position',
                    itemId: data.id,
                    type: ShelfItemType.object,
                  );

                  // 既存のアイテムを削除
                  for (
                    int i = 0;
                    i < categories[categoryIndex].items.length;
                    i++
                  ) {
                    if (categories[categoryIndex].items[i].id ==
                        existingItemRef.id) {
                      categories[categoryIndex].items.removeAt(i);
                      break;
                    }
                  }

                  // 新しいオブジェクトを追加
                  categories[categoryIndex].items.add(newItemRef);
                });

                // Save changes
                _saveData();
              } else if (data is Map<String, dynamic>) {
                // 同じアイテムを同じ場所に置く場合は何もしない
                if (data['categoryIndex'] == categoryIndex &&
                    data['position'] == position)
                  return;

                setState(() {
                  // 元のアイテムを取得
                  final draggedItemRef =
                      categories[data['categoryIndex']]
                          .items[data['itemIndex']];

                  // 新しい位置情報を持つアイテムのコピーを作成
                  final updatedItemRef = ShelfItemReference(
                    id:
                        draggedItemRef.id.split('_position_')[0] +
                        '_position_$position',
                    itemId: draggedItemRef.itemId,
                    type: draggedItemRef.type,
                  );

                  // 元のアイテムを削除
                  categories[data['categoryIndex']].items.removeAt(
                    data['itemIndex'],
                  );

                  // 現在の位置のアイテムを一時保存
                  final existingItemRef = itemRef;

                  // 既存のアイテムを削除
                  for (
                    int i = 0;
                    i < categories[categoryIndex].items.length;
                    i++
                  ) {
                    if (categories[categoryIndex].items[i].id ==
                        existingItemRef.id) {
                      categories[categoryIndex].items.removeAt(i);
                      break;
                    }
                  }

                  // 新しいアイテムを現在の位置に追加
                  categories[categoryIndex].items.add(updatedItemRef);

                  // 元の位置に既存のアイテムを追加
                  final updatedExistingItemRef = ShelfItemReference(
                    id:
                        existingItemRef.id.split('_position_')[0] +
                        '_position_${data['position']}',
                    itemId: existingItemRef.itemId,
                    type: existingItemRef.type,
                  );
                  categories[data['categoryIndex']].items.add(
                    updatedExistingItemRef,
                  );
                });

                // Save changes
                _saveData();
              }
            },
            builder: (context, candidateData, rejectedData) {
              return Draggable<Map<String, dynamic>>(
                // ドラッグ＆ドロップでオブジェクトを移動
                data:
                    _isEditMode
                        ? {
                          'itemIndex': itemIndex,
                          'categoryIndex': categoryIndex,
                          'position': position,
                        }
                        : null,
                feedback:
                    _isEditMode
                        ? Container(
                          width: width,
                          height: height,
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Image.asset(
                            object.imagePath,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              print(
                                'Feedback image error: ${object.imagePath}: $error',
                              );
                              return Container(
                                color: Colors.amber[100],
                                child: const Icon(
                                  Icons.emoji_objects,
                                  size: 40,
                                  color: Colors.brown,
                                ),
                              );
                            },
                          ),
                        )
                        : const SizedBox(),
                childWhenDragging: Opacity(
                  opacity: 0.3,
                  child: Container(
                    width: width,
                    height: height,
                    padding: EdgeInsets.symmetric(horizontal: width * 0.05),
                    child: Image.asset(
                      object.imagePath,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        print(
                          'ChildWhenDragging image error: ${object.imagePath}: $error',
                        );
                        return Container(
                          color: Colors.amber[100],
                          child: const Icon(
                            Icons.emoji_objects,
                            size: 40,
                            color: Colors.brown,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                child: GestureDetector(
                  onTap:
                      !_isEditMode
                          ? () {
                            // 将来的に詳細画面を表示する予定
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('「${object.name}」をタップしました'),
                              ),
                            );
                          }
                          : null,
                  onLongPress: () async {
                    // 長押しで編集モードを開始（バブリングを防止）
                    if (!_isEditMode) {
                      await _generateHapticFeedback(); // バイブレーション追加
                      _toggleEditMode();
                    }
                  },
                  child: Container(
                    width: width,
                    height: height,
                    padding: EdgeInsets.symmetric(horizontal: width * 0.05),
                    child: Image.asset(
                      object.imagePath,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        print('Main image error: ${object.imagePath}: $error');
                        return Container(
                          color: Colors.amber[100],
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.emoji_objects,
                                size: 30,
                                color: Colors.brown,
                              ),
                              Text(
                                object.name,
                                style: const TextStyle(
                                  color: Colors.brown,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),

          // 削除ボタン（編集モード時のみ表示）
          if (_isEditMode)
            Positioned(
              top: 0,
              left: width * 0.05,
              child: GestureDetector(
                onTap: () => _showDeleteConfirmDialog(categoryIndex, itemIndex),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.remove,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 空のスロットウィジェット（編集モード時にアイテムを追加できる）
  Widget _buildEmptySlot({
    required double width,
    required double height,
    required int slotIndex,
    required int categoryIndex,
  }) {
    return GestureDetector(
      onTap:
          _isEditMode
              ? () => _showAddItemDialog(categoryIndex, slotIndex)
              : null,
      child: DragTarget<Object>(
        onWillAccept: (data) {
          // 編集モード時のみドラッグを許可
          return _isEditMode && data != null;
        },
        onAccept: (data) {
          setState(() {
            if (data is FavoriteBookReference) {
              // お気に入り一覧からの本をドロップした場合
              final newItemRef = ShelfItemReference(
                id:
                    '${DateTime.now().millisecondsSinceEpoch}_position_$slotIndex',
                itemId: data.bookId,
                type: ShelfItemType.book,
              );
              categories[categoryIndex].items.add(newItemRef);
            } else if (data is DecorationObject) {
              // お気に入り一覧からのオブジェクトをドロップした場合
              final newItemRef = ShelfItemReference(
                id:
                    '${DateTime.now().millisecondsSinceEpoch}_position_$slotIndex',
                itemId: data.id,
                type: ShelfItemType.object,
              );
              categories[categoryIndex].items.add(newItemRef);
            } else if (data is Map<String, dynamic>) {
              // 本棚内での移動の場合
              // ドラッグされたアイテムを取得
              final draggedItemRef =
                  categories[data['categoryIndex']].items[data['itemIndex']];

              // 新しい位置情報を持つアイテムのコピーを作成
              final updatedItemRef = ShelfItemReference(
                id:
                    draggedItemRef.id.split('_position_')[0] +
                    '_position_$slotIndex',
                itemId: draggedItemRef.itemId,
                type: draggedItemRef.type,
              );

              // 元のアイテムを削除
              categories[data['categoryIndex']].items.removeAt(
                data['itemIndex'],
              );

              // 新しい位置にアイテムを追加
              categories[categoryIndex].items.add(updatedItemRef);
            }
          });

          // Save changes
          _saveData();
        },
        builder: (context, candidateData, rejectedData) {
          return Container(
            width: width,
            height: height,
            padding: EdgeInsets.symmetric(horizontal: width * 0.05),
            child:
                _isEditMode
                    ? Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color:
                              candidateData.isNotEmpty
                                  ? Colors.green.withOpacity(0.8) // ドラッグ中はハイライト
                                  : Colors.white.withOpacity(0.5),
                          width: candidateData.isNotEmpty ? 3 : 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.add,
                          color:
                              candidateData.isNotEmpty
                                  ? Colors.green.withOpacity(0.8) // ドラッグ中はハイライト
                                  : Colors.white.withOpacity(0.7),
                          size: 30,
                        ),
                      ),
                    )
                    : const SizedBox(), // 編集モードでない場合は非表示
          );
        },
      ),
    );
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
      body: _buildBookshelfScreen(context),
    );
  }
}

// 位置選択ダイアログ用のオプションクラス
class PositionOption {
  final int categoryIndex;
  final int position;
  final String categoryName;
  final String positionName;

  PositionOption({
    required this.categoryIndex,
    required this.position,
    required this.categoryName,
    required this.positionName,
  });
}
