// lib/repositories/tag_repository.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../services/file_storage_service.dart';

// タググループモデル
class TagGroup {
  final String id;
  final String name;
  final List<Tag> tags;

  TagGroup({required this.id, required this.name, required this.tags});

  factory TagGroup.fromJson(Map<String, dynamic> json) {
    return TagGroup(
      id: json['id'],
      name: json['name'],
      tags:
          (json['tags'] as List)
              .map((tagJson) => Tag.fromJson(tagJson))
              .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'tags': tags.map((tag) => tag.toJson()).toList(),
    };
  }
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

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      id: json['id'],
      name: json['name'],
      icon: json['icon'],
      isSelected: json['isSelected'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'icon': icon, 'isSelected': isSelected};
  }
}

class TagRepository {
  // Constants for file names
  static const String TAGS_FILE = 'tags.json';
  static const String TAGS_ASSET = 'assets/data/tags.json';

  // FileStorageService instance
  final FileStorageService _fileStorageService = FileStorageService();

  // キャッシュ用
  List<TagGroup>? _cachedTagGroups;

  // Singleton pattern
  static final TagRepository _instance = TagRepository._internal();
  factory TagRepository() => _instance;
  TagRepository._internal();

  // タググループの取得
  Future<List<TagGroup>> getTagGroups() async {
    try {
      // キャッシュがあれば返す
      if (_cachedTagGroups != null) {
        return _cachedTagGroups!;
      }

      // Ensure local file exists
      await _fileStorageService.ensureLocalJsonFileExists(
        TAGS_FILE,
        TAGS_ASSET,
      );

      // ローカルファイルから読み込み
      final tagsData = await _fileStorageService.readJsonFromFile(TAGS_FILE);

      if (tagsData != null) {
        _cachedTagGroups =
            (tagsData as List).map((json) => TagGroup.fromJson(json)).toList();
        return _cachedTagGroups!;
      }

      // ローカルファイルがなければアセットから読み込み
      final String jsonString = await rootBundle.loadString(TAGS_ASSET);
      final List<dynamic> jsonData = json.decode(jsonString);

      _cachedTagGroups =
          jsonData.map((json) => TagGroup.fromJson(json)).toList();

      // 将来の使用のためにローカルに保存
      await _fileStorageService.writeJsonToFile(TAGS_FILE, jsonData);

      return _cachedTagGroups!;
    } catch (e) {
      print('Error loading tag groups: $e');

      // エラー時はデフォルトのタググループを返す
      return _getDefaultTagGroups();
    }
  }

  // キャッシュをクリア
  void clearCache() {
    _cachedTagGroups = null;
  }

  // デフォルトのタググループを作成（エラー時のフォールバック用）
  List<TagGroup> _getDefaultTagGroups() {
    return [
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
  }
}
