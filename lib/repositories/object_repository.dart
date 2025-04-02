// lib/repositories/object_repository.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/object_models.dart';
import '../services/file_storage_service.dart';

class ObjectRepository {
  // Constants for file names
  static const String OBJECTS_FILE = 'decoration_objects.json';
  static const String OBJECTS_ASSET = 'assets/data/decoration_objects.json';

  // FileStorageService instance
  final FileStorageService _fileStorageService = FileStorageService();

  // キャッシュ変数
  List<DecorationObject>? _cachedObjects;

  // Singleton pattern
  static final ObjectRepository _instance = ObjectRepository._internal();
  factory ObjectRepository() => _instance;
  ObjectRepository._internal();

  // キャッシュをクリア
  void clearCache() {
    _cachedObjects = null;
    print('Cleared object cache');
  }

  // オブジェクト一覧を取得
  Future<List<DecorationObject>> getAllObjects() async {
    // キャッシュがあればそれを返す
    if (_cachedObjects != null) {
      print('Returning ${_cachedObjects!.length} objects from cache');
      return _cachedObjects!;
    }

    try {
      // デバッグログを追加
      print('Loading decoration objects...');

      // Ensure local file exists
      await _fileStorageService.ensureLocalJsonFileExists(
        OBJECTS_FILE,
        OBJECTS_ASSET,
      );

      // Try to load from local file first
      final objectsData = await _fileStorageService.readJsonFromFile(
        OBJECTS_FILE,
      );

      if (objectsData != null) {
        print('Loaded ${(objectsData as List).length} objects from local file');
        print('Sample object: ${json.encode(objectsData[0])}');
        _cachedObjects =
            (objectsData as List)
                .map((json) => DecorationObject.fromJson(json))
                .toList();

        // デバッグ用にオブジェクト情報を出力
        for (var obj in _cachedObjects!) {
          print(
            '  - ${obj.name}: ${obj.imagePath} (isPurchased: ${obj.isPurchased})',
          );
        }

        return _cachedObjects!;
      }

      // Fallback to asset
      print('Loading objects from asset file');
      final String jsonString = await rootBundle.loadString(OBJECTS_ASSET);
      final List<dynamic> jsonData = json.decode(jsonString);
      print('Loaded ${jsonData.length} objects from asset');
      print('Sample object from asset: ${json.encode(jsonData[0])}');

      // Save to local file for future use
      await _fileStorageService.writeJsonToFile(OBJECTS_FILE, jsonData);

      _cachedObjects =
          jsonData.map((json) => DecorationObject.fromJson(json)).toList();

      // デバッグ用にオブジェクト情報を出力
      for (var obj in _cachedObjects!) {
        print(
          '  - ${obj.name}: ${obj.imagePath} (isPurchased: ${obj.isPurchased})',
        );
      }

      return _cachedObjects!;
    } catch (e) {
      print('Error loading object data: $e');
      return [];
    }
  }

  // IDでオブジェクトを取得
  Future<DecorationObject?> getObjectById(String id) async {
    try {
      final objects = await getAllObjects();
      return objects.firstWhere((object) => object.id == id);
    } catch (e) {
      print('Error getting object by ID: $e');
      return null;
    }
  }

  // 購入済みのオブジェクトのみ取得
  Future<List<DecorationObject>> getPurchasedObjects() async {
    try {
      final objects = await getAllObjects();
      final purchased = objects.where((object) => object.isPurchased).toList();
      print('Loaded ${purchased.length} purchased objects');
      for (var obj in purchased) {
        print(
          '  - ${obj.name}: ${obj.imagePath} (isPurchased: ${obj.isPurchased})',
        );
      }
      return purchased;
    } catch (e) {
      print('Error getting purchased objects: $e');
      return [];
    }
  }

  // 未購入のオブジェクトのみ取得
  Future<List<DecorationObject>> getUnpurchasedObjects() async {
    try {
      final objects = await getAllObjects();
      final unpurchased =
          objects.where((object) => !object.isPurchased).toList();
      print('Loaded ${unpurchased.length} unpurchased objects');
      for (var obj in unpurchased) {
        print(
          '  - ${obj.name}: ${obj.imagePath} (isPurchased: ${obj.isPurchased})',
        );
      }
      return unpurchased;
    } catch (e) {
      print('Error getting unpurchased objects: $e');
      return [];
    }
  }

  // オブジェクトを購入
  Future<bool> purchaseObject(String id) async {
    try {
      // キャッシュがない場合は先に読み込む
      if (_cachedObjects == null) {
        await getAllObjects();
      }

      final index = _cachedObjects!.indexWhere((object) => object.id == id);

      if (index != -1) {
        // 新しいオブジェクトを作成（copyWithがあればそれを使う）
        _cachedObjects![index] = DecorationObject(
          id: _cachedObjects![index].id,
          name: _cachedObjects![index].name,
          imagePath: _cachedObjects![index].imagePath,
          description: _cachedObjects![index].description,
          promotionalText: _cachedObjects![index].promotionalText,
          isPurchased: true,
          purchaseDate: DateTime.now(),
          price: _cachedObjects![index].price,
          currency: _cachedObjects![index].currency,
        );

        // Save updated objects list
        await _fileStorageService.writeJsonToFile(
          OBJECTS_FILE,
          _cachedObjects!.map((obj) => obj.toJson()).toList(),
        );

        return true;
      }

      return false;
    } catch (e) {
      print('Error purchasing object: $e');
      return false;
    }
  }
}
