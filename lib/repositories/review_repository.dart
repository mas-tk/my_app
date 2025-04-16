// lib/repositories/review_repository.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import '../models/review_models.dart';
import '../services/file_storage_service.dart';

class ReviewRepository {
  // Constants for file names
  static const String REVIEWS_FILE_PREFIX = 'reviews_';
  static const String REVIEWS_ASSET_PREFIX = 'assets/data/reviews/';

  // FileStorageService instance
  final FileStorageService _fileStorageService = FileStorageService();

  // キャッシュ変数
  final Map<String, List<ReviewComment>> _cachedReviews = {};

  // Singleton pattern
  static final ReviewRepository _instance = ReviewRepository._internal();
  factory ReviewRepository() => _instance;
  ReviewRepository._internal();

  // キャッシュをクリア
  void clearCache() {
    _cachedReviews.clear();
    print('Cleared review cache');
  }

  // 特定の本のレビューを取得
  Future<List<ReviewComment>> getReviewsForBook(String bookId) async {
    // キャッシュをチェック
    if (_cachedReviews.containsKey(bookId)) {
      return _cachedReviews[bookId]!;
    }

    try {
      // ファイル名を構築
      final fileName = '${REVIEWS_FILE_PREFIX}${bookId}.json';
      final assetPath = '${REVIEWS_ASSET_PREFIX}book${bookId}_reviews.json';

      // ローカルファイルが存在することを確認
      await _fileStorageService.ensureLocalJsonFileExists(fileName, assetPath);

      // ローカルファイルから読み込み
      final reviewsData = await _fileStorageService.readJsonFromFile(fileName);

      if (reviewsData != null) {
        final List<ReviewComment> reviews =
            (reviewsData as List)
                .map((json) => ReviewComment.fromJson(json))
                .toList();

        // キャッシュに保存
        _cachedReviews[bookId] = reviews;
        return reviews;
      }

      // ローカルファイルが読み込めない場合はアセットから読み込む
      return await _loadInitialReviewsFromAsset(bookId);
    } catch (e) {
      print('Error loading reviews: $e');
      // エラー時はデフォルトデータを返す
      return _getDefaultReviews();
    }
  }

  // アセットから初期レビューデータを読み込む
  Future<List<ReviewComment>> _loadInitialReviewsFromAsset(
    String bookId,
  ) async {
    try {
      final assetPath = '${REVIEWS_ASSET_PREFIX}book${bookId}_reviews.json';
      final jsonString = await rootBundle.loadString(assetPath);
      final List<dynamic> jsonData = json.decode(jsonString);

      final List<ReviewComment> reviews =
          jsonData.map((json) => ReviewComment.fromJson(json)).toList();

      // ローカルファイルに保存
      final fileName = '${REVIEWS_FILE_PREFIX}${bookId}.json';
      await _fileStorageService.writeJsonToFile(fileName, jsonData);

      // キャッシュに保存
      _cachedReviews[bookId] = reviews;

      return reviews;
    } catch (e) {
      print('Error loading initial reviews: $e');
      // エラー時はデフォルトデータを返す
      return _getDefaultReviews();
    }
  }

  // レビューを追加
  Future<bool> addReview(String bookId, ReviewComment review) async {
    try {
      // 現在のレビューを取得
      final reviews = await getReviewsForBook(bookId);

      // 新しいレビューを追加
      reviews.insert(0, review);

      // ファイルに保存
      await saveReviews(bookId, reviews);

      return true;
    } catch (e) {
      print('Error adding review: $e');
      return false;
    }
  }

  // レビューにいいねを追加/削除
  Future<bool> toggleLike(String bookId, int reviewIndex) async {
    try {
      // 現在のレビューを取得
      final reviews = await getReviewsForBook(bookId);

      if (reviewIndex >= 0 && reviewIndex < reviews.length) {
        // いいねを切り替え
        reviews[reviewIndex].isLiked = !reviews[reviewIndex].isLiked;
        reviews[reviewIndex].likes += reviews[reviewIndex].isLiked ? 1 : -1;

        // ファイルに保存
        await saveReviews(bookId, reviews);

        return true;
      }

      return false;
    } catch (e) {
      print('Error toggling like: $e');
      return false;
    }
  }

  // レビューをファイルに保存
  Future<bool> saveReviews(String bookId, List<ReviewComment> reviews) async {
    try {
      // ファイル名を構築
      final fileName = '${REVIEWS_FILE_PREFIX}${bookId}.json';

      // JSONデータに変換
      final List<Map<String, dynamic>> reviewsData =
          reviews.map((review) => review.toJson()).toList();

      // ファイルに書き込み
      await _fileStorageService.writeJsonToFile(fileName, reviewsData);

      // キャッシュを更新
      _cachedReviews[bookId] = reviews;

      print('Reviews saved successfully');
      return true;
    } catch (e) {
      print('Error saving reviews: $e');
      return false;
    }
  }

  // デフォルトのレビューを生成
  List<ReviewComment> _getDefaultReviews() {
    return [
      ReviewComment(
        username: '田中さん',
        rating: 4.5,
        comment: 'とても素敵な絵本です。子供も大喜びでした。',
        date: DateTime.now().subtract(const Duration(days: 5)),
        likes: 42,
        isLiked: false,
      ),
      ReviewComment(
        username: '佐藤さん',
        rating: 5.0,
        comment: 'ストーリーも絵も素晴らしい。何度も読み返しています。',
        date: DateTime.now().subtract(const Duration(days: 10)),
        likes: 26,
        isLiked: false,
      ),
      ReviewComment(
        username: '鈴木さん',
        rating: 3.5,
        comment: '面白いですが、もう少し長いとよかったかも。',
        date: DateTime.now().subtract(const Duration(days: 15)),
        likes: 17,
        isLiked: false,
      ),
      ReviewComment(
        username: 'そういち',
        rating: 4.0,
        comment: '人間の方が怖い？',
        date: DateTime.now().subtract(const Duration(days: 18)),
        likes: 15,
        isLiked: false,
      ),
      ReviewComment(
        username: 'ぬを一',
        rating: 3.0,
        comment: '面白い漫画を見つけた',
        date: DateTime.now().subtract(const Duration(days: 25)),
        likes: 7,
        isLiked: false,
      ),
      ReviewComment(
        username: 'あきなり',
        rating: 4.0,
        comment: 'ウィルス持ってるからなぁ。主人公らは掛からない体質かな',
        date: DateTime.now().subtract(const Duration(days: 35)),
        likes: 5,
        isLiked: false,
      ),
    ];
  }
}
