import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../config/map_tiles.dart';
import '../../models/place_model.dart';
import '../../providers/place_provider.dart';
import '../../utils/launcher.dart';
import '../../widgets/place_image.dart';
import '../home/widgets/place_card.dart';
import '../home/widgets/search_filter_bar.dart';

/// Tab "Bản đồ": bản đồ toàn màn hình, tìm kiếm nổi phía trên, thẻ xem trước phía dưới.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Vẽ quá nhiều marker làm bản đồ giật, nên chỉ vẽ các địa điểm gần tâm bản đồ đang xem
  static const _maxMarkers = 150;
  static const _defaultCenter = LatLng(10.7769, 106.7009); // TP. Hồ Chí Minh

  final MapController _map = MapController();
  bool _mapReady = false;
  LatLng? _viewCenter;
  Timer? _moveDebounce;
  String _fittedQuery = '';

  @override
  void dispose() {
    _moveDebounce?.cancel();
    _map.dispose();
    super.dispose();
  }

  void _onMapMoved(MapCamera camera, bool hasGesture) {
    _moveDebounce?.cancel();
    _moveDebounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _viewCenter = camera.center);
    });
  }

  LatLng _initialCenter(List<PlaceModel> places) {
    for (final p in places) {
      if (p.hasValidLocation) return LatLng(p.latitude, p.longitude);
    }
    return _defaultCenter;
  }

  List<PlaceModel> _placesNear(List<PlaceModel> places, LatLng center, PlaceModel? selected) {
    double distance(PlaceModel p) {
      final dLat = p.latitude - center.latitude;
      final dLng = p.longitude - center.longitude;
      return dLat * dLat + dLng * dLng;
    }

    final nearest = places.where((p) => p.hasValidLocation).toList()
      ..sort((a, b) => distance(a).compareTo(distance(b)));

    // Nhiều địa điểm trùng toạ độ: mỗi điểm chỉ vẽ một marker để không chồng lên nhau
    final seen = <String>{};
    final visible = nearest
        .where((p) => seen.add('${p.latitude},${p.longitude}'))
        .take(_maxMarkers)
        .where((p) => p.id != selected?.id)
        .toList();

    // Marker đang chọn vẽ sau cùng để nằm trên các marker khác
    if (selected != null && selected.hasValidLocation) visible.add(selected);
    return visible;
  }

  /// Vừa tìm kiếm xong thì đưa camera tới các kết quả.
  void _maybeFitToSearch(PlaceProvider prov) {
    final q = prov.searchQuery.trim();
    if (q == _fittedQuery) return;
    _fittedQuery = q;
    if (q.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitTo(prov.places));
  }

  void _fitTo(List<PlaceModel> places) {
    if (!_mapReady || !mounted) return;
    final points = [
      for (final p in places)
        if (p.hasValidLocation) LatLng(p.latitude, p.longitude),
    ];
    if (points.isEmpty) return;
    if (points.length == 1) {
      _map.move(points.first, 16);
      return;
    }
    final top = MediaQuery.paddingOf(context).top;
    _map.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: EdgeInsets.fromLTRB(48, top + 140, 48, 120),
        maxZoom: 16,
      ),
    );
  }

  void _select(PlaceProvider prov, PlaceModel place) {
    prov.selectPlace(place);
    // Dời tâm lên một chút để thẻ xem trước không che marker
    _map.move(
      LatLng(place.latitude, place.longitude),
      math.max(_map.camera.zoom, 15),
      offset: const Offset(0, -70),
    );
  }

  List<Marker> _buildMarkers(PlaceProvider prov) {
    final selected = prov.selectedPlace;
    final center = _viewCenter ?? _initialCenter(prov.places);
    return _placesNear(prov.places, center, selected).map((p) {
      final isSelected = selected?.id == p.id;
      final size = isSelected ? 46.0 : 36.0;
      return Marker(
        key: ValueKey(p.id),
        point: LatLng(p.latitude, p.longitude),
        width: size + 8,
        height: size + 9,
        alignment: Alignment.topCenter,
        child: Semantics(
          button: true,
          selected: isSelected,
          label: '${p.type.label} ${p.name}',
          child: GestureDetector(
            onTap: () => _select(prov, p),
            child: _MapPin(place: p, selected: isSelected, size: size),
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<PlaceProvider>();
    final colors = context.colors;
    final selected = prov.selectedPlace;
    _maybeFitToSearch(prov);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Nền bản đồ sáng ở cả chế độ tối
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: Stack(
          children: [
            FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: _initialCenter(prov.places),
                initialZoom: 13.5,
                minZoom: 4,
                maxZoom: 19,
                onMapReady: () => _mapReady = true,
                onTap: (_, __) => prov.selectPlace(null),
                onPositionChanged: _onMapMoved,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                MapTiles.layer(),
                MarkerLayer(markers: _buildMarkers(prov)),
                MapTiles.attribution,
              ],
            ),

            // Tìm kiếm + bộ lọc nổi trên bản đồ
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: PlaceSearchField(floating: true),
                      ),
                      const SizedBox(height: 10),
                      const CategoryChips(floating: true),
                      if (prov.isLoading)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                          child: LinearProgressIndicator(minHeight: 3, borderRadius: BorderRadius.circular(3)),
                        ),
                      if (prov.hasLoaded && prov.isFiltering)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _ResultNotice(count: prov.places.length, onClear: prov.clearFilters),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Nút đưa camera về toàn bộ kết quả (ẩn khi đang xem một địa điểm)
            Positioned(
              right: 16,
              bottom: 34,
              child: AnimatedScale(
                scale: selected == null ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: _MapButton(
                  icon: Icons.zoom_out_map_rounded,
                  tooltip: 'Xem tất cả kết quả',
                  onTap: () => _fitTo(prov.places),
                ),
              ),
            ),

            // Thẻ xem trước địa điểm đang chọn; chừa chỗ cho dòng ghi công "© Esri" bên dưới
            Positioned(
              left: 12,
              right: 12,
              bottom: 30,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(anim),
                    child: child,
                  ),
                ),
                child: selected == null
                    ? const SizedBox.shrink(key: ValueKey('none'))
                    : _PlacePreviewCard(
                        key: ValueKey(selected.id),
                        place: selected,
                        onClose: () => prov.selectPlace(null),
                      ),
              ),
            ),

            if (prov.error != null && !prov.hasLoaded)
              Center(
                child: Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    boxShadow: colors.softShadow,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_off_rounded, size: 36, color: colors.danger),
                      const SizedBox(height: 10),
                      Text(prov.error!, textAlign: TextAlign.center, style: context.text.bodyMedium),
                      const SizedBox(height: 12),
                      FilledButton.tonal(onPressed: prov.load, child: const Text('Thử lại')),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ResultNotice extends StatelessWidget {
  final int count;
  final VoidCallback onClear;

  const _ResultNotice({required this.count, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final empty = count == 0;
    return Container(
      padding: const EdgeInsets.only(left: 14, right: 4),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(999),
        boxShadow: colors.softShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            empty ? Icons.search_off_rounded : Icons.place_rounded,
            size: 16,
            color: empty ? colors.danger : context.scheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            empty ? 'Không có địa điểm phù hợp' : '$count địa điểm phù hợp',
            style: context.text.labelMedium,
          ),
          TextButton(
            onPressed: onClear,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              textStyle: context.text.labelMedium!.copyWith(fontWeight: FontWeight.w700),
            ),
            child: const Text('Xóa lọc'),
          ),
        ],
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _MapButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: colors.card,
        shape: const CircleBorder(),
        elevation: 0,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: colors.softShadow),
            child: Icon(icon, color: colors.textPrimary),
          ),
        ),
      ),
    );
  }
}

/// Marker dạng ghim: màu và icon theo loại, sao vàng nếu đang được quảng bá.
class _MapPin extends StatelessWidget {
  final PlaceModel place;
  final bool selected;
  final double size;

  const _MapPin({required this.place, required this.selected, required this.size});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = place.type.color(colors);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: selected ? 3 : 2.5),
                boxShadow: [
                  BoxShadow(
                    color: selected ? color.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.25),
                    blurRadius: selected ? 14 : 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(place.type.icon, color: Colors.white, size: size * 0.5),
            ),
            if (place.hasBanner)
              Positioned(
                top: -3,
                right: -3,
                child: Container(
                  width: 17,
                  height: 17,
                  decoration: BoxDecoration(
                    color: colors.sponsored,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Icon(Icons.star_rounded, size: 11, color: Colors.white),
                ),
              ),
          ],
        ),
        CustomPaint(size: const Size(12, 8), painter: _PinTailPainter(color)),
      ],
    );
  }
}

class _PinTailPainter extends CustomPainter {
  final Color color;

  const _PinTailPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PinTailPainter old) => old.color != color;
}

class _PlacePreviewCard extends StatelessWidget {
  final PlaceModel place;
  final VoidCallback onClose;

  const _PlacePreviewCard({super.key, required this.place, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: colors.shadow, blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => openPlaceDetail(context, place),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 4, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        width: 86,
                        height: 86,
                        child: PlaceImage(place: place, displayWidth: 86),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              place.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            PlaceMetaLine(place: place),
                            if (place.address != null) ...[
                              const SizedBox(height: 5),
                              PlaceAddressLine(address: place.address!),
                            ],
                            if (place.displayPrice != null) ...[
                              const SizedBox(height: 6),
                              PlacePriceLine(price: place.displayPrice!),
                            ],
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Đóng',
                      onPressed: onClose,
                      icon: Icon(Icons.close_rounded, color: colors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Launcher.directions(context, place),
                      icon: const Icon(Icons.directions_outlined, size: 20),
                      label: const Text('Chỉ đường'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => openPlaceDetail(context, place),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                      label: const Text('Xem chi tiết'),
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
