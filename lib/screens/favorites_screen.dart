// lib/screens/favorites_screen.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/book_repository.dart';
import '../repositories/object_repository.dart'; // 追加: オブジェクトリポジトリ
import '../models/book_models.dart' as app_models;
import '../models/object_models.dart'; // 追加: オブジェクトモデル
import '../services/file_storage_service.dart';

// Favorite book reference model
class FavoriteBookReference {
  final String id;
  final String bookId;
  final DateTime registeredAt;

  FavoriteBookReference({
    required this.id,
    required this.bookId,
    required this.registeredAt,
  });

  factory FavoriteBookReference.fromJson(Map<String, dynamic> json) {
    return FavoriteBookReference(
      id: json['id'],
      bookId: json['bookId'],
      registeredAt: DateTime.parse(json['registeredAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bookId': bookId,
      'registeredAt': registeredAt.toIso8601String(),
    };
  }
}

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({Key? key}) : super(key: key);

  @override
  _FavoritesScreenState createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  // Constants for file names
  static const String FAVORITE_BOOKS_FILE = 'favorite_books.json';
  static const String FAVORITE_BOOKS_ASSET = 'assets/data/favorite_books.json';

  // Add FileStorageService instance
  final FileStorageService _fileStorageService = FileStorageService();

  // BookRepository instance
  final BookRepository _bookRepository = BookRepository();

  // ObjectRepository instance
  final ObjectRepository _objectRepository = ObjectRepository();

  // Book cache
  final Map<String, app_models.Book> _bookCache = {};

  // Object cache
  final Map<String, DecorationObject> _objectCache = {};

  // Favorite books data
  List<FavoriteBookReference> favoriteBooks = [];

  // Decoration objects data
  List<DecorationObject> purchasedObjects = [];
  List<DecorationObject> unpurchasedObjects = [];

  // Loading state
  bool _isLoading = true;

  // Tab controller
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadData();
  }

  // Load data from SharedPreferences and JSON files
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load favorite books
      await _loadFavoriteBooks();

      // Load decoration objects
      await _loadDecorationObjects();

      // Preload book data
      await _preloadBooks();

      // Preload object data
      await _preloadObjects();
    } catch (e) {
      print('データのロード中にエラーが発生しました: $e');
      await _loadDefaultData();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Load favorite books
  Future<void> _loadFavoriteBooks() async {
    try {
      // Ensure local file exists
      await _fileStorageService.ensureLocalJsonFileExists(
        FAVORITE_BOOKS_FILE,
        FAVORITE_BOOKS_ASSET,
      );

      // Try to load from local file first
      final favoritesData = await _fileStorageService.readJsonFromFile(
        FAVORITE_BOOKS_FILE,
      );

      if (favoritesData != null) {
        print('Loading favorite data from local file');
        favoriteBooks =
            (favoritesData as List)
                .map((json) => FavoriteBookReference.fromJson(json))
                .toList();

        // Update SharedPreferences for compatibility
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('favorite_books', jsonEncode(favoritesData));
      } else {
        // Fallback to SharedPreferences
        print('Loading favorite data from SharedPreferences');
        final prefs = await SharedPreferences.getInstance();
        final String? savedJson = prefs.getString('favorite_books');

        if (savedJson != null && savedJson.isNotEmpty) {
          final List<dynamic> jsonList = jsonDecode(savedJson);
          favoriteBooks =
              jsonList
                  .map((json) => FavoriteBookReference.fromJson(json))
                  .toList();

          // Save to local file for future use
          await _fileStorageService.writeJsonToFile(
            FAVORITE_BOOKS_FILE,
            jsonList,
          );
        } else {
          // If nothing found, load from asset
          print('Loading favorite data from asset');
          final String favoritesJson = await rootBundle.loadString(
            FAVORITE_BOOKS_ASSET,
          );
          final List<dynamic> favoritesData = json.decode(favoritesJson);
          favoriteBooks =
              favoritesData
                  .map((json) => FavoriteBookReference.fromJson(json))
                  .toList();

          // Save to local storage
          await _fileStorageService.writeJsonToFile(
            FAVORITE_BOOKS_FILE,
            favoritesData,
          );

          // Also update SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('favorite_books', jsonEncode(favoritesData));
        }
      }
    } catch (e) {
      print('Error loading favorite books: $e');
      throw e;
    }
  }

  // Load decoration objects
  Future<void> _loadDecorationObjects() async {
    try {
      // キャッシュをクリアして新鮮なデータを確実に取得
      _objectRepository.clearCache();

      // 購入済みオブジェクトを取得
      purchasedObjects = await _objectRepository.getPurchasedObjects();
      print('Loaded ${purchasedObjects.length} purchased objects');
      for (var obj in purchasedObjects) {
        print(
          '  - ${obj.name}: ${obj.imagePath} (isPurchased: ${obj.isPurchased})',
        );
      }

      // 未購入オブジェクトを取得
      unpurchasedObjects = await _objectRepository.getUnpurchasedObjects();
      print('Loaded ${unpurchasedObjects.length} unpurchased objects');
      for (var obj in unpurchasedObjects) {
        print(
          '  - ${obj.name}: ${obj.imagePath} (isPurchased: ${obj.isPurchased})',
        );
      }

      print(
        'Loaded ${purchasedObjects.length} purchased objects and ${unpurchasedObjects.length} unpurchased objects',
      );
    } catch (e) {
      print('Error loading decoration objects: $e');
      throw e;
    }
  }

  // _loadDefaultData メソッドの修正
  Future<void> _loadDefaultData() async {
    // Default favorite data
    favoriteBooks = [
      FavoriteBookReference(
        id: 'fav1',
        bookId: '1',
        registeredAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      FavoriteBookReference(
        id: 'fav2',
        bookId: '2',
        registeredAt: DateTime.now().subtract(const Duration(days: 25)),
      ),
      FavoriteBookReference(
        id: 'fav3',
        bookId: '3',
        registeredAt: DateTime.now().subtract(const Duration(days: 20)),
      ),
      FavoriteBookReference(
        id: 'fav4',
        bookId: '4',
        registeredAt: DateTime.now().subtract(const Duration(days: 15)),
      ),
      FavoriteBookReference(
        id: 'fav5',
        bookId: '3',
        registeredAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
    ];

    // Save default data to both file and SharedPreferences
    try {
      // Save to local file
      await _fileStorageService.writeJsonToFile(
        FAVORITE_BOOKS_FILE,
        favoriteBooks.map((f) => f.toJson()).toList(),
      );

      // Also update SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(
        favoriteBooks.map((f) => f.toJson()).toList(),
      );
      await prefs.setString('favorite_books', jsonString);

      print('デフォルトのお気に入りデータを保存しました');
    } catch (e) {
      print('デフォルトデータの保存中にエラーが発生しました: $e');
    }

    // オブジェクトデータを読み込む
    try {
      // キャッシュをクリアしてから読み込み
      _objectRepository.clearCache();

      // デコレーションオブジェクトをロード
      await _loadDecorationObjects();
    } catch (e) {
      print('デフォルトのオブジェクトデータの読み込みに失敗しました: $e');
      // ハードコードされた値を使わないようにする - この部分を完全に削除または以下のように修正
      if (purchasedObjects.isEmpty && unpurchasedObjects.isEmpty) {
        print('JSONファイルからの読み込みに失敗しました - 空のリストを使用します');
        purchasedObjects = [];
        unpurchasedObjects = [];
      }
    }
  }

  // [Unused] Method to remove a favorite book - functionality moved to book_overview_screen
  Future<void> _removeFavorite(FavoriteBookReference favorite) async {
    try {
      setState(() {
        favoriteBooks.removeWhere((item) => item.id == favorite.id);
      });

      // Save changes to both file and SharedPreferences
      await _saveFavorites();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('お気に入りから削除しました')));
    } catch (e) {
      print('Error removing favorite: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('削除中にエラーが発生しました')));
    }
  }

  // Save favorites to persistent storage
  Future<void> _saveFavorites() async {
    try {
      // Save to local file
      await _fileStorageService.writeJsonToFile(
        FAVORITE_BOOKS_FILE,
        favoriteBooks.map((f) => f.toJson()).toList(),
      );

      // Also update SharedPreferences for compatibility
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(
        favoriteBooks.map((f) => f.toJson()).toList(),
      );
      await prefs.setString('favorite_books', jsonString);

      print('お気に入りデータを保存しました');
    } catch (e) {
      print('お気に入りデータの保存中にエラーが発生しました: $e');
      rethrow;
    }
  }

  // Preload book data
  Future<void> _preloadBooks() async {
    try {
      // Collect needed book IDs
      final Set<String> neededBookIds = {};
      for (var favorite in favoriteBooks) {
        neededBookIds.add(favorite.bookId);
      }

      // Load each book's data
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

  // Preload object data
  Future<void> _preloadObjects() async {
    try {
      // すべてのオブジェクトをキャッシュに格納
      for (var obj in [...purchasedObjects, ...unpurchasedObjects]) {
        _objectCache[obj.id] = obj;
      }
    } catch (e) {
      print('オブジェクトのプリロード中にエラーが発生しました: $e');
    }
  }

  // Format date
  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }

  // Build favorite book item widget
  Widget _buildFavoriteBookItem(FavoriteBookReference favoriteRef) {
    final app_models.Book? book = _bookCache[favoriteRef.bookId];

    if (book == null) {
      return const Center(child: Text('本の情報が見つかりません'));
    }

    return GestureDetector(
      onTap: () {
        Navigator.of(context)
            .pushNamed('/bookOverview', arguments: {'bookId': book.id})
            .then(
              (_) => _loadData(),
            ); // Reload data when returning from book detail
      },
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(book.coverAssetPath, fit: BoxFit.cover),
              ),
            ),
          ),
          // タイトル表示部分を削除し、登録日のみ表示
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '登録日: ${_formatDate(favoriteRef.registeredAt)}',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  // Build decoration object item widget
  Widget _buildObjectItem(DecorationObject object) {
    // デバッグログを追加
    print(
      'Building object item: ${object.name}, imagePath: ${object.imagePath}, isPurchased: ${object.isPurchased}',
    );

    return GestureDetector(
      onTap: () {
        // オブジェクトが購入済みの場合はメッセージを表示
        if (object.isPurchased) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('「${object.name}」をタップしました')));
        } else {
          // 未購入の場合は購入ダイアログを表示
          _showPurchaseDialog(object);
        }
      },
      child: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          object.imagePath,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            // エラー情報を出力
                            print(
                              'Image error for ${object.imagePath}: $error',
                            );
                            print('Stack trace: $stackTrace');
                            // 画像が見つからない場合のフォールバック
                            return Container(
                              color: Colors.amber[200], // 色を変更して問題を視覚的に確認
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

                      // 未購入の場合は鍵アイコンを表示
                      if (!object.isPurchased)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.lock,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      object.name,
                      style: const TextStyle(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    if (object.isPurchased && object.purchaseDate != null)
                      Text(
                        '購入日: ${_formatDate(object.purchaseDate!)}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                        maxLines: 1,
                      )
                    else if (!object.isPurchased && object.price > 0)
                      Text(
                        '価格: ${object.price.toInt()} ${object.currency}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.orange,
                        ),
                        maxLines: 1,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // オブジェクト購入ダイアログを表示
  Future<void> _showPurchaseDialog(DecorationObject object) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('「${object.name}」を購入'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(object.description),
                const SizedBox(height: 10),
                Text('価格: ${object.price.toInt()} ${object.currency}'),
                const SizedBox(height: 20),
                const Text('このオブジェクトを購入しますか？'),
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
              child: const Text('購入する'),
              onPressed: () async {
                // オブジェクトを購入
                final success = await _objectRepository.purchaseObject(
                  object.id,
                );

                if (success) {
                  // 購入成功時はデータを再読み込み
                  Navigator.of(context).pop();
                  await _loadData();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('「${object.name}」を購入しました')),
                  );
                } else {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('購入に失敗しました')));
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'マイアイテム',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          tabs: const [
            Tab(icon: Icon(Icons.book), text: 'お気に入り絵本'),
            Tab(icon: Icon(Icons.emoji_objects), text: 'インテリア'),
          ],
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                controller: _tabController,
                children: [
                  // お気に入り絵本タブ
                  Container(
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/wooden-frame-background.jpg'),
                        fit: BoxFit.cover,
                        opacity: 0.3,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            'お気に入り登録された本 (${favoriteBooks.length}冊)',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          child:
                              favoriteBooks.isEmpty
                                  ? const Center(
                                    child: Text('お気に入りに登録された本はありません'),
                                  )
                                  : GridView.builder(
                                    padding: const EdgeInsets.all(16),
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 3,
                                          childAspectRatio: 0.7,
                                          crossAxisSpacing: 16,
                                          mainAxisSpacing: 24,
                                        ),
                                    itemCount: favoriteBooks.length,
                                    itemBuilder: (context, index) {
                                      return _buildFavoriteBookItem(
                                        favoriteBooks[index],
                                      );
                                    },
                                  ),
                        ),
                      ],
                    ),
                  ),

                  // インテリアタブ
                  Container(
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/wooden-frame-background.jpg'),
                        fit: BoxFit.cover,
                        opacity: 0.3,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            '所有インテリア (${purchasedObjects.length}個)',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          child:
                              purchasedObjects.isEmpty &&
                                      unpurchasedObjects.isEmpty
                                  ? const Center(child: Text('インテリアがありません'))
                                  : ListView(
                                    children: [
                                      // 購入済みオブジェクト
                                      GridView.builder(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        padding: const EdgeInsets.all(16),
                                        gridDelegate:
                                            const SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: 3,
                                              childAspectRatio: 0.7,
                                              crossAxisSpacing: 16,
                                              mainAxisSpacing: 24,
                                            ),
                                        itemCount: purchasedObjects.length,
                                        itemBuilder: (context, index) {
                                          // デバッグ用のプリント
                                          print(
                                            'Building objects tab with ${purchasedObjects.length} purchased objects',
                                          );
                                          print(
                                            'Unpurchased objects: ${unpurchasedObjects.length}',
                                          );
                                          return _buildObjectItem(
                                            purchasedObjects[index],
                                          );
                                        },
                                      ),

                                      // 未購入オブジェクト（存在する場合）
                                      if (unpurchasedObjects.isNotEmpty) ...[
                                        const Padding(
                                          padding: EdgeInsets.fromLTRB(
                                            16,
                                            16,
                                            16,
                                            8,
                                          ),
                                          child: Text(
                                            '購入可能なインテリア',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        GridView.builder(
                                          shrinkWrap: true,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          padding: const EdgeInsets.all(16),
                                          gridDelegate:
                                              const SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount: 3,
                                                childAspectRatio: 0.7,
                                                crossAxisSpacing: 16,
                                                mainAxisSpacing: 24,
                                              ),
                                          itemCount: unpurchasedObjects.length,
                                          itemBuilder: (context, index) {
                                            return _buildObjectItem(
                                              unpurchasedObjects[index],
                                            );
                                          },
                                        ),
                                      ],
                                    ],
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
    );
  }
}
