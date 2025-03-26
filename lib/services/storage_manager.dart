// lib/services/storage_manager.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/book_models.dart';

class StorageManager {
  // Singleton pattern
  static final StorageManager _instance = StorageManager._internal();
  factory StorageManager() => _instance;
  StorageManager._internal();

  // Base URL for remote assets
  static const String remoteBaseUrl = 'https://yourapi.com/assets';

  // プリインストールされた本をチェックし、必要に応じてコピー
  Future<void> initializePreinstalledBooks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool initialized =
          prefs.getBool('preinstalled_initialized') ?? false;

      // 既に初期化済みなら何もしない
      if (initialized) return;

      print('Initializing preinstalled books...');

      // プリインストールされた本のJSONを読み込む
      final String jsonString = await rootBundle.loadString(
        'assets/data/books.json',
      );
      final List<dynamic> booksData = json.decode(jsonString);
      final List<Book> books =
          booksData.map((json) => Book.fromJson(json)).toList();

      // カテゴリJSONを読み込む
      final String categoriesString = await rootBundle.loadString(
        'assets/data/categories.json',
      );
      final List<dynamic> categoriesData = json.decode(categoriesString);
      final List<BookCategory> categories =
          categoriesData.map((json) => BookCategory.fromJson(json)).toList();

      // カテゴリを保存
      await saveCategories(categories);

      // プリインストール対象の本IDリスト（最初の15冊）
      final List<String> preinstalledIds = [];
      for (var i = 0; i < books.length && i < 15; i++) {
        preinstalledIds.add(books[i].id);
      }

      // 各本を保存して「ダウンロード済み」としてマーク
      for (var book in books) {
        if (preinstalledIds.contains(book.id)) {
          // 本データを保存
          await saveBook(book);

          // ダウンロード済みとしてマーク
          await markBookAsDownloaded(book.id);
        }
      }

      // 初期化完了としてマーク
      await prefs.setBool('preinstalled_initialized', true);
      print('Preinstalled books initialized successfully');
    } catch (e) {
      print('Error initializing preinstalled books: $e');
    }
  }

  // Save book data to local storage
  Future<bool> saveBook(Book book) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String bookJson = json.encode(book.toJson());
      await prefs.setString('book_${book.id}', bookJson);
      return true;
    } catch (e) {
      print('Error saving book: $e');
      return false;
    }
  }

  // Get book data from local storage
  Future<Book?> getBook(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? bookJson = prefs.getString('book_$id');

      if (bookJson == null) return null;

      return Book.fromJson(json.decode(bookJson));
    } catch (e) {
      print('Error getting book: $e');
      return null;
    }
  }

  // Save category data to local storage
  Future<bool> saveCategories(List<BookCategory> categories) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String categoriesJson = json.encode(
        categories.map((category) => category.toJson()).toList(),
      );
      await prefs.setString('book_categories', categoriesJson);
      return true;
    } catch (e) {
      print('Error saving categories: $e');
      return false;
    }
  }

  // Get categories from local storage
  Future<List<BookCategory>?> getCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? categoriesJson = prefs.getString('book_categories');

      if (categoriesJson == null) return null;

      final List<dynamic> decoded = json.decode(categoriesJson);
      return decoded.map((json) => BookCategory.fromJson(json)).toList();
    } catch (e) {
      print('Error getting categories: $e');
      return null;
    }
  }

  // Get list of downloaded books
  Future<List<String>> getDownloadedBookIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList('downloaded_books') ?? [];
    } catch (e) {
      print('Error getting downloaded book IDs: $e');
      return [];
    }
  }

  // Mark a book as downloaded
  Future<bool> markBookAsDownloaded(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> downloadedBooks = await getDownloadedBookIds();

      if (!downloadedBooks.contains(id)) {
        downloadedBooks.add(id);
        await prefs.setStringList('downloaded_books', downloadedBooks);
      }

      return true;
    } catch (e) {
      print('Error marking book as downloaded: $e');
      return false;
    }
  }

  // Check if a book is downloaded
  Future<bool> isBookDownloaded(String id) async {
    final downloadedBooks = await getDownloadedBookIds();
    return downloadedBooks.contains(id);
  }

  // Download a single asset to local storage
  Future<String?> downloadAsset(String remotePath) async {
    try {
      // Check if asset already exists in preinstalled assets
      if (await _isAssetExists('assets/$remotePath')) {
        return 'assets/$remotePath';
      }

      final String fileName = remotePath.split('/').last;
      final directory = await getApplicationDocumentsDirectory();
      final String localPath = '${directory.path}/assets/$fileName';

      // Create directory if it doesn't exist
      final Directory assetDir = Directory('${directory.path}/assets');
      if (!await assetDir.exists()) {
        await assetDir.create(recursive: true);
      }

      // Check if file already exists
      final File localFile = File(localPath);
      if (await localFile.exists()) {
        return localPath;
      }

      // Download file
      final response = await http.get(Uri.parse('$remoteBaseUrl/$remotePath'));

      if (response.statusCode == 200) {
        await localFile.writeAsBytes(response.bodyBytes);
        return localPath;
      } else {
        throw Exception('Failed to download asset: ${response.statusCode}');
      }
    } catch (e) {
      print('Error downloading asset: $e');
      return null;
    }
  }

  // プリインストールされたアセットのパスを取得
  Future<String?> getLocalAssetPath(String remotePath) async {
    try {
      // まずプリインストールされたアセットとして存在するか確認
      if (await _isAssetExists('assets/$remotePath')) {
        return 'assets/$remotePath';
      }

      // 既にassets/で始まるパスの場合はそのまま返す
      if (remotePath.startsWith('assets/') &&
          await _isAssetExists(remotePath)) {
        return remotePath;
      }

      // ファイル名を抽出
      final String fileName = remotePath.split('/').last;

      // ダウンロードされたアセットとして存在するか確認
      final directory = await getApplicationDocumentsDirectory();
      final String localPath = '${directory.path}/assets/$fileName';

      final File localFile = File(localPath);
      if (await localFile.exists()) {
        return localPath;
      }

      // 見つからない場合
      return null;
    } catch (e) {
      print('Error getting local asset path: $e');
      return null;
    }
  }

  // アセットが存在するかチェック
  Future<bool> _isAssetExists(String assetPath) async {
    try {
      await rootBundle.load(assetPath);
      return true;
    } catch (_) {
      return false;
    }
  }

  // Delete a downloaded book and its assets
  Future<bool> deleteDownloadedBook(String id) async {
    try {
      final book = await getBook(id);
      if (book == null) return false;

      // プリインストールされた本の場合、データ自体は削除せず、ダウンロード済みリストから削除するだけ
      if (book.coverAssetPath.startsWith('assets/')) {
        // ダウンロード済みリストから削除
        final prefs = await SharedPreferences.getInstance();
        final List<String> downloadedBooks = await getDownloadedBookIds();
        downloadedBooks.remove(id);
        await prefs.setStringList('downloaded_books', downloadedBooks);
        return true;
      }

      // Delete book data
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('book_$id');

      // Remove from downloaded books list
      final List<String> downloadedBooks = await getDownloadedBookIds();
      downloadedBooks.remove(id);
      await prefs.setStringList('downloaded_books', downloadedBooks);

      // Delete book assets
      final directory = await getApplicationDocumentsDirectory();
      final String assetDir = '${directory.path}/assets';

      // Delete cover image
      final coverFile = File(
        '$assetDir/${book.coverAssetPath.split('/').last}',
      );
      if (await coverFile.exists()) await coverFile.delete();

      // Delete page images
      if (book.pages != null) {
        for (var page in book.pages!) {
          final baseImageFile = File(
            '$assetDir/${page.baseImage.split('/').last}',
          );
          if (await baseImageFile.exists()) await baseImageFile.delete();

          final textImageFile = File(
            '$assetDir/${page.textImage.split('/').last}',
          );
          if (await textImageFile.exists()) await textImageFile.delete();
        }
      }

      // Delete audio tracks
      if (book.audio != null) {
        for (var track in book.audio!.tracks) {
          final audioFile = File(
            '$assetDir/${track.assetPath.split('/').last}',
          );
          if (await audioFile.exists()) await audioFile.delete();
        }
      }

      return true;
    } catch (e) {
      print('Error deleting downloaded book: $e');
      return false;
    }
  }

  // Get all book data from local storage
  Future<List<Book>> getAllLocalBooks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Book> books = [];

      // Get all keys that start with 'book_'
      final allKeys = prefs.getKeys();
      final bookKeys = allKeys.where((key) => key.startsWith('book_')).toList();

      // Get each book
      for (var key in bookKeys) {
        final String? bookJson = prefs.getString(key);
        if (bookJson != null) {
          try {
            final book = Book.fromJson(json.decode(bookJson));
            books.add(book);
          } catch (e) {
            print('Error parsing book data for key $key: $e');
          }
        }
      }

      return books;
    } catch (e) {
      print('Error getting all local books: $e');
      return [];
    }
  }

  // Check if we have an internet connection
  Future<bool> hasInternetConnection() async {
    try {
      final response = await http.get(Uri.parse('https://www.google.com'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
