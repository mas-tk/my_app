// lib/repositories/coin_repository.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/coin_models.dart';
import '../services/file_storage_service.dart';

class CoinRepository {
  // Constants for file names
  static const String COINS_FILE = 'coins.json';
  static const String COINS_ASSET = 'assets/data/coins.json';

  // FileStorageService instance
  final FileStorageService _fileStorageService = FileStorageService();

  // キャッシュ変数
  CoinBalance? _cachedBalance;

  // Singleton pattern
  static final CoinRepository _instance = CoinRepository._internal();
  factory CoinRepository() => _instance;
  CoinRepository._internal();

  // キャッシュをクリア
  void clearCache() {
    _cachedBalance = null;
    print('Cleared coin cache');
  }

  // コイン残高を取得
  Future<CoinBalance> getBalance() async {
    // キャッシュがあればそれを返す
    if (_cachedBalance != null) {
      return _cachedBalance!;
    }

    try {
      // Ensure local file exists
      await _fileStorageService.ensureLocalJsonFileExists(
        COINS_FILE,
        COINS_ASSET,
      );

      // Try to load from local file first
      final coinsData = await _fileStorageService.readJsonFromFile(COINS_FILE);

      if (coinsData != null) {
        _cachedBalance = CoinBalance.fromJson(coinsData);
        return _cachedBalance!;
      }

      // Fallback to asset
      final String jsonString = await rootBundle.loadString(COINS_ASSET);
      final dynamic jsonData = json.decode(jsonString);

      _cachedBalance = CoinBalance.fromJson(jsonData);

      // Save to local file for future use
      await _fileStorageService.writeJsonToFile(COINS_FILE, jsonData);

      return _cachedBalance!;
    } catch (e) {
      print('Error loading coins data: $e');

      // Create default balance in case of error
      _cachedBalance = CoinBalance(
        balance: 1000,
        transactions: [
          CoinTransaction(
            id: 'default',
            amount: 1000,
            type: 'initial',
            description: 'デフォルト初期コイン',
            date: DateTime.now(),
          ),
        ],
        lastUpdated: DateTime.now(),
      );

      return _cachedBalance!;
    }
  }

  // コインを消費
  Future<bool> spendCoins(int amount, String description) async {
    try {
      final currentBalance = await getBalance();

      // 残高が足りるかチェック
      if (currentBalance.balance < amount) {
        return false;
      }

      // 新しい取引を作成
      final newTransaction = CoinTransaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        amount: -amount, // 負の値で支出を表現
        type: 'spend',
        description: description,
        date: DateTime.now(),
      );

      // 更新された残高を計算
      final updatedBalance = currentBalance.copyWith(
        balance: currentBalance.balance - amount,
        transactions: [...currentBalance.transactions, newTransaction],
        lastUpdated: DateTime.now(),
      );

      // キャッシュを更新
      _cachedBalance = updatedBalance;

      // ファイルに保存
      await _fileStorageService.writeJsonToFile(
        COINS_FILE,
        updatedBalance.toJson(),
      );

      return true;
    } catch (e) {
      print('Error spending coins: $e');
      return false;
    }
  }

  // コインを獲得
  Future<bool> earnCoins(int amount, String type, String description) async {
    try {
      final currentBalance = await getBalance();

      // 新しい取引を作成
      final newTransaction = CoinTransaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        amount: amount,
        type: type,
        description: description,
        date: DateTime.now(),
      );

      // 更新された残高を計算
      final updatedBalance = currentBalance.copyWith(
        balance: currentBalance.balance + amount,
        transactions: [...currentBalance.transactions, newTransaction],
        lastUpdated: DateTime.now(),
      );

      // キャッシュを更新
      _cachedBalance = updatedBalance;

      // ファイルに保存
      await _fileStorageService.writeJsonToFile(
        COINS_FILE,
        updatedBalance.toJson(),
      );

      return true;
    } catch (e) {
      print('Error earning coins: $e');
      return false;
    }
  }
}
