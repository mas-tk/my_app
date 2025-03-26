// lib/models/book_models.dart
import 'dart:convert';

// Comprehensive Book Model
class Book {
  final String id;
  final String title;
  final String coverAssetPath;
  final String? summary;
  final int? views;
  final int? likes;
  final int? comments;
  final double? rating;
  final List<String>? genres;
  final List<BookPage>? pages;
  final BookAudio? audio;

  Book({
    required this.id,
    required this.title,
    required this.coverAssetPath,
    this.summary,
    this.views,
    this.likes,
    this.comments,
    this.rating,
    this.genres,
    this.pages,
    this.audio,
  });

  // Create from JSON
  factory Book.fromJson(Map<String, dynamic> json) {
    List<BookPage>? pages;
    if (json.containsKey('pages') && json['pages'] != null) {
      pages =
          (json['pages'] as List)
              .map((pageJson) => BookPage.fromJson(pageJson))
              .toList();
    }

    List<String>? genres;
    if (json.containsKey('genres') && json['genres'] != null) {
      genres = List<String>.from(json['genres']);
    }

    BookAudio? audio;
    if (json.containsKey('audio') && json['audio'] != null) {
      audio = BookAudio.fromJson(json['audio']);
    }

    return Book(
      id: json['id'],
      title: json['title'],
      coverAssetPath: json['coverAssetPath'],
      summary: json['summary'],
      views: json['views'],
      likes: json['likes'],
      comments: json['comments'],
      rating: json['rating']?.toDouble(),
      genres: genres,
      pages: pages,
      audio: audio,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'coverAssetPath': coverAssetPath,
      'summary': summary,
      'views': views,
      'likes': likes,
      'comments': comments,
      'rating': rating,
      'genres': genres,
      'pages': pages?.map((page) => page.toJson()).toList(),
      'audio': audio?.toJson(),
    };
  }
}

// Book Page Model
class BookPage {
  final String pageId;
  final String baseImage;
  final String textImage;

  BookPage({
    required this.pageId,
    required this.baseImage,
    required this.textImage,
  });

  factory BookPage.fromJson(Map<String, dynamic> json) {
    return BookPage(
      pageId: json['pageId'],
      baseImage: json['baseImage'],
      textImage: json['textImage'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'pageId': pageId, 'baseImage': baseImage, 'textImage': textImage};
  }
}

// Audio Track Model
class AudioTrack {
  final String assetPath;
  final int startPage;
  final int endPage;

  AudioTrack({
    required this.assetPath,
    required this.startPage,
    required this.endPage,
  });

  factory AudioTrack.fromJson(Map<String, dynamic> json) {
    return AudioTrack(
      assetPath: json['assetPath'],
      startPage: json['startPage'],
      endPage: json['endPage'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'assetPath': assetPath, 'startPage': startPage, 'endPage': endPage};
  }
}

// Book Audio Model
class BookAudio {
  final String bookId;
  final List<AudioTrack> tracks;

  BookAudio({required this.bookId, required this.tracks});

  factory BookAudio.fromJson(Map<String, dynamic> json) {
    return BookAudio(
      bookId: json['bookId'],
      tracks:
          (json['tracks'] as List)
              .map((trackJson) => AudioTrack.fromJson(trackJson))
              .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bookId': bookId,
      'tracks': tracks.map((track) => track.toJson()).toList(),
    };
  }

  // 指定したページ番号に対応するトラックを返す
  AudioTrack? getTrackForPage(int pageNumber) {
    for (var track in tracks) {
      if (pageNumber >= track.startPage && pageNumber <= track.endPage) {
        return track;
      }
    }
    return null;
  }
}

// Category Model
class BookCategory {
  final String id;
  final String title;
  final List<String> bookIds; // References to books by ID

  BookCategory({required this.id, required this.title, required this.bookIds});

  factory BookCategory.fromJson(Map<String, dynamic> json) {
    return BookCategory(
      id: json['id'],
      title: json['title'],
      bookIds: List<String>.from(json['bookIds']),
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'title': title, 'bookIds': bookIds};
  }
}
