import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../config/app_theme.dart';
import '../utils/formatters.dart';
import 'category_model.dart';

/// Loại địa điểm chính, quyết định icon, màu marker và ảnh minh hoạ.
enum PlaceType {
  restaurant('Nhà hàng', Icons.restaurant_rounded),
  cafe('Cafe', Icons.local_cafe_rounded),
  hotel('Khách sạn', Icons.hotel_rounded);

  const PlaceType(this.label, this.icon);

  final String label;
  final IconData icon;

  Color color(AppColors c) => switch (this) {
        PlaceType.restaurant => c.restaurant,
        PlaceType.cafe => c.cafe,
        PlaceType.hotel => c.hotel,
      };
}

class PlaceCommentModel {
  final int id;
  final String content;
  final int rating;
  final DateTime createdAt;
  final int helpfulCount;
  final String userId;
  final String userEmail;

  /// Tên hiển thị do server tính (họ tên, hoặc phần trước @ của email).
  final String? userName;

  PlaceCommentModel({
    required this.id,
    required this.content,
    required this.rating,
    required this.createdAt,
    required this.helpfulCount,
    required this.userId,
    required this.userEmail,
    this.userName,
  });

  /// Tên hiển thị: ưu tiên tên server trả về; server cũ chưa có thì lấy phần trước @ của email.
  String get authorName =>
      (userName != null && userName!.trim().isNotEmpty) ? userName!.trim() : displayNameFromEmail(userEmail);

  factory PlaceCommentModel.fromJson(Map<String, dynamic> json) {
    final rating = json['rating'] is int ? json['rating'] as int : int.tryParse('${json['rating']}') ?? 5;
    return PlaceCommentModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      content: json['content'] ?? '',
      rating: rating.clamp(1, 5),
      createdAt: parseServerDate(json['createdAt']) ?? DateTime.now(),
      helpfulCount: json['helpfulCount'] is int ? json['helpfulCount'] : 0,
      userId: json['userId'] ?? '',
      userEmail: json['userEmail'] ?? 'Người dùng',
      userName: json['userName'] as String?,
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
      imageUrl: AppConfig.resolveUrl(json['imageUrl'] as String?) ?? '',
    );
  }
}

class PlaceModel {
  // Toạ độ mặc định khi cào dữ liệu không xác định được vị trí: địa điểm chưa có vị trí thật
  static const _unknownLat = 10.7769;
  static const _unknownLng = 106.7009;

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

  /// Hạng sao của khách sạn (1-5), không phải điểm đánh giá của người dùng.
  final int? starRating;
  final String? amenities;
  final String? openingHours;
  final String? website;
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
    this.openingHours,
    this.website,
    this.ownerId,
    this.aiSummaryCache,
    required this.categories,
    this.images = const [],
    this.comments = const [],
  });

  bool get hasBanner => bannerStatus == 2 && (bannerUrl != null && bannerUrl!.isNotEmpty);

  /// Mức giá đáng hiển thị; "Liên hệ" (gần như mọi địa điểm cào về đều vậy) coi như chưa có giá.
  String? get displayPrice {
    final p = priceRange?.trim();
    if (p == null || p.isEmpty || foldVietnamese(p).startsWith('lien he')) return null;
    return p;
  }

  static final _privateUse = RegExp(r'[-]');
  static final _rating = RegExp(r'^\d[,.]\d\s*\([\d.,\s]+\)$'); // 4,3(113)
  static final _currency = RegExp(r'[₫$€]'); // 100-200 N ₫
  static final _hours = RegExp(r'^(mở|đóng|đang mở|sắp|open|closed)');
  static final _starHotel = RegExp(r'^khách sạn( \d sao)?$');
  static final _digit = RegExp(r'\d');
  static final _wordSplit = RegExp(r'[\s,./()\-]+');
  // So khớp có dấu: "quận" là địa chỉ nhưng "quán" là loại hình
  static const _streetWords = {
    'đường', 'đ', 'phố', 'p', 'ngõ', 'ngách', 'hẻm', 'kiệt', 'ql', 'lộ', 'lô', 'thôn', 'ấp', 'xã', //
    'phường', 'quận', 'q', 'huyện', 'tp', 'tx', 'tt', 'số', 'kp', 'chợ', 'tòa', 'tầng', 'block', //
    'căn', 'bãi', 'trấn',
  };

  static bool _isAddressSegment(String segment) {
    final s = segment.trim();
    final low = s.toLowerCase();
    if (s.isEmpty || _rating.hasMatch(s) || _currency.hasMatch(s) || _hours.hasMatch(low)) return false;
    if (_starHotel.hasMatch(low) || low == 'việt nam') return false;
    if (_digit.hasMatch(s)) return true;
    return low.split(_wordSplit).any(_streetWords.contains);
  }

  /// Trường địa chỉ cào từ thẻ Google Maps có dạng "loại hình · điểm(số đánh giá) · giá · địa chỉ",
  /// đôi khi kèm ký tự icon riêng của Google. Chỉ giữ các đoạn thật sự là địa chỉ.
  /// Cùng quy tắc với script bổ sung địa chỉ dùng để sửa dữ liệu trong database.
  static String? cleanAddress(String? raw) {
    if (raw == null) return null;
    final parts = raw.replaceAll(_privateUse, '').split('·').where(_isAddressSegment).map((s) => s.trim()).toList();
    return parts.isEmpty ? null : parts.join(', ');
  }

  PlaceType get type => categories.any((c) => c.slug == 'hotel')
      ? PlaceType.hotel
      : categories.any((c) => c.slug == 'cafe')
          ? PlaceType.cafe
          : PlaceType.restaurant;

  bool get hasValidLocation =>
      latitude != 0 &&
      longitude != 0 &&
      !(latitude == _unknownLat && longitude == _unknownLng);

  bool get hasOwner => ownerId != null && ownerId!.isNotEmpty;

  String? get _phone => phoneNumber?.trim();
  bool get hasPhone => _phone != null && _phone!.isNotEmpty;

  /// "Nhà hàng · Cafe" — tối đa hai danh mục.
  String get categoryLabel {
    final names = categories.map((c) => c.name).where((n) => n.isNotEmpty).take(2).toList();
    return names.isEmpty ? type.label : names.join(' · ');
  }

  /// Ảnh bìa trước, sau đó tới album; bỏ trùng.
  List<String> get galleryUrls {
    final urls = <String>[];
    for (final u in [imageUrl, ...images.map((i) => i.imageUrl)]) {
      if (u != null && u.trim().isNotEmpty && !urls.contains(u)) urls.add(u);
    }
    return urls;
  }

  /// Tiện ích dạng danh sách nếu chuỗi gốc là các mục ngắn cách nhau bằng dấu phẩy/chấm phẩy/xuống dòng.
  List<String> get amenityList {
    final raw = amenities?.trim() ?? '';
    if (raw.isEmpty) return const [];
    final items = raw
        .split(RegExp(r'[,;\n•|]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return items.every((s) => s.length <= 40) ? items : const [];
  }

  int get reviewCount => comments.length;

  double get averageRating =>
      comments.isEmpty ? 0 : comments.fold<int>(0, (sum, c) => sum + c.rating) / comments.length;

  /// Số đánh giá theo từng mức sao, chỉ số 0 ứng với 1 sao.
  List<int> get ratingDistribution {
    final counts = List<int>.filled(5, 0);
    for (final c in comments) {
      counts[c.rating - 1]++;
    }
    return counts;
  }

  // Các chuỗi đã bỏ dấu để tìm kiếm tại máy, tính một lần
  late final String _searchName = foldVietnamese(name);
  late final String _searchCategories = foldVietnamese(categories.map((c) => c.name).join(' '));

  /// Gần như mọi địa chỉ đều có "Thành phố …", nên bỏ cụm này để gõ "pho" không khớp cả nghìn nơi.
  late final String _searchDetails = foldVietnamese(
    [address, description].whereType<String>().join(' '),
  ).replaceAll(RegExp(r'(?<![a-z0-9])thanh pho(?![a-z0-9])'), ' ');

  /// Điểm khớp với các từ khoá đã bỏ dấu; 0 = không khớp. Điểm cao hiển thị trước: nguyên một từ
  /// trong tên ("pho" ↔ "Phố Cổ") > đầu từ trong tên ("Phong") > nằm giữa tên > danh mục > địa chỉ/mô tả
  /// (hai nhóm sau chỉ tính khớp đầu từ).
  int searchScore(List<String> tokens) {
    if (tokens.isEmpty) return 1;
    var score = 0;
    for (final t in tokens) {
      if (containsWholeWord(_searchName, t)) {
        score += 5;
      } else if (containsWordPrefix(_searchName, t)) {
        score += 4;
      } else if (_searchName.contains(t)) {
        score += 3;
      } else if (containsWordPrefix(_searchCategories, t)) {
        score += 2;
      } else if (containsWordPrefix(_searchDetails, t)) {
        score += 1;
      } else {
        return 0;
      }
    }
    // Gõ đúng cụm trong tên (vd. "pho hoa") xếp trên các nơi chỉ khớp rời từng từ
    if (tokens.length > 1 && _searchName.contains(tokens.join(' '))) score += 2;
    return score;
  }

  /// Số ảnh minh hoạ cho mỗi loại địa điểm.
  static const fallbackVariants = 4;

  static String fallbackAssetFor(PlaceType type, int variant) => 'assets/fallback/${type.name}-$variant.jpg';

  /// Ảnh minh hoạ theo loại, dùng khi không có ảnh hoặc link đã hết hạn. Đóng gói sẵn trong app
  /// (assets/fallback là bản sao của wwwroot/images/fallback) nên hiện ngay, không cần mạng.
  /// Cùng quy tắc chọn ảnh với PlaceFallbackImage.cs ở backend.
  String get fallbackAsset => fallbackAssetFor(type, id % fallbackVariants + 1);

  factory PlaceModel.fromJson(Map<String, dynamic> json) {
    String? str(String key) {
      final v = json[key];
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    return PlaceModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] ?? '',
      address: cleanAddress(str('address')),
      latitude: json['latitude'] is num ? (json['latitude'] as num).toDouble() : 0.0,
      longitude: json['longitude'] is num ? (json['longitude'] as num).toDouble() : 0.0,
      description: str('description'),
      imageUrl: AppConfig.resolveUrl(str('imageUrl')),
      phoneNumber: str('phoneNumber'),
      priceRange: str('priceRange'),
      bannerUrl: str('bannerUrl'),
      bannerStatus: json['bannerStatus'] is int ? json['bannerStatus'] : 0,
      starRating: json['starRating'] is int ? json['starRating'] : null,
      amenities: str('amenities'),
      openingHours: str('openingHours'),
      website: str('website'),
      ownerId: str('ownerId'),
      aiSummaryCache: str('aiSummaryCache'),
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
