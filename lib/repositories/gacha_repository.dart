// lib/repositories/gacha_repository.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import '../models/gacha_models.dart';
import '../models/object_models.dart';
import '../repositories/object_repository.dart';
import '../services/file_storage_service.dart';

class GachaRepository {
  // Constants for file names
  static const String GACHA_TYPES_FILE = 'gacha_types.json';
  static const String GACHA_TYPES_ASSET = 'assets/data/gacha_types.json';

  // FileStorageService instance
  final FileStorageService _fileStorageService = FileStorageService();
  final ObjectRepository _objectRepository = ObjectRepository();

  // キャッシュ変数
  List<GachaType>? _cachedGachaTypes;

  // Singleton pattern
  static final GachaRepository _instance = GachaRepository._internal();
  factory GachaRepository() => _instance;
  GachaRepository._internal();

  // キャッシュをクリア
  void clearCache() {
    _cachedGachaTypes = null;
    print('Cleared gacha types cache');
  }

  // ガチャタイプ一覧を取得
  Future<List<GachaType>> getGachaTypes() async {
    // キャッシュがあればそれを返す
    if (_cachedGachaTypes != null) {
      return _cachedGachaTypes!;
    }

    try {
      // Ensure local file exists
      await _fileStorageService.ensureLocalJsonFileExists(
        GACHA_TYPES_FILE,
        GACHA_TYPES_ASSET,
      );

      // Try to load from local file first
      final gachaTypesData = await _fileStorageService.readJsonFromFile(
        GACHA_TYPES_FILE,
      );

      if (gachaTypesData != null) {
        _cachedGachaTypes =
            (gachaTypesData as List)
                .map((json) => GachaType.fromJson(json))
                .toList();
        return _cachedGachaTypes!;
      }

      // Fallback to asset
      final String jsonString = await rootBundle.loadString(GACHA_TYPES_ASSET);
      final List<dynamic> jsonData = json.decode(jsonString);

      _cachedGachaTypes =
          jsonData.map((json) => GachaType.fromJson(json)).toList();

      // Save to local file for future use
      await _fileStorageService.writeJsonToFile(GACHA_TYPES_FILE, jsonData);

      return _cachedGachaTypes!;
    } catch (e) {
      print('Error loading gacha types data: $e');
      return [];
    }
  }

  // IDでガチャタイプを取得
  Future<GachaType?> getGachaTypeById(String id) async {
    try {
      final gachaTypes = await getGachaTypes();
      return gachaTypes.firstWhere((type) => type.id == id);
    } catch (e) {
      print('Error getting gacha type by ID: $e');
      return null;
    }
  }

  // ガチャを引く
  Future<DecorationObject?> pullGacha(String gachaTypeId) async {
    try {
      // ガチャタイプを取得
      final gachaType = await getGachaTypeById(gachaTypeId);
      if (gachaType == null) {
        throw Exception('Gacha type not found: $gachaTypeId');
      }

      // 乱数生成器
      final random = Random();

      // 確率の合計を計算
      int totalProbability = 0;
      gachaType.probabilities.forEach((_, value) {
        totalProbability += value;
      });

      // 乱数を生成（1～確率合計）
      int randomValue = random.nextInt(totalProbability) + 1;

      // 確率に基づいてオブジェクトIDを選択
      String selectedObjectId = '';
      int currentSum = 0;

      for (var entry in gachaType.probabilities.entries) {
        currentSum += entry.value;
        if (randomValue <= currentSum) {
          selectedObjectId = entry.key;
          break;
        }
      }

      if (selectedObjectId.isEmpty) {
        throw Exception('Failed to select an object from gacha');
      }

      // オブジェクトリポジトリからオブジェクトを取得
      final object = await _objectRepository.getObjectById(selectedObjectId);
      return object;
    } catch (e) {
      print('Error pulling gacha: $e');
      return null;
    }
  }
}
