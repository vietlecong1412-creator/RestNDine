import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/place_model.dart';

/// Ảnh địa điểm; không có ảnh hoặc link hết hạn thì dùng ảnh minh hoạ theo loại.
class PlaceImage extends StatelessWidget {
  final PlaceModel place;

  /// Ảnh cụ thể trong album; mặc định là ảnh bìa.
  final String? url;
  final BoxFit fit;

  /// Chiều rộng hiển thị (logical px) để giải mã ảnh vừa đủ, tiết kiệm RAM khi cuộn danh sách dài.
  final double? displayWidth;

  const PlaceImage({
    super.key,
    required this.place,
    this.url,
    this.fit = BoxFit.cover,
    this.displayWidth,
  });

  /// Cho phép test thay ảnh mạng bằng ảnh cục bộ.
  @visibleForTesting
  static Widget Function(String url, BoxFit fit)? debugImageBuilder;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final placeholder = ColoredBox(
      color: colors.skeleton,
      child: Center(
        child: Icon(place.type.icon, size: 28, color: colors.textMuted.withValues(alpha: 0.5)),
      ),
    );

    final cacheWidth = displayWidth == null
        ? null
        : (displayWidth! * MediaQuery.devicePixelRatioOf(context)).round();

    Widget network(String imageUrl, Widget Function() onError) {
      final debug = debugImageBuilder;
      if (debug != null) return debug(imageUrl, fit);
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: fit,
        memCacheWidth: cacheWidth,
        fadeInDuration: const Duration(milliseconds: 220),
        placeholder: (_, __) => placeholder,
        errorWidget: (_, __, ___) => onError(),
      );
    }

    final fallback = network(place.fallbackImageUrl, () => placeholder);
    final imageUrl = url ?? place.imageUrl;
    if (imageUrl == null || imageUrl.isEmpty) return fallback;
    return network(imageUrl, () => fallback);
  }
}
