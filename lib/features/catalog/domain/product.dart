import 'package:flutter/material.dart';

import '../../../core/storage/local_store.dart';

class IceCategory {
  const IceCategory({required this.id, required this.name, required this.tagline, required this.image});

  final String id;
  final String name;
  final String tagline;
  final String image;
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.description,
    required this.image,
    required this.pack,
    required this.weightKg,
    required this.price,
    required this.mrp,
    required this.rating,
    required this.uses,
    this.warning,
    this.forDrinks = false,
    this.bestseller = false,
    this.inStock = true,
    this.subscribable = true,
  });

  final String id;
  final String name;
  final String categoryId;
  final String description;
  final String image;
  final String pack;
  final double weightKg;
  final double price;
  final double mrp;
  final double rating;
  final List<String> uses;

  /// A safety or usage note shown before buying.
  final String? warning;

  /// Only these are suggested for drinks.
  final bool forDrinks;
  final bool bestseller;
  final bool inStock;
  final bool subscribable;

  factory Product.fromJson(Json j) => Product(
    id: j['id'] as String,
    name: j['name'] as String,
    categoryId: j['categoryId'] as String,
    description: j['description'] as String,
    image: j['image'] as String,
    pack: j['pack'] as String,
    weightKg: (j['weightKg'] as num).toDouble(),
    price: (j['price'] as num).toDouble(),
    mrp: (j['mrp'] as num).toDouble(),
    rating: (j['rating'] as num).toDouble(),
    uses: (j['uses'] as List).cast<String>(),
    warning: j['warning'] as String?,
    forDrinks: j['forDrinks'] as bool,
    bestseller: j['bestseller'] as bool,
    inStock: j['inStock'] as bool,
    subscribable: j['subscribable'] as bool,
  );

  bool get isDryIce => categoryId == 'dry';
  int get percentOff => mrp > price ? ((mrp - price) / mrp * 100).round() : 0;
  Color get warningColor => isDryIce ? const Color(0xFFDC2626) : const Color(0xFFD97706);
}

class Review {
  const Review({required this.productId, required this.author, required this.rating, required this.text, required this.at});

  final String productId;
  final String author;
  final int rating;
  final String text;
  final DateTime at;

  Json toJson() => {'productId': productId, 'author': author, 'rating': rating, 'text': text, 'at': at.toIso8601String()};

  factory Review.fromJson(Json j) => Review(
    productId: j['productId'] as String,
    author: j['author'] as String,
    rating: j['rating'] as int,
    text: j['text'] as String,
    at: DateTime.parse(j['at'] as String),
  );
}
