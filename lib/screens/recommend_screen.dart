// lib/screens/recommend_screen.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/book_models.dart';
import '../repositories/book_repository.dart';

// タググループモデル
class TagGroup {
  final String id;
  final String name;
  final List<Tag> tags;

  TagGroup({required this.id, required this.name, required this.tags});
}

// タグモデル
class Tag {
  final String id;
  final String name;
  final String? icon; // 絵文字やアイコンのコード
  bool isSelected;

  Tag({
    required this.id,
    required this.name,
    this.icon,
    this.isSelected = false,
  });
}

class RecommendScreen extends StatefulWidget {
  const RecommendScreen({Key? key}) : super(key: key);

  @override
  _RecommendScreenState createState() => _RecommendScreenState();
}

class _RecommendScreenState extends State<RecommendScreen> {
  final BookRepository _bookRepository = BookRepository();
  List<Book> _allBooks = [];
  List<Book> _filteredBooks = [];
  List<Book> _searchResults = [];
  bool _isLoading = true;
  String _searchQuery = '';
  bool _isSearching = false;

  // 選択されたタグのリスト
  final List<Tag> _selectedTags = [];

  // タググループとタグの定義
  final List<TagGroup> _tagGroups = [
    TagGroup(
      id: 'pickup',
      name: 'ピックアップ',
      tags: [
        Tag(id: 'featured', name: '注目の作品', icon: '✨'),
        Tag(id: 'new', name: '新着作品', icon: '🆕'),
        Tag(id: 'popular', name: '人気作品', icon: '🔥'),
      ],
    ),
    TagGroup(
      id: 'genres',
      name: 'ジャンル',
      tags: [
        Tag(id: 'fantasy', name: 'ファンタジー', icon: '🧚'),
        Tag(id: 'adventure', name: '冒険', icon: '🚀'),
        Tag(id: 'growth', name: '成長', icon: '🌱'),
        Tag(id: 'memory', name: '思い出', icon: '📸'),
        Tag(id: 'promise', name: '約束', icon: '🤝'),
        Tag(id: 'educational', name: 'ためになる', icon: '📚'),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  // 本のデータを読み込む
  Future<void> _loadBooks() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // ローカルのJSONファイルから本のデータを読み込む
      final String jsonString = await rootBundle.loadString(
        'assets/data/books.json',
      );
      final List<dynamic> booksData = json.decode(jsonString);
      final List<Book> books =
          booksData.map((json) => Book.fromJson(json)).toList();

      setState(() {
        _allBooks = books;
        _filteredBooks = books;
        _searchResults = books;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading books: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 検索機能
  void _performSearch(String query) {
    setState(() {
      _searchQuery = query;
      _isSearching = query.isNotEmpty;

      if (query.isEmpty) {
        _searchResults = _filteredBooks;
        return;
      }

      // タイトルまたは概要に検索クエリが含まれる本をフィルタリング
      _searchResults =
          _filteredBooks.where((book) {
            final titleMatch = book.title.toLowerCase().contains(
              query.toLowerCase(),
            );
            final summaryMatch =
                book.summary != null
                    ? book.summary!.toLowerCase().contains(query.toLowerCase())
                    : false;
            return titleMatch || summaryMatch;
          }).toList();
    });
  }

  // タグに基づいて本をフィルタリング
  void _filterBooks() {
    if (_selectedTags.isEmpty) {
      // タグが選択されていない場合はすべての本を表示
      setState(() {
        _filteredBooks = _allBooks;
        _searchResults = _allBooks;
      });
      return;
    }

    // 選択されたタグのIDを取得
    final List<String> selectedTagIds =
        _selectedTags.map((tag) => tag.id).toList();

    // 選択されたタグのジャンル名を取得（小文字に変換）
    final List<String> selectedGenres =
        _selectedTags.map((tag) => tag.name.toLowerCase()).toList();

    setState(() {
      _filteredBooks =
          _allBooks.where((book) {
            // ピックアップタグの処理
            if (selectedTagIds.contains('featured') &&
                book.rating != null &&
                book.rating! >= 4.5) {
              return true;
            }
            if (selectedTagIds.contains('new') && book.id.startsWith('1')) {
              return true;
            }
            if (selectedTagIds.contains('popular') &&
                book.likes != null &&
                book.likes! >= 400) {
              return true;
            }

            // ジャンルタグの処理
            if (book.genres != null) {
              for (var genre in book.genres!) {
                if (selectedGenres.contains(genre.toLowerCase())) {
                  return true;
                }
              }
            }
            return false;
          }).toList();

      // 検索結果も更新
      if (_searchQuery.isNotEmpty) {
        _performSearch(_searchQuery);
      } else {
        _searchResults = _filteredBooks;
      }
    });
  }

  // タグ選択ダイアログを表示
  void _showTagSelectDialog() {
    // ダイアログ内で使用する一時的なタグ選択状態
    List<TagGroup> tempTagGroups = [];

    // 現在の選択状態をコピー
    for (var group in _tagGroups) {
      List<Tag> tempTags = [];
      for (var tag in group.tags) {
        tempTags.add(
          Tag(
            id: tag.id,
            name: tag.name,
            icon: tag.icon,
            isSelected: _selectedTags.any(
              (selectedTag) => selectedTag.id == tag.id,
            ),
          ),
        );
      }
      tempTagGroups.add(
        TagGroup(id: group.id, name: group.name, tags: tempTags),
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // ヘッダー
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade700,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'タグを選択',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // タグリスト
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: tempTagGroups.length,
                      itemBuilder: (context, groupIndex) {
                        final group = tempTagGroups[groupIndex];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 16,
                                bottom: 8,
                                left: 8,
                              ),
                              child: Text(
                                group.name,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children:
                                  group.tags.map((tag) {
                                    return FilterChip(
                                      selected: tag.isSelected,
                                      backgroundColor: Colors.grey.shade200,
                                      selectedColor: Colors.blue.shade100,
                                      checkmarkColor: Colors.blue.shade700,
                                      label: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (tag.icon != null)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                right: 4,
                                              ),
                                              child: Text(tag.icon!),
                                            ),
                                          Text(tag.name),
                                        ],
                                      ),
                                      onSelected: (selected) {
                                        setModalState(() {
                                          tag.isSelected = selected;
                                        });
                                      },
                                    );
                                  }).toList(),
                            ),
                            const SizedBox(height: 8),
                          ],
                        );
                      },
                    ),
                  ),

                  // 絞り込みボタン
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              // すべてのタグを未選択に
                              for (var group in tempTagGroups) {
                                for (var tag in group.tags) {
                                  tag.isSelected = false;
                                }
                              }
                            });
                          },
                          child: Text(
                            'リセット',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            // 選択されたタグを反映
                            _selectedTags.clear();
                            for (var group in tempTagGroups) {
                              for (var tag in group.tags) {
                                if (tag.isSelected) {
                                  _selectedTags.add(tag);
                                }
                              }
                            }

                            // 本をフィルタリング
                            _filterBooks();

                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          child: const Text(
                            '絞り込む',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // タグチップを削除
  void _removeTag(Tag tag) {
    setState(() {
      _selectedTags.removeWhere((t) => t.id == tag.id);
      _filterBooks();
    });
  }

  // 本を表示するカード
  Widget _buildBookCard(Book book) {
    // ランダムに本のページ画像を取得（カルーセル用）
    List<String> carouselImages = [book.coverAssetPath];
    if (book.pages != null && book.pages!.isNotEmpty) {
      // ランダムに最大3つの本のページを追加
      final random = Random();
      final pageIndices = <int>{};

      while (pageIndices.length < min(3, book.pages!.length)) {
        pageIndices.add(random.nextInt(book.pages!.length));
      }

      for (var index in pageIndices) {
        carouselImages.add(book.pages![index].baseImage);
      }
    }

    // 現在表示中の画像インデックス
    final ValueNotifier<int> currentImageIndex = ValueNotifier(0);

    return GestureDetector(
      // カード全体をタップ可能に
      onTap: () {
        Navigator.of(
          context,
        ).pushNamed('/bookOverview', arguments: {'bookId': book.id});
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 本の表紙画像（カルーセル機能）
            SizedBox(
              width: 120,
              height: 180,
              child: Stack(
                children: [
                  // 画像表示 - PageViewを循環させる
                  PageView.builder(
                    itemCount: null, // nullを設定して無限スクロールを実現
                    onPageChanged: (index) {
                      // 実際のインデックスを計算（循環）
                      currentImageIndex.value = index % carouselImages.length;
                    },
                    itemBuilder: (context, index) {
                      // 実際のインデックスを計算（循環）
                      final actualIndex = index % carouselImages.length;
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          carouselImages[actualIndex],
                          width: 120,
                          height: 180,
                          fit: BoxFit.cover,
                        ),
                      );
                    },
                  ),

                  // インジケーター
                  if (carouselImages.length > 1)
                    Positioned(
                      bottom: 8,
                      left: 0,
                      right: 0,
                      child: ValueListenableBuilder<int>(
                        valueListenable: currentImageIndex,
                        builder: (context, value, child) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              carouselImages.length,
                              (index) => Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color:
                                      index == value
                                          ? Colors.white
                                          : Colors.white.withOpacity(0.4),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // 本の情報（ポップのようなデザイン）
            Expanded(
              child: Transform.rotate(
                angle: 0.01, // わずかに傾ける
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // タイトル
                      Text(
                        book.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 8),

                      // ジャンルタグ
                      if (book.genres != null && book.genres!.isNotEmpty)
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children:
                              book.genres!.map((genre) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    genre,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.blue.shade800,
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),

                      const SizedBox(height: 8),

                      // 統計情報
                      Row(
                        children: [
                          Icon(
                            Icons.remove_red_eye,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${book.views ?? 0}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 12),

                          Icon(Icons.favorite, size: 14, color: Colors.red),
                          const SizedBox(width: 2),
                          Text(
                            '${book.likes ?? 0}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 12),

                          Icon(Icons.comment, size: 14, color: Colors.blue),
                          const SizedBox(width: 2),
                          Text(
                            '${book.comments ?? 0}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),

                          Spacer(),

                          if (book.rating != null)
                            Row(
                              children: [
                                Text(
                                  book.rating!.toString(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Colors.amber.shade800,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(Icons.star, size: 14, color: Colors.amber),
                              ],
                            ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // 概要
                      if (book.summary != null)
                        Text(
                          book.summary!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),

                      // 「詳細を見る」ボタンを削除し、下部に若干の余白を追加
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // ヘッダー部分 - 下向き矢印を削除
          Container(
            color: Colors.blue.shade700,
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.of(context).padding.top + 8,
              16,
              16,
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),

                // 検索バー - 背景を透過
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2), // 背景を半透明に
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    onChanged: (value) {
                      _performSearch(value);
                    },
                    style: TextStyle(color: Colors.white), // テキスト色を白に
                    decoration: InputDecoration(
                      hintText: '絵本を検索...',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                      ), // ヒントテキストも半透明の白に
                      prefixIcon: Icon(Icons.search, color: Colors.white),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // フィルターチップ - 背景を透過
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.transparent, // 背景色を透過に変更
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 選択されたタグを表示
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        _selectedTags.map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100.withOpacity(
                                0.9,
                              ), // 若干透過
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (tag.icon != null)
                                  Text(
                                    tag.icon! + ' ',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                Text(tag.name, style: TextStyle(fontSize: 12)),
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: () => _removeTag(tag),
                                  child: Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                  ),
                ),

                // タグ選択ボタン - 背景色を半透明に
                GestureDetector(
                  onTap: _showTagSelectDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue),
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.white.withOpacity(0.7), // 背景を半透明に
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.add, size: 16, color: Colors.blue),
                        SizedBox(width: 4),
                        Text('絞り込み', style: TextStyle(color: Colors.blue)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 本のリスト
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/wooden-frame-background.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
              child:
                  _isLoading
                      ? Center(child: CircularProgressIndicator())
                      : _isSearching && _searchResults.isEmpty
                      ? Center(
                        child: Text(
                          '検索条件に一致する絵本が見つかりませんでした。',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white),
                        ),
                      )
                      : _selectedTags.isNotEmpty && _filteredBooks.isEmpty
                      ? Center(
                        child: Text(
                          '条件に一致する絵本が見つかりませんでした。\n条件を変更してお試しください。',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white),
                        ),
                      )
                      : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount:
                            _isSearching
                                ? _searchResults.length
                                : _filteredBooks.length,
                        itemBuilder: (context, index) {
                          return _buildBookCard(
                            _isSearching
                                ? _searchResults[index]
                                : _filteredBooks[index],
                          );
                        },
                      ),
            ),
          ),
        ],
      ),
    );
  }
}
