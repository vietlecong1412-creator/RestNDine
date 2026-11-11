import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../config/map_tiles.dart';
import '../../models/place_model.dart';
import '../../providers/location_provider.dart';
import '../../providers/place_provider.dart';
import '../../providers/route_provider.dart';
import '../../services/route_service.dart' show TravelMode;
import '../../widgets/location_widgets.dart';
import '../../widgets/place_image.dart';
import '../home/widgets/place_card.dart';
import '../home/widgets/search_filter_bar.dart';
import '../shell/main_shell.dart';
import 'directions.dart';
import 'my_location.dart';
import 'place_clusters.dart';
import 'place_marker_layer.dart';

/// Tab "Bản đồ": bản đồ toàn màn hình, tìm kiếm nổi phía trên, thẻ xem trước phía dưới.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _defaultCenter = LatLng(10.7769, 106.7009); // TP. Hồ Chí Minh

  /// Phóng tới nhóm không quá mức này (ở zoom 17 trở lên ghim không còn bị gom theo lưới).
  static const _clusterFitMaxZoom = 18.0;

  final MapController _map = MapController();
  late final LocationProvider _location = context.read<LocationProvider>();
  late final RouteProvider _route = context.read<RouteProvider>();
  bool _mapReady = false;

  /// Tuyến (đích + cách đi) đã canh camera; tính lại tuyến khi đi chệch thì không canh lại cho đỡ giật.
  (int, TravelMode)? _fittedRoute;
  List<PlaceModel> _routePlaces = const [];
  String _fittedQuery = '';

  /// Camera đã do người dùng (kéo, tìm kiếm, chọn quán) điều khiển: không tự kéo về vị trí nữa.
  bool _cameraTouched = false;
  bool _centeredOnUser = false;

  @override
  void initState() {
    super.initState();
    _location.addListener(_onLocationChanged);
    _route.addListener(_onRouteChanged);
  }

  @override
  void dispose() {
    _location.removeListener(_onLocationChanged);
    _route.removeListener(_onRouteChanged);
    _map.dispose();
    super.dispose();
  }

  /// Lần đầu biết vị trí (bản đồ thường đã dựng sẵn từ trước): đưa camera về chỗ người dùng,
  /// trừ khi họ đã tự di chuyển bản đồ.
  void _onLocationChanged() {
    final pos = _location.position;
    if (pos != null) _route.updatePosition(pos); // đi chệch khỏi tuyến thì tìm lại
    if (pos == null || _centeredOnUser || _cameraTouched || !_mapReady) return;
    _centeredOnUser = true;
    _map.move(pos, 15);
  }

  /// Có tuyến mới (đích hoặc cách đi khác): canh camera vừa toàn tuyến, chừa chỗ cho bảng chỉ đường.
  void _onRouteChanged() {
    final target = _route.target, result = _route.result;
    if (target == null) {
      _fittedRoute = null;
      return;
    }
    final key = (target.id, _route.mode);
    if (result == null || key == _fittedRoute || !_mapReady || !mounted) return;
    _fittedRoute = key;
    _cameraTouched = true;
    final top = MediaQuery.paddingOf(context).top;
    _map.fitCamera(CameraFit.coordinates(
      coordinates: result.points,
      padding: EdgeInsets.fromLTRB(48, top + 48, 48, 330),
      maxZoom: 17,
    ));
  }

  /// Nút "Vị trí của tôi": xin quyền nếu cần, đưa camera tới đủ gần để thấy các quán xung quanh.
  Future<void> _goToMyLocation() async {
    final pos = await locateWithFeedback(context);
    if (pos == null || !mounted) return;
    _centeredOnUser = true;
    _map.move(pos, math.max(_map.camera.zoom, 16));
  }

  LatLng _initialCenter(List<PlaceModel> places) {
    for (final p in places) {
      if (p.hasValidLocation) return LatLng(p.latitude, p.longitude);
    }
    return _defaultCenter;
  }

  /// Vừa tìm kiếm xong thì đưa camera tới các kết quả.
  ///
  /// Bản đồ được dựng sẵn (ẩn) từ trước khi mở tab; lúc đó chưa đưa camera đi đâu cả, để tìm rồi
  /// xoá từ khoá ở trang chủ không làm bản đồ kẹt ở góc nhìn của lần tìm cũ.
  void _maybeFitToSearch(PlaceProvider prov, {required bool visible}) {
    if (!visible) return;
    final q = prov.searchQuery.trim();
    if (q == _fittedQuery) return;
    _fittedQuery = q;
    if (q.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitTo(prov.places));
  }

  void _fitTo(List<PlaceModel> places) {
    if (!_mapReady || !mounted) return;
    _cameraTouched = true;
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
    _cameraTouched = true;
    prov.selectPlace(place);
    // Dời tâm lên một chút để thẻ xem trước không che marker
    _map.move(
      LatLng(place.latitude, place.longitude),
      math.max(_map.camera.zoom, 15),
      offset: const Offset(0, -70),
    );
  }

  /// Phóng tới khu có địa điểm gần tâm bản đồ nhất: thu nhỏ hết cỡ thì tâm có thể đang ở biển
  /// hay nước khác, phóng to tại chỗ sẽ chẳng thấy quán nào.
  void _zoomToNearest(List<PlaceModel> places) {
    _cameraTouched = true;
    final center = _map.camera.center;
    PlaceModel? nearest;
    var best = double.infinity;
    for (final p in places) {
      if (!p.hasValidLocation) continue;
      final dLat = p.latitude - center.latitude, dLng = p.longitude - center.longitude;
      final d = dLat * dLat + dLng * dLng;
      if (d < best) {
        best = d;
        nearest = p;
      }
    }
    _map.move(nearest == null ? center : LatLng(nearest.latitude, nearest.longitude), 15);
  }

  /// Chạm vào nhóm: phóng tới để tách ghim; nhóm trùng toạ độ thì mở danh sách để chọn.
  void _openCluster(PlaceProvider prov, PlaceCluster cluster) {
    if (cluster.isSameSpot || _map.camera.zoom >= _clusterFitMaxZoom - 0.5) {
      _showClusterSheet(prov, cluster);
      return;
    }
    final top = MediaQuery.paddingOf(context).top;
    _cameraTouched = true;
    _map.fitCamera(
      CameraFit.bounds(
        bounds: cluster.bounds,
        padding: EdgeInsets.fromLTRB(56, top + 150, 56, 120),
        maxZoom: _clusterFitMaxZoom,
      ),
    );
  }

  Future<void> _showClusterSheet(PlaceProvider prov, PlaceCluster cluster) async {
    final picked = await showModalBottomSheet<PlaceModel>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _ClusterSheet(places: cluster.places),
    );
    if (picked != null && mounted) _select(prov, picked);
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<PlaceProvider>();
    final colors = context.colors;
    final selected = prov.selectedPlace;
    // IndexedStack giữ cả animation của tab ẩn (Visibility.maintain) nên phải hỏi tab đang chọn
    final visible = context.select<ShellController, bool>((s) => s.index == ShellController.map);
    _maybeFitToSearch(prov, visible: visible);
    final locating = context.select<LocationProvider, bool>((l) => l.locating);
    final routeTarget = context.select<RouteProvider, PlaceModel?>((r) => r.target);
    final routing = routeTarget != null;
    if (routing && (_routePlaces.isEmpty || _routePlaces.first.id != routeTarget.id)) {
      _routePlaces = [routeTarget]; // giữ nguyên list để lớp ghim không phải gom nhóm lại mỗi lần dựng
    }

    return PopScope(
      // Đang chỉ đường thì nút Back tắt chỉ đường trước (chỉ khi đang ở tab Bản đồ)
      canPop: !(routing && visible),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && routing && visible) _route.clear();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        // Nền bản đồ sáng ở cả chế độ tối
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          body: Stack(
            children: [
              FlutterMap(
                mapController: _map,
                options: MapOptions(
                  // Đã biết vị trí thì mở ngay tại chỗ người dùng: app gợi ý quán gần bạn
                  initialCenter: _location.position ?? _initialCenter(prov.places),
                  // Đủ gần để thấy ngay các quán nổi bật quanh trung tâm (xem PlaceMarkerLayer.browseMinZoom)
                  initialZoom: 15,
                  minZoom: 4,
                  maxZoom: 19,
                  onMapReady: () {
                    _mapReady = true;
                    if (_location.position != null) {
                      _centeredOnUser = true;
                    }
                  },
                  onPositionChanged: (_, hasGesture) {
                    if (hasGesture) _cameraTouched = true;
                  },
                  onTap: (_, __) {
                    if (!routing) prov.selectPlace(null);
                  },
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  MapTiles.layer(),
                  const RouteLine(),
                  // Đang chỉ đường: chỉ còn ghim nơi đến cho bản đồ gọn
                  PlaceMarkerLayer(
                    places: routing ? _routePlaces : prov.places,
                    browsing: !routing && !prov.isFiltering,
                    selected: routing ? routeTarget : selected,
                    onSelect: (p) {
                      if (!routing) _select(prov, p);
                    },
                    onClusterTap: (c) => _openCluster(prov, c),
                  ),
                  const MyLocationLayer(),
                  _ZoomInHint(
                    enabled: !routing && !prov.isFiltering && selected == null,
                    onTap: () => _zoomToNearest(prov.places),
                  ),
                  MapTiles.attribution,
                ],
              ),

              // Tìm kiếm + bộ lọc nổi trên bản đồ (ẩn khi đang chỉ đường)
              if (!routing)
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

              // Nút nổi góc phải, ẩn khi đang xem một địa điểm (thẻ xem trước chiếm phía dưới).
              // "Xem tất cả kết quả" chỉ khi đang tìm kiếm/lọc: xem tự do thì toàn bộ là cả nước,
              // mà ở mức đó bản đồ không hiện ghim
              Positioned(
                right: 16,
                bottom: 34,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PopIn(
                      show: !routing && selected == null && prov.isFiltering,
                      child: _MapButton(
                        icon: Icons.zoom_out_map_rounded,
                        tooltip: 'Xem tất cả kết quả',
                        onTap: () => _fitTo(prov.places),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _PopIn(
                      show: !routing && selected == null,
                      child: _MapButton(
                        icon: Icons.my_location_rounded,
                        tooltip: 'Vị trí của tôi',
                        busy: locating,
                        onTap: _goToMyLocation,
                      ),
                    ),
                  ],
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
                  child: routing
                      ? const RoutePanel(key: ValueKey('route'))
                      : selected == null
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

/// Hiện/ẩn nút nổi bằng hiệu ứng phóng; lúc ẩn thì không bấm được và trình đọc màn hình bỏ qua.
class _PopIn extends StatelessWidget {
  final bool show;
  final Widget child;

  const _PopIn({required this.show, required this.child});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !show,
      child: ExcludeSemantics(
        excluding: !show,
        child: AnimatedScale(
          scale: show ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: child,
        ),
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  /// Đang xử lý: hiện vòng xoay thay icon và tạm không nhận bấm.
  final bool busy;

  const _MapButton({required this.icon, required this.tooltip, required this.onTap, this.busy = false});

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
          onTap: busy ? null : onTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: colors.softShadow),
            child: busy
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : Icon(icon, color: colors.textPrimary),
          ),
        ),
      ),
    );
  }
}

/// Gợi ý phóng to khi đang xem tự do mà bản đồ thu quá nhỏ (lúc này không hiện ghim nào).
/// Nằm trong `FlutterMap.children` để đọc mức zoom hiện tại mỗi khung hình.
class _ZoomInHint extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _ZoomInHint({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final show = enabled && MapCamera.of(context).zoom < PlaceMarkerLayer.browseMinZoom;
    final colors = context.colors;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 34),
        child: IgnorePointer(
          ignoring: !show,
          child: AnimatedOpacity(
            opacity: show ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: Material(
              color: colors.card,
              shape: const StadiumBorder(),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: onTap,
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: colors.softShadow,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.zoom_in_rounded, size: 20, color: context.scheme.primary),
                      const SizedBox(width: 8),
                      Text('Phóng to để xem địa điểm', style: context.text.labelLarge),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Danh sách các địa điểm chung một chỗ trên bản đồ (phóng to cũng không tách ra được).
class _ClusterSheet extends StatelessWidget {
  final List<PlaceModel> places;

  const _ClusterSheet({required this.places});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('${places.length} địa điểm tại đây', style: context.text.titleMedium),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 8),
                itemCount: places.length,
                itemBuilder: (_, i) {
                  final p = places[i];
                  final color = p.type.color(colors);
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.15),
                      child: Icon(p.type.icon, color: color, size: 20),
                    ),
                    title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: p.address == null
                        ? Text(p.categoryLabel)
                        : Text(p.address!, maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => Navigator.of(context).pop(p),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
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
                      onPressed: () => openDirections(context, place),
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
