import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../models/place_model.dart';

/// Ảnh địa điểm; không có ảnh hoặc link hết hạn thì dùng ảnh minh hoạ theo loại.
class PlaceImage extends StatelessWidget {
  final PlaceModel place;

  const PlaceImage({super.key, required this.place});

  @override
  Widget build(BuildContext context) {
    final fallback = CachedNetworkImage(
      imageUrl: place.fallbackImageUrl,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(color: Colors.grey.shade200),
      errorWidget: (_, __, ___) => Container(
        color: Colors.grey.shade200,
        child: Icon(Icons.image_not_supported_outlined, color: Colors.grey.shade400, size: 32),
      ),
    );

    final url = place.imageUrl;
    if (url == null || url.isEmpty) return fallback;

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(color: Colors.grey.shade200),
      errorWidget: (_, __, ___) => fallback,
    );
  }
}
