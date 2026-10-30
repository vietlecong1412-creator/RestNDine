import '../config/app_config.dart';
import 'category_model.dart';

class PlaceCommentModel {
  final int id;
  final String content;
  final int rating;
  final DateTime createdAt;
  final int helpfulCount;
  final String userId;
  final String userEmail;

  PlaceCommentModel({
    required this.id,
    required this.content,
    required this.rating,
    required this.createdAt,
    required this.helpfulCount,
    required this.userId,
    required this.userEmail,
  });

  factory PlaceCommentModel.fromJson(Map<String, dynamic> json) {
    return PlaceCommentModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      content: json['content'] ?? '',
      rating: json['rating'] is int ? json['rating'] : int.tryParse(json['rating'].toString()) ?? 5,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      helpfulCount: json['helpfulCount'] is int ? json['helpfulCount'] : 0,
      userId: json['userId'] ?? '',
      userEmail: json['userEmail'] ?? 'Người dùng',
    );
  }
}

class PlaceImageModel {
  final int id;
  final String imageUrl;

  PlaceImageModel({required this.id, required this.imageUrl});

  factory PlaceImageModel.fromJson(Map<String, dynamic> json) {
    return PlaceImageModel(
      id: json['id'] is int ? json['id'] : 0,
      imageUrl: json['imageUrl'] ?? '',
    );
  }
}

class PlaceModel {
  final int id;
  final String name;
  final String? address;
  final double latitude;
  final double longitude;
  final String? description;
  final String? imageUrl;
  final String? phoneNumber;
  final String? priceRange;
  final String? bannerUrl;
  final int bannerStatus;
  final int? starRating;
  final String? amenities;
  final String? ownerId;
  final String? aiSummaryCache;
  final List<CategoryModel> categories;
  final List<PlaceImageModel> images;
  final List<PlaceCommentModel> comments;

  PlaceModel({
    required this.id,
    required this.name,
    this.address,
    required this.latitude,
    required this.longitude,
    this.description,
    this.imageUrl,
    this.phoneNumber,
    this.priceRange,
    this.bannerUrl,
    required this.bannerStatus,
    this.starRating,
    this.amenities,
    this.ownerId,
    this.aiSummaryCache,
    required this.categories,
    this.images = const [],
    this.comments = const [],
  });

  bool get hasBanner => bannerStatus == 2 && (bannerUrl != null && bannerUrl!.isNotEmpty);

  /// Ảnh minh hoạ theo loại, dùng khi không có ảnh hoặc link đã hết hạn.
  /// Cùng quy tắc với PlaceFallbackImage.cs ở backend.
  String get fallbackImageUrl {
    final type = categories.any((c) => c.slug == 'hotel')
        ? 'hotel'
        : categories.any((c) => c.slug == 'cafe')
            ? 'cafe'
            : 'restaurant';
    return '${AppConfig.baseUrl}/images/fallback/$type-${id % 4 + 1}.jpg';
  }

  factory PlaceModel.fromJson(Map<String, dynamic> json) {
    return PlaceModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] ?? '',
      address: json['address'],
      latitude: json['latitude'] is num ? (json['latitude'] as num).toDouble() : 0.0,
      longitude: json['longitude'] is num ? (json['longitude'] as num).toDouble() : 0.0,
      description: json['description'],
      imageUrl: json['imageUrl'],
      phoneNumber: json['phoneNumber'],
      priceRange: json['priceRange'],
      bannerUrl: json['bannerUrl'],
      bannerStatus: json['bannerStatus'] is int ? json['bannerStatus'] : 0,
      starRating: json['starRating'] is int ? json['starRating'] : null,
      amenities: json['amenities'],
      ownerId: json['ownerId'],
      aiSummaryCache: json['aiSummaryCache'],
      categories: (json['categories'] as List<dynamic>?)
              ?.map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      images: (json['images'] as List<dynamic>?)
              ?.map((e) => PlaceImageModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      comments: (json['comments'] as List<dynamic>?)
              ?.map((e) => PlaceCommentModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
