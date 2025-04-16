// lib/models/coin_models.dart
import 'dart:convert';

// コイン残高モデル
class CoinBalance {
  final int balance;
  final List<CoinTransaction> transactions;
  final DateTime lastUpdated;

  CoinBalance({
    required this.balance,
    required this.transactions,
    required this.lastUpdated,
  });

  factory CoinBalance.fromJson(Map<String, dynamic> json) {
    return CoinBalance(
      balance: json['balance'] ?? 0,
      transactions:
          (json['transactions'] as List?)
              ?.map((tx) => CoinTransaction.fromJson(tx))
              .toList() ??
          [],
      lastUpdated:
          json['lastUpdated'] != null
              ? DateTime.parse(json['lastUpdated'])
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'balance': balance,
      'transactions': transactions.map((tx) => tx.toJson()).toList(),
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  // 新しい残高で更新したオブジェクトを返す
  CoinBalance copyWith({
    int? balance,
    List<CoinTransaction>? transactions,
    DateTime? lastUpdated,
  }) {
    return CoinBalance(
      balance: balance ?? this.balance,
      transactions: transactions ?? this.transactions,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

// コイン取引履歴モデル
class CoinTransaction {
  final String id;
  final int amount;
  final String type; // 'earn', 'spend', 'initial', 'bonus' など
  final String description;
  final DateTime date;

  CoinTransaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.description,
    required this.date,
  });

  factory CoinTransaction.fromJson(Map<String, dynamic> json) {
    return CoinTransaction(
      id: json['id'] ?? '',
      amount: json['amount'] ?? 0,
      type: json['type'] ?? '',
      description: json['description'] ?? '',
      date:
          json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'type': type,
      'description': description,
      'date': date.toIso8601String(),
    };
  }
}
