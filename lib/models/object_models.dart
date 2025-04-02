// lib/models/object_models.dart
import 'dart:convert';

class DecorationObject {
  final String id;
  final String name;
  final String imagePath;
  final String description;
  final String promotionalText;
  final bool isPurchased;
  final DateTime? purchaseDate;
  final double price;
  final String currency;

  DecorationObject({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.description,
    this.promotionalText = '',
    required this.isPurchased,
    this.purchaseDate,
    this.price = 0.0,
    this.currency = 'JPY',
  });

  factory DecorationObject.fromJson(Map<String, dynamic> json) {
    return DecorationObject(
      id: json['id'],
      name: json['name'],
      imagePath: json['imagePath'],
      description: json['description'],
      promotionalText: json['promotionalText'] ?? '',
      isPurchased: json['isPurchased'] ?? false,
      purchaseDate:
          json['purchaseDate'] != null
              ? DateTime.parse(json['purchaseDate'])
              : null,
      price: json['price']?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'JPY',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imagePath': imagePath,
      'description': description,
      'promotionalText': promotionalText,
      'isPurchased': isPurchased,
      'purchaseDate': purchaseDate?.toIso8601String(),
      'price': price,
      'currency': currency,
    };
  }
}
