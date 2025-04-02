// lib/models/shelf_models.dart
import 'dart:convert';

// アイテム種別の列挙型
enum ShelfItemType { book, object }

// 棚のアイテム（本またはオブジェクト）の共通インターフェース
class ShelfItemReference {
  final String id; // 位置情報付きID (例: "1_position_0")
  final String itemId; // books.jsonまたはdecoration_objects.jsonのID
  final ShelfItemType type; // アイテムの種類（本またはオブジェクト）

  ShelfItemReference({
    required this.id,
    required this.itemId,
    required this.type,
  });

  // JSONから作成するファクトリーメソッド
  factory ShelfItemReference.fromJson(Map<String, dynamic> json) {
    return ShelfItemReference(
      id: json['id'],
      itemId: json['itemId'],
      type: _typeFromString(json['type']),
    );
  }

  // JSONに変換するメソッド
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'itemId': itemId,
      'type': type == ShelfItemType.book ? 'book' : 'object',
    };
  }

  // 文字列からShelfItemTypeへの変換ヘルパー
  static ShelfItemType _typeFromString(String? typeStr) {
    return typeStr == 'object' ? ShelfItemType.object : ShelfItemType.book;
  }
}

// カテゴリー（棚）のデータモデル
class ShelfCategory {
  final String id;
  final String title;
  List<ShelfItemReference> items; // 編集可能にするため、final を削除

  ShelfCategory({required this.id, required this.title, required this.items});

  // JSONから作成するファクトリーメソッド
  factory ShelfCategory.fromJson(Map<String, dynamic> json) {
    List<ShelfItemReference> itemsList;

    // 下位互換性のために、古い形式のJSONも処理できるようにする
    if (json.containsKey('books')) {
      // 古い形式: 'books'キーがある場合
      itemsList =
          (json['books'] as List).map((bookJson) {
            // 旧形式のbookIdをitemIdとして使用
            if (bookJson.containsKey('bookId')) {
              return ShelfItemReference(
                id: bookJson['id'],
                itemId: bookJson['bookId'],
                type: ShelfItemType.book,
              );
            }
            // 既に新形式になっている場合
            return ShelfItemReference.fromJson(bookJson);
          }).toList();
    } else {
      // 新しい形式: 'items'キーを使用
      itemsList =
          (json['items'] as List)
              .map((itemJson) => ShelfItemReference.fromJson(itemJson))
              .toList();
    }

    return ShelfCategory(
      id: json['id'],
      title: json['title'],
      items: itemsList,
    );
  }

  // JSONに変換するメソッド
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}
