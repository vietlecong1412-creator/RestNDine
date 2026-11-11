import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:provider/provider.dart';
import '../../providers/location_provider.dart';

/// Chấm xanh vị trí của người dùng, đặt trong `FlutterMap.children`.
class MyLocationLayer extends StatelessWidget {
  const MyLocationLayer({super.key});

  @override
  Widget build(BuildContext context) {
    final pos = context.select<LocationProvider, LatLng?>((l) => l.position);
    if (pos == null) return const SizedBox.shrink();
    return MarkerLayer(
      markers: [
        Marker(
          point: pos,
          width: 44,
          height: 44,
          child: Semantics(
            label: 'Vị trí của bạn',
            // Quầng nhạt thay cho bóng đổ mờ (rẻ hơn khi vẽ lại lúc kéo bản đồ)
            child: Container(
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x331A73E8)),
              alignment: Alignment.center,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1A73E8),
                  border: Border.all(color: Colors.white, width: 3),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
