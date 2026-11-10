import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import '../../../config/app_theme.dart';
import '../../../config/map_tiles.dart';
import '../../../models/place_model.dart';
import '../../../widgets/common.dart';
import '../../../widgets/place_image.dart';

/// Ảnh đầu trang chi tiết: vuốt ngang xem album, chạm để xem toàn màn hình.
class HeaderGallery extends StatefulWidget {
  final PlaceModel place;

  const HeaderGallery({super.key, required this.place});

  @override
  State<HeaderGallery> createState() => _HeaderGalleryState();
}

class _HeaderGalleryState extends State<HeaderGallery> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final urls = widget.place.galleryUrls;
    final count = urls.isEmpty ? 1 : urls.length;
    final index = _index.clamp(0, count - 1);

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          itemCount: count,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (context, i) => GestureDetector(
            onTap: urls.isEmpty ? null : () => openPhotoViewer(context, widget.place, urls, i),
            child: PlaceImage(place: widget.place, url: urls.isEmpty ? null : urls[i]),
          ),
        ),
        // Phủ tối trên/dưới để nút và chữ trên ảnh luôn đọc được
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.3, 0.7, 1],
                colors: [Color(0x73000000), Color(0x00000000), Color(0x00000000), Color(0x59000000)],
              ),
            ),
          ),
        ),
        if (count > 1)
          Positioned(
            right: 16,
            bottom: 16,
            child: Pill(
              label: '${index + 1}/$count',
              icon: Icons.photo_library_outlined,
              color: Colors.white,
              background: Colors.black.withValues(alpha: 0.55),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
          ),
      ],
    );
  }
}

void openPhotoViewer(BuildContext context, PlaceModel place, List<String> urls, int initialIndex) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (_, __, ___) => _PhotoViewer(place: place, urls: urls, initialIndex: initialIndex),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
    ),
  );
}

class _PhotoViewer extends StatefulWidget {
  final PlaceModel place;
  final List<String> urls;
  final int initialIndex;

  const _PhotoViewer({required this.place, required this.urls, required this.initialIndex});

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final PageController _ctrl = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _ctrl,
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => InteractiveViewer(
              maxScale: 4,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: widget.urls[i],
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const CircularProgressIndicator(color: Colors.white54),
                  errorWidget: (_, __, ___) => CachedNetworkImage(
                    imageUrl: widget.place.fallbackImageUrl,
                    fit: BoxFit.contain,
                    errorWidget: (_, __, ___) =>
                        const Icon(Icons.broken_image_outlined, color: Colors.white38, size: 48),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                  const Spacer(),
                  if (widget.urls.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(
                        '${_index + 1} / ${widget.urls.length}',
                        style: context.text.labelLarge!.copyWith(color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bản đồ nhỏ (không kéo được) cho biết vị trí; chạm để mở chỉ đường.
class LocationPreview extends StatelessWidget {
  final PlaceModel place;
  final VoidCallback onOpen;

  const LocationPreview({super.key, required this.place, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final point = LatLng(place.latitude, place.longitude);
    final color = place.type.color(colors);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: SizedBox(
        height: 180,
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: point,
                initialZoom: 15.5,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
              ),
              children: [
                MapTiles.layer(),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: point,
                      width: 44,
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 3))],
                        ),
                        child: Icon(place.type.icon, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
                MapTiles.attribution,
              ],
            ),
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(onTap: onOpen),
              ),
            ),
            Positioned(
              right: 10,
              top: 10,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: colors.softShadow,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.directions_rounded, size: 16, color: context.scheme.primary),
                      const SizedBox(width: 6),
                      Text('Chỉ đường', style: context.text.labelMedium!.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
