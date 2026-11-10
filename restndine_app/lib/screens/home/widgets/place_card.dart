import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../models/place_model.dart';
import '../../../widgets/common.dart';
import '../../../widgets/place_image.dart';
import '../../place_detail/place_detail_screen.dart';

void openPlaceDetail(BuildContext context, PlaceModel place) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => PlaceDetailScreen(placeId: place.id, preview: place)),
  );
}

/// Thẻ địa điểm trong danh sách: ảnh lớn, tên, loại, địa chỉ và mức giá.
class PlaceCard extends StatelessWidget {
  final PlaceModel place;

  const PlaceCard({super.key, required this.place});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return PressableScale(
      onTap: () => openPlaceDetail(context, place),
      child: Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: context.isDark ? Border.all(color: colors.border) : null,
          boxShadow: context.isDark ? null : colors.softShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 2 / 1,
                  child: LayoutBuilder(
                    builder: (_, c) => PlaceImage(place: place, displayWidth: c.maxWidth),
                  ),
                ),
                if (place.hasBanner) const Positioned(top: 12, left: 12, child: SponsoredBadge()),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleMedium!.copyWith(fontSize: 17),
                  ),
                  const SizedBox(height: 6),
                  PlaceMetaLine(place: place),
                  if (place.address != null) ...[
                    const SizedBox(height: 5),
                    PlaceAddressLine(address: place.address!),
                  ],
                  if (place.displayPrice != null) ...[
                    const SizedBox(height: 8),
                    PlacePriceLine(price: place.displayPrice!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thẻ lớn trong dải "Nổi bật": tên và địa chỉ đặt trên ảnh.
class FeaturedPlaceCard extends StatelessWidget {
  final PlaceModel place;
  final double width;

  const FeaturedPlaceCard({super.key, required this.place, this.width = 272});

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: () => openPlaceDetail(context, place),
      child: SizedBox(
        width: width,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          child: Stack(
            fit: StackFit.expand,
            children: [
              PlaceImage(place: place, displayWidth: width),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.35, 1],
                    colors: [Colors.transparent, Color(0xD9000000)],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleMedium!.copyWith(color: Colors.white, fontSize: 17),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(place.type.icon, size: 14, color: Colors.white70),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            [place.categoryLabel, place.address].whereType<String>().join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodySmall!.copyWith(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dòng phụ: loại địa điểm (kèm hạng sao nếu là khách sạn).
class PlaceMetaLine extends StatelessWidget {
  final PlaceModel place;

  const PlaceMetaLine({super.key, required this.place});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = place.type;
    final stars = type == PlaceType.hotel ? (place.starRating ?? 0) : 0;
    final style = context.text.labelMedium!.copyWith(color: colors.textSecondary);

    return Row(
      children: [
        Icon(type.icon, size: 16, color: type.color(colors)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(place.categoryLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
        ),
        if (stars > 0) ...[
          Text('  ·  ', style: style.copyWith(color: colors.textMuted)),
          RatingStars(rating: stars.toDouble(), size: 14),
        ],
      ],
    );
  }
}

class PlaceAddressLine extends StatelessWidget {
  final String address;

  const PlaceAddressLine({super.key, required this.address});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.location_on_outlined, size: 16, color: context.colors.textMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(address, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
        ),
      ],
    );
  }
}

class PlacePriceLine extends StatelessWidget {
  final String price;

  const PlacePriceLine({super.key, required this.price});

  @override
  Widget build(BuildContext context) {
    final color = context.colors.success;
    return Row(
      children: [
        Icon(Icons.payments_outlined, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            price,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelMedium!.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

/// Khung xương của [PlaceCard] khi đang tải.
class PlaceCardSkeleton extends StatelessWidget {
  const PlaceCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      clipBehavior: Clip.antiAlias,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(aspectRatio: 2 / 1, child: SkeletonBox(height: double.infinity, radius: 0)),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 190, height: 16),
                SizedBox(height: 10),
                SkeletonBox(width: 140, height: 12),
                SizedBox(height: 10),
                SkeletonBox(width: 230, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
