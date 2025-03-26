// lib/repositories/book_repository.dart
import 'dart:async';
import '../models/book_models.dart';
import '../services/book_service.dart';
import '../services/storage_manager.dart';

class BookRepository {
  final BookService _bookService = BookService();
  final StorageManager _storageManager = StorageManager();

  // _storageManager へのアクセサを追加
  StorageManager get storageManager => _storageManager;

  // Singleton pattern
  static final BookRepository _instance = BookRepository._internal();
  factory BookRepository() => _instance;
  BookRepository._internal();

  // アプリ起動時にプリインストールされた本を初期化
  Future<void> initializePreinstalledBooks() async {
    await _storageManager.initializePreinstalledBooks();
  }

  // Get books by category
  Future<List<Book>> getBooksByCategory(String categoryId) async {
    try {
      // Try to get categories from local storage first
      final categories = await _storageManager.getCategories();

      if (categories != null) {
        // Find the category
        final category = categories.firstWhere(
          (c) => c.id == categoryId,
          orElse: () => throw Exception('Category not found: $categoryId'),
        );

        // Get each book by ID
        final books = <Book>[];
        for (var bookId in category.bookIds) {
          final book = await getBookById(bookId);
          if (book != null) {
            books.add(book);
          }
        }

        return books;
      } else {
        // If not in local storage, fetch from API
        final allCategories = await _bookService.getCategories();

        // Save to local storage for future use
        await _storageManager.saveCategories(allCategories);

        final category = allCategories.firstWhere(
          (c) => c.id == categoryId,
          orElse: () => throw Exception('Category not found: $categoryId'),
        );

        final books = <Book>[];
        for (var bookId in category.bookIds) {
          final book = await getBookById(bookId);
          if (book != null) {
            books.add(book);
          }
        }

        return books;
      }
    } catch (e) {
      print('Error getting books by category: $e');
      return [];
    }
  }

  // Get all categories
  Future<List<BookCategory>> getAllCategories() async {
    try {
      // Check local storage first
      final localCategories = await _storageManager.getCategories();

      if (localCategories != null && localCategories.isNotEmpty) {
        return localCategories;
      }

      // If not in local storage, fetch from API
      final apiCategories = await _bookService.getCategories();

      // Save to local storage
      await _storageManager.saveCategories(apiCategories);

      return apiCategories;
    } catch (e) {
      print('Error getting all categories: $e');
      return [];
    }
  }

  // Get book by ID (with offline support)
  Future<Book?> getBookById(String id) async {
    try {
      // Check if we have the book in local storage
      final localBook = await _storageManager.getBook(id);

      if (localBook != null) {
        return localBook;
      }

      // If not in local storage, fetch from API
      final apiBook = await _bookService.getBookById(id);

      // Save to local storage
      await _storageManager.saveBook(apiBook);

      return apiBook;
    } catch (e) {
      print('Error getting book by ID: $e');
      return null;
    }
  }

  // Download a book for offline reading
  Future<bool> downloadBook(String id) async {
    try {
      // First make sure we have the book data
      final book = await getBookById(id);
      if (book == null) return false;

      // Download cover image
      final coverPath = await _storageManager.downloadAsset(
        book.coverAssetPath,
      );
      if (coverPath == null) return false;

      // Download pages
      if (book.pages != null) {
        for (var page in book.pages!) {
          await _storageManager.downloadAsset(page.baseImage);
          await _storageManager.downloadAsset(page.textImage);
        }
      }

      // Download audio
      if (book.audio != null) {
        for (var track in book.audio!.tracks) {
          await _storageManager.downloadAsset(track.assetPath);
        }
      }

      // Mark book as downloaded
      await _storageManager.markBookAsDownloaded(id);

      return true;
    } catch (e) {
      print('Error downloading book: $e');
      return false;
    }
  }

  // Check if a book is downloaded
  Future<bool> isBookDownloaded(String id) {
    return _storageManager.isBookDownloaded(id);
  }

  // Get all downloaded books
  Future<List<Book>> getDownloadedBooks() async {
    try {
      final downloadedIds = await _storageManager.getDownloadedBookIds();
      final books = <Book>[];

      for (var id in downloadedIds) {
        final book = await _storageManager.getBook(id);
        if (book != null) {
          books.add(book);
        }
      }

      return books;
    } catch (e) {
      print('Error getting downloaded books: $e');
      return [];
    }
  }

  // Delete a downloaded book
  Future<bool> deleteDownloadedBook(String id) {
    return _storageManager.deleteDownloadedBook(id);
  }

  // Get the local path for an asset
  Future<String> getAssetPath(String remotePath) async {
    // まずローカルのパスを確認
    final localPath = await _storageManager.getLocalAssetPath(remotePath);

    // ローカルパスがある場合はそれを返す
    if (localPath != null) {
      return localPath;
    }

    // なければリモートパスをそのまま返す
    return remotePath;
  }
}
