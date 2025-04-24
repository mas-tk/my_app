// lib/models/gacha_models.dart
import 'dart:convert';

// ガチャタイプモデル
class GachaType {
  final String id;
  final String name;
  final String description;
  final int cost;
  final String imagePath;
  final List<String> availableObjects;
  final Map<String, int> probabilities;

  GachaType({
    required this.id,
    required this.name,
    required this.description,
    required this.cost,
    required this.imagePath,
    required this.availableObjects,
    required this.probabilities,
  });

  factory GachaType.fromJson(Map<String, dynamic> json) {
    // 確率マップの変換
    Map<String, int> probMap = {};
    if (json['probabilities'] != null) {
      json['probabilities'].forEach((key, value) {
        // doubleの場合はintに変換
        if (value is double) {
          probMap[key] = value.toInt();
        } else {
          probMap[key] = value as int;
        }
      });
    }

    return GachaType(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      // costがdoubleの場合はintに変換
      cost:
          json['cost'] is double
              ? (json['cost'] as double).toInt()
              : (json['cost'] ?? 0),
      imagePath: json['imagePath'] ?? '',
      availableObjects:
          (json['availableObjects'] as List?)
              ?.map((obj) => obj as String)
              .toList() ??
          [],
      probabilities: probMap,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'cost': cost,
      'imagePath': imagePath,
      'availableObjects': availableObjects,
      'probabilities': probabilities,
    };
  }
}
