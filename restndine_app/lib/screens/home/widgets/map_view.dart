import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../config/app_theme.dart';
import '../../../models/place_model.dart';
import 'place_card.dart';

class InteractiveMapView extends StatefulWidget {
  final List<PlaceModel> places;
  final PlaceModel? selectedPlace;
  final Function(PlaceModel?) onPlaceSelected;

  const InteractiveMapView({
    super.key,
    required this.places,
    this.selectedPlace,
    required this.onPlaceSelected,
  });

  @override
  State<InteractiveMapView> createState() => _InteractiveMapViewState();
}

class _InteractiveMapViewState extends State<InteractiveMapView> {
  // Vẽ quá nhiều marker làm bản đồ giật, nên chỉ vẽ các địa điểm gần tâm bản đồ đang xem
  static const _maxMarkers = 150;

  // Toạ độ mặc định khi cào dữ liệu không xác định được vị trí: địa điểm này chưa có vị trí thật
  static const _unknownLat = 10.7769;
  static const _unknownLng = 106.7009;

  final MapController _mapController = MapController();
  LatLng? _viewCenter;
  Timer? _moveDebounce;

  @override
  void dispose() {
    _moveDebounce?.cancel();
    super.dispose();
  }

  void _onMapMoved(MapCamera camera, bool hasGesture) {
    _moveDebounce?.cancel();
    _moveDebounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _viewCenter = camera.center);
    });
  }

  List<PlaceModel> _placesNear(LatLng center) {
    double distance(PlaceModel p) {
      final dLat = p.latitude - center.latitude;
      final dLng = p.longitude - center.longitude;
      return dLat * dLat + dLng * dLng;
    }

    final nearest = widget.places
        .where((p) =>
            p.latitude != 0 &&
            p.longitude != 0 &&
            !(p.latitude == _unknownLat && p.longitude == _unknownLng))
        .toList()
      ..sort((a, b) => distance(a).compareTo(distance(b)));

    // Nhiều địa điểm trùng toạ độ: mỗi điểm chỉ vẽ một marker để không chồng lên nhau
    final seen = <String>{};
    final visible = nearest
        .where((p) => seen.add('${p.latitude},${p.longitude}'))
        .take(_maxMarkers)
        .toList();

    final selected = widget.selectedPlace;
    if (selected != null && !visible.any((p) => p.id == selected.id)) visible.add(selected);
    return visible;
  }

  LatLng _getCenter() {
    if (widget.selectedPlace != null && widget.selectedPlace!.latitude != 0) {
      return LatLng(widget.selectedPlace!.latitude, widget.selectedPlace!.longitude);
    }
    if (widget.places.isNotEmpty) {
      final valid = widget.places.firstWhere(
        (p) => p.latitude != 0 && p.longitude != 0,
        orElse: () => widget.places.first,
      );
      if (valid.latitude != 0) {
        return LatLng(valid.latitude, valid.longitude);
      }
    }
    return const LatLng(10.7769, 106.7009); // TP. Hồ Chí Minh mặc định
  }

  @override
  Widget build(BuildContext context) {
    final center = _getCenter();

    final markers = _placesNear(_viewCenter ?? center).map((p) {
      final isSelected = widget.selectedPlace?.id == p.id;
      final isSponsored = p.hasBanner;

      Color markerColor = AppTheme.primaryColor;
      IconData icon = Icons.restaurant;

      if (p.categories.any((c) => c.slug == 'hotel')) {
        markerColor = const Color(0xFF1E88E5);
        icon = Icons.hotel;
      } else if (p.categories.any((c) => c.slug == 'cafe')) {
        markerColor = const Color(0xFF8D6E63);
        icon = Icons.local_cafe;
      }

      if (isSponsored) {
        markerColor = const Color(0xFFFF9800); // Gold for sponsored
      }

      return Marker(
        point: LatLng(p.latitude, p.longitude),
        width: isSelected ? 50 : 40,
        height: isSelected ? 50 : 40,
        child: GestureDetector(
          onTap: () {
            widget.onPlaceSelected(p);
            _mapController.move(LatLng(p.latitude, p.longitude), 15);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            decoration: BoxDecoration(
              color: markerColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: isSelected ? 3 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? markerColor.withOpacity(0.6)
                      : Colors.black.withOpacity(0.2),
                  blurRadius: isSelected ? 12 : 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: isSelected ? 26 : 20,
            ),
          ),
        ),
      );
    }).toList();

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 13.5,
            onTap: (_, __) => widget.onPlaceSelected(null),
            onPositionChanged: _onMapMoved,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
              userAgentPackageName: 'com.restndine.restndine_app',
              maxNativeZoom: 19,
            ),
            MarkerLayer(markers: markers),
            const SimpleAttributionWidget(source: Text('Tiles © Esri')),
          ],
        ),

        // Bottom Selected Place Card Popup
        if (widget.selectedPlace != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Stack(
              children: [
                PlaceCard(place: widget.selectedPlace!),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => widget.onPlaceSelected(null),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 16, color: Colors.grey),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
