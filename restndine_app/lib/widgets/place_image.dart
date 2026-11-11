import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/place_model.dart';

/// Ảnh địa điểm. Ảnh minh hoạ theo loại (đóng gói sẵn trong app) hiện ngay; ảnh thật trên mạng
/// được tải ngầm và hiện đè lên nếu tải được. Link ảnh cào từ Google hay hết hạn (403) hoặc không
/// tới được, nên không bao giờ bắt người dùng chờ chúng.
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

  /// Cho phép test thay ảnh bằng ảnh cục bộ.
  @visibleForTesting
  static Widget Function(String url, BoxFit fit)? debugImageBuilder;

  /// Link vừa tải lỗi → thời điểm lỗi. Trong [retryAfter] không tải lại mà dùng luôn ảnh minh hoạ,
  /// để mỗi lần mở lại địa điểm không phải gọi mạng vô ích.
  static final _failedAt = <String, DateTime>{};
  static const retryAfter = Duration(minutes: 5);

  /// Link có đáng thử tải không: có link, và chưa lỗi (hoặc lỗi đã lâu, có thể chỉ do mất mạng).
  static bool isWorthTrying(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final at = _failedAt[url];
    return at == null || DateTime.now().difference(at) > retryAfter;
  }

  static void markFailed(String url) => _failedAt[url] = DateTime.now();

  @visibleForTesting
  static void debugResetFailures() => _failedAt.clear();

  /// Giải mã sẵn các ảnh minh hoạ lúc mở app, để lần hiện đầu tiên cũng không trễ khung hình nào.
  static void precacheFallbacks(BuildContext context) {
    if (debugImageBuilder != null) return;
    for (final type in PlaceType.values) {
      for (var i = 1; i <= PlaceModel.fallbackVariants; i++) {
        precacheImage(AssetImage(PlaceModel.fallbackAssetFor(type, i)), context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = url ?? place.imageUrl;
    final hasUrl = imageUrl != null && imageUrl.trim().isNotEmpty;

    final debug = debugImageBuilder;
    if (debug != null) return debug(hasUrl ? imageUrl : place.fallbackAsset, fit);

    final colors = context.colors;
    final placeholder = ColoredBox(
      color: colors.skeleton,
      child: Center(
        child: Icon(place.type.icon, size: 28, color: colors.textMuted.withValues(alpha: 0.5)),
      ),
    );

    // Không giới hạn cỡ giải mã: cả app chỉ có 12 ảnh minh hoạ dùng chung cho mọi kích thước
    final fallback = Image.asset(
      place.fallbackAsset,
      fit: fit,
      // Chỉ thấy nền chờ nếu ảnh chưa kịp giải mã sẵn (vài khung hình đầu sau khi mở app)
      frameBuilder: (_, child, frame, sync) => sync || frame != null ? child : placeholder,
      errorBuilder: (_, __, ___) => placeholder,
    );
    if (!hasUrl || !isWorthTrying(imageUrl)) return fallback;

    final cacheWidth = displayWidth == null
        ? null
        : (displayWidth! * MediaQuery.devicePixelRatioOf(context)).round();

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      memCacheWidth: cacheWidth,
      fadeInDuration: const Duration(milliseconds: 220),
      fadeOutDuration: const Duration(milliseconds: 220),
      placeholder: (_, __) => fallback,
      errorListener: (_) => markFailed(imageUrl),
      errorWidget: (_, __, ___) => fallback,
    );
  }
}
