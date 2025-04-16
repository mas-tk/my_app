// lib/models/review_models.dart
import 'dart:convert';

// レビューコメントモデル
class ReviewComment {
  final String username;
  final double rating;
  final String comment;
  final DateTime date;
  int likes; // いいね数
  bool isLiked; // 現在のユーザーがいいねしたかどうか

  ReviewComment({
    required this.username,
    required this.rating,
    required this.comment,
    required this.date,
    this.likes = 0,
    this.isLiked = false,
  });

  // JSONからコンストラクト
  factory ReviewComment.fromJson(Map<String, dynamic> json) {
    return ReviewComment(
      username: json['username'] ?? '',
      rating: (json['rating'] ?? 0.0).toDouble(),
      comment: json['comment'] ?? '',
      date:
          json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      likes: json['likes'] ?? 0,
      isLiked: json['isLiked'] ?? false,
    );
  }

  // JSONに変換
  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'rating': rating,
      'comment': comment,
      'date': date.toIso8601String(),
      'likes': likes,
      'isLiked': isLiked,
    };
  }
}
