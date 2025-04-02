// lib/services/book_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;
import '../models/book_models.dart';

class BookService {
  // Base API URL - change to your actual API endpoint
  static const String baseUrl = 'https://yourapi.com/api/books';

  // Singleton pattern
  static final BookService _instance = BookService._internal();
  factory BookService() => _instance;
  BookService._internal();

  // Get book list from API
  Future<List<Book>> getBooks() async {
    try {
      // For remote API
      final response = await http.get(Uri.parse(baseUrl));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Book.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load books: ${response.statusCode}');
      }
    } catch (e) {
      // Fallback to local JSON if API fails
      return _loadLocalBooks();
    }
  }

  // Get book by ID from API
  Future<Book> getBookById(String id) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/$id'));

      if (response.statusCode == 200) {
        return Book.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to load book: ${response.statusCode}');
      }
    } catch (e) {
      // Fallback to local JSON if API fails
      final books = await _loadLocalBooks();
      final book = books.firstWhere(
        (book) => book.id == id,
        orElse: () => throw Exception('Book not found: $id'),
      );
      return book;
    }
  }

  // Get categories from API
  Future<List<BookCategory>> getCategories() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/categories'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => BookCategory.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load categories: ${response.statusCode}');
      }
    } catch (e) {
      // Fallback to local JSON if API fails
      return _loadLocalCategories();
    }
  }

  // Download book assets (images, audio) for offline use
  Future<bool> downloadBookAssets(String bookId) async {
    try {
      // Get book details
      final book = await getBookById(bookId);

      // Download logic for cover image
      await _downloadAsset(book.coverAssetPath);

      // Download book pages
      if (book.pages != null) {
        for (var page in book.pages!) {
          await _downloadAsset(page.baseImage);
          await _downloadAsset(page.textImage);
        }
      }

      // Download audio tracks
      if (book.audio != null) {
        for (var track in book.audio!.tracks) {
          await _downloadAsset(track.assetPath);
        }
      }

      return true;
    } catch (e) {
      print('Error downloading book assets: $e');
      return false;
    }
  }

  // Helper to download a single asset
  Future<void> _downloadAsset(String assetPath) async {
    // Implementation will depend on how you want to store assets
    // Example using http to download and path_provider to store:
    // 1. Check if asset already exists locally
    // 2. If not, download from remote server
    // 3. Save to local storage
  }

  // Load books from local JSON file (fallback)
  Future<List<Book>> _loadLocalBooks() async {
    try {
      final jsonString = await rootBundle.loadString('assets/data/books.json');
      final List<dynamic> jsonData = json.decode(jsonString);
      print('Loaded ${jsonData.length} books from local JSON');

      // 各本のIDをログに出力
      final books = jsonData.map((json) => Book.fromJson(json)).toList();
      print('Book IDs: ${books.map((b) => b.id).join(", ")}');

      return books;
    } catch (e) {
      print('Error loading local books: $e');
      return [];
    }
  }

  // Load categories from local JSON file (fallback)
  Future<List<BookCategory>> _loadLocalCategories() async {
    final jsonString = await rootBundle.loadString(
      'assets/data/categories.json',
    );
    final List<dynamic> jsonData = json.decode(jsonString);
    return jsonData.map((json) => BookCategory.fromJson(json)).toList();
  }
}
