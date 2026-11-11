import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import '../../config/app_theme.dart';
import '../../models/place_model.dart';
import 'place_clusters.dart';

/// Lớp ghim của tab Bản đồ, đặt trong `FlutterMap.children`. Có hai chế độ:
///
/// * Xem tự do ([browsing], không tìm kiếm/lọc) — như Google Maps: thu nhỏ dưới [browseMinZoom]
///   thì không hiện ghim; từ đó tới zoom 16 mỗi ô lưới chỉ hiện quán nổi bật nhất (quảng bá, hạng
///   sao — đúng thứ tự server trả về), phóng to tới đâu hiện thêm tới đó.
/// * Đang tìm kiếm/lọc: hiện hết kết quả, chỗ dày thì gộp thành vòng tròn có số đếm.
///
/// Đọc camera mỗi khung hình (để biết mức zoom và vùng đang xem) nhưng chỉ dựng lại danh sách
/// marker khi đổi mức zoom nguyên, kéo ra khỏi vùng đã dựng, hoặc dữ liệu/lựa chọn thay đổi.
/// Các khung hình còn lại dùng lại đúng danh sách cũ nên Flutter bỏ qua việc dựng lại từng ghim.
class PlaceMarkerLayer extends StatefulWidget {
  /// Dưới mức này, khi không tìm kiếm, bản đồ không hiện ghim nào để tránh rối mắt.
  static const browseMinZoom = 14;

  final List<PlaceModel> places;
  final bool browsing;
  final PlaceModel? selected;
  final ValueChanged<PlaceModel> onSelect;
  final ValueChanged<PlaceCluster> onClusterTap;

  const PlaceMarkerLayer({
    super.key,
    required this.places,
    required this.browsing,
    required this.selected,
    required this.onSelect,
    required this.onClusterTap,
  });

  @override
  State<PlaceMarkerLayer> createState() => _PlaceMarkerLayerState();
}

class _PlaceMarkerLayerState extends State<PlaceMarkerLayer> {
  PlaceClusterer? _clusterer;
  List<Marker> _markers = const [];
  bool _dirty = true;
  int? _builtZoom;
  LatLngBounds? _builtArea;
  AppColors? _builtColors;

  @override
  void didUpdateWidget(PlaceMarkerLayer old) {
    super.didUpdateWidget(old);
    if (!identical(old.places, widget.places)) {
      _clusterer = null;
      _dirty = true;
    }
    if (old.selected?.id != widget.selected?.id || old.browsing != widget.browsing) _dirty = true;
  }

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final colors = context.colors;
    // Làm tròn xuống: ô lưới trên màn hình chỉ to hơn (64–128 px), các nhóm không đè nhau
    final zoom = camera.zoom.floor();
    final view = camera.visibleBounds;

    final area = _builtArea;
    if (_dirty ||
        zoom != _builtZoom ||
        !identical(colors, _builtColors) ||
        area == null ||
        !area.containsBounds(view)) {
      // Dựng dư nửa màn hình mỗi phía để kéo bản đồ không thấy ghim hiện chậm ở mép
      final next = _expand(view, 0.5);
      _markers = _buildMarkers(zoom, next, colors);
      _builtZoom = zoom;
      _builtArea = next;
      _builtColors = colors;
      _dirty = false;
    }
    return MarkerLayer(markers: _markers);
  }

  List<Marker> _buildMarkers(int zoom, LatLngBounds area, AppColors colors) {
    final clusterer = _clusterer ??= PlaceClusterer(widget.places);
    final selected = widget.selected;
    final browsing = widget.browsing;

    final pins = <Marker>[];
    final groups = <Marker>[];
    if (!browsing || zoom >= PlaceMarkerLayer.browseMinZoom) {
      for (final c in clusterer.clustersAt(zoom)) {
        if (!area.contains(c.point)) continue;
        // Xem tự do: mỗi ô chỉ hiện quán nổi bật nhất (đứng đầu nhóm). Nhóm trùng toạ độ ở zoom
        // gần vẫn là vòng tròn, vì phóng to thêm cũng không tách được, phải mở danh sách
        final representative = browsing && !c.isSameSpot;
        if (c.isSingle || representative) {
          final p = c.places.first;
          // Ghim đang chọn được vẽ riêng ở trên cùng
          if (p.id != selected?.id) pins.add(_pinMarker(p, selected: false));
        } else {
          groups.add(_clusterMarker(c, zoom));
        }
      }
    }

    return [
      ...pins,
      ...groups,
      if (selected != null && selected.hasValidLocation) _pinMarker(selected, selected: true),
    ];
  }

  Marker _pinMarker(PlaceModel p, {required bool selected}) {
    final size = selected ? 46.0 : 36.0;
    return Marker(
      key: ValueKey(selected ? 'selected-${p.id}' : 'pin-${p.id}'),
      point: LatLng(p.latitude, p.longitude),
      width: size + 8,
      height: size + 9,
      alignment: Alignment.topCenter,
      child: Semantics(
        button: true,
        selected: selected,
        label: '${p.type.label} ${p.name}',
        child: GestureDetector(
          onTap: () => widget.onSelect(p),
          child: selected
              ? TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.6, end: 1),
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  builder: (_, scale, child) => Transform.scale(
                    scale: scale,
                    alignment: Alignment.bottomCenter,
                    child: child,
                  ),
                  child: MapPin(place: p, selected: true, size: size),
                )
              : MapPin(place: p, selected: false, size: size),
        ),
      ),
    );
  }

  Marker _clusterMarker(PlaceCluster c, int zoom) {
    // To dần theo số lượng nhưng có giới hạn: 2 → 42 px, 10 → 46 px, 100+ → 52 px
    final size = 34.0 + 6.0 * math.min(3.0, math.log(c.count) / math.ln10 + 1);
    return Marker(
      key: ValueKey('cluster-$zoom-${c.places.first.id}'),
      point: c.point,
      width: size,
      height: size,
      child: Semantics(
        button: true,
        label: '${c.count} địa điểm, chạm để xem',
        child: GestureDetector(
          onTap: () => widget.onClusterTap(c),
          child: ClusterBubble(count: c.count, size: size),
        ),
      ),
    );
  }

  static LatLngBounds _expand(LatLngBounds b, double factor) {
    final dLat = (b.north - b.south) * factor;
    final dLng = (b.east - b.west) * factor;
    return LatLngBounds.unsafe(
      north: math.min(85, b.north + dLat),
      south: math.max(-85, b.south - dLat),
      east: math.min(180, b.east + dLng),
      west: math.max(-180, b.west - dLng),
    );
  }
}

/// Ghim dạng giọt: màu và icon theo loại, sao vàng nếu đang được quảng bá.
///
/// Không dùng bóng đổ mờ cho ghim thường: hàng trăm lớp blur mỗi khung hình là phần tốn GPU
/// nhất khi kéo bản đồ; viền trắng đã đủ tách ghim khỏi nền.
class MapPin extends StatelessWidget {
  final PlaceModel place;
  final bool selected;
  final double size;

  const MapPin({super.key, required this.place, required this.selected, required this.size});

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
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: selected ? 3 : 2.5),
                boxShadow: selected
                    ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 14, offset: const Offset(0, 3))]
                    : null,
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

/// Vòng tròn đếm số địa điểm của một nhóm; quầng nhạt bên ngoài thay cho bóng đổ mờ.
class ClusterBubble extends StatelessWidget {
  final int count;
  final double size;

  const ClusterBubble({super.key, required this.count, required this.size});

  @override
  Widget build(BuildContext context) {
    final primary = context.scheme.primary;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(shape: BoxShape.circle, color: primary.withValues(alpha: 0.25)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: primary,
          border: Border.all(color: Colors.white, width: 2.5),
        ),
        child: Center(
          child: Text(
            count > 999 ? '999+' : '$count',
            maxLines: 1,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: count >= 100 ? 12.5 : 14,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
