import 'package:dio/dio.dart';
import 'package:flutter/material.dart' show IconData, Icons;
import 'package:latlong2/latlong.dart' show LatLng;
import 'api_exception.dart';

/// Cách đi khi tìm đường. OSRM không có hồ sơ riêng cho xe máy; luật đường (một chiều, cấm rẽ)
/// của xe máy và ô tô ở Việt Nam gần như giống nhau nên dùng chung hồ sơ ô tô.
enum TravelMode {
  drive('routed-car', 'driving', 'Đi xe', Icons.two_wheeler_rounded),
  walk('routed-foot', 'foot', 'Đi bộ', Icons.directions_walk_rounded);

  const TravelMode(this.server, this.profile, this.label, this.icon);

  final String server;
  final String profile;
  final String label;
  final IconData icon;
}

/// Một bước rẽ trong tuyến đường, đã dịch sang tiếng Việt.
class RouteStep {
  final String instruction;
  final double distance;
  final LatLng location;
  final IconData icon;

  const RouteStep({required this.instruction, required this.distance, required this.location, required this.icon});
}

class RouteResult {
  final TravelMode mode;
  final List<LatLng> points;

  /// Mét theo đường đi (không phải đường chim bay).
  final double distance;

  /// Giây, theo tốc độ trung bình của OSRM (chưa tính kẹt xe).
  final double duration;
  final List<RouteStep> steps;

  const RouteResult({
    required this.mode,
    required this.points,
    required this.distance,
    required this.duration,
    required this.steps,
  });

  /// Đọc phản hồi `route/v1` của OSRM (geometries=geojson, steps=true).
  factory RouteResult.fromOsrm(Map<String, dynamic> json, TravelMode mode, {String? destinationName}) {
    final route = (json['routes'] as List).first as Map<String, dynamic>;
    final coords = (route['geometry'] as Map<String, dynamic>)['coordinates'] as List;
    final steps = <RouteStep>[];
    for (final leg in route['legs'] as List) {
      for (final s in (leg as Map<String, dynamic>)['steps'] as List) {
        final step = s as Map<String, dynamic>;
        final m = step['maneuver'] as Map<String, dynamic>;
        final loc = m['location'] as List;
        steps.add(RouteStep(
          instruction: describeManeuver(
            type: m['type'] as String? ?? '',
            modifier: m['modifier'] as String?,
            name: step['name'] as String?,
            exit: m['exit'] as int?,
            destinationName: destinationName,
          ),
          distance: (step['distance'] as num).toDouble(),
          location: LatLng((loc[1] as num).toDouble(), (loc[0] as num).toDouble()),
          icon: maneuverIcon(m['type'] as String? ?? '', m['modifier'] as String?),
        ));
      }
    }
    return RouteResult(
      mode: mode,
      points: [for (final c in coords) LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())],
      distance: (route['distance'] as num).toDouble(),
      duration: (route['duration'] as num).toDouble(),
      steps: steps,
    );
  }
}

const _turn = {
  'left': 'Rẽ trái',
  'right': 'Rẽ phải',
  'slight left': 'Chếch sang trái',
  'slight right': 'Chếch sang phải',
  'sharp left': 'Rẽ gắt sang trái',
  'sharp right': 'Rẽ gắt sang phải',
  'straight': 'Đi thẳng',
  'uturn': 'Quay đầu',
};

const _side = {'left': 'bên trái', 'right': 'bên phải', 'slight left': 'bên trái', 'slight right': 'bên phải'};

/// Câu chỉ dẫn tiếng Việt từ một maneuver của OSRM (OSRM không có sẵn tiếng Việt).
String describeManeuver({
  required String type,
  String? modifier,
  String? name,
  int? exit,
  String? destinationName,
}) {
  final road = (name == null || name.trim().isEmpty) ? null : name.trim();
  final turn = _turn[modifier] ?? 'Đi tiếp';
  String onto(String verb) => road == null ? verb : '$verb vào $road';

  switch (type) {
    case 'depart':
      return road == null ? 'Xuất phát' : 'Xuất phát theo $road';
    case 'arrive':
      final where = destinationName ?? 'nơi cần đến';
      final side = _side[modifier];
      return side == null ? 'Đến $where' : 'Đến $where, ở $side';
    case 'new name':
      return road == null ? 'Đi tiếp' : 'Đi tiếp vào $road';
    case 'continue':
      return onto(modifier == 'straight' || modifier == null ? 'Đi thẳng' : turn);
    case 'merge':
      return road == null ? 'Nhập làn' : 'Nhập vào $road';
    case 'on ramp':
      return onto('Lên đường dẫn');
    case 'off ramp':
      return onto('Rẽ ra');
    case 'fork':
      final branch = (modifier ?? '').contains('left') ? 'trái' : 'phải';
      return onto('Đi theo nhánh $branch');
    case 'end of road':
      return onto('Cuối đường, ${turn.toLowerCase()}');
    case 'roundabout':
    case 'rotary':
      final out = exit == null ? 'ra ở lối phù hợp' : 'ra ở lối thứ $exit';
      return road == null ? 'Vào vòng xoay, $out' : 'Vào vòng xoay, $out vào $road';
    case 'exit roundabout':
    case 'exit rotary':
      return onto('Ra khỏi vòng xoay');
    default: // turn, notification, use lane...
      return onto(turn);
  }
}

IconData maneuverIcon(String type, String? modifier) {
  if (type == 'depart') return Icons.trip_origin_rounded;
  if (type == 'arrive') return Icons.flag_rounded;
  if (type == 'roundabout' || type == 'rotary' || type.startsWith('exit ro')) return Icons.roundabout_right_rounded;
  if (type == 'merge') return Icons.merge_rounded;
  if (type == 'fork') return (modifier ?? '').contains('left') ? Icons.fork_left_rounded : Icons.fork_right_rounded;
  return switch (modifier) {
    'left' => Icons.turn_left_rounded,
    'right' => Icons.turn_right_rounded,
    'slight left' => Icons.turn_slight_left_rounded,
    'slight right' => Icons.turn_slight_right_rounded,
    'sharp left' => Icons.turn_sharp_left_rounded,
    'sharp right' => Icons.turn_sharp_right_rounded,
    'uturn' => Icons.u_turn_left_rounded,
    _ => Icons.straight_rounded,
  };
}

/// Tìm đường bằng OSRM của FOSSGIS (routing.openstreetmap.de): miễn phí, không cần khoá API,
/// dữ liệu OpenStreetMap. Quy định sử dụng: ghi rõ tên ứng dụng, không gọi dồn dập.
class RouteService {
  RouteService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://routing.openstreetmap.de',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              headers: {'User-Agent': 'RestNDine-App/1.0 (do an sinh vien)'},
            ));

  final Dio _dio;

  Future<RouteResult> fetch(LatLng from, LatLng to, TravelMode mode, {String? destinationName}) async {
    // OSRM nhận toạ độ theo thứ tự kinh độ,vĩ độ
    final path = '/${mode.server}/route/v1/${mode.profile}/'
        '${from.longitude},${from.latitude};${to.longitude},${to.latitude}';
    try {
      final res = await _dio.get(path, queryParameters: {
        'overview': 'full',
        'geometries': 'geojson',
        'steps': 'true',
      });
      final data = res.data as Map<String, dynamic>;
      if (data['code'] != 'Ok' || (data['routes'] as List?)?.isEmpty != false) {
        throw const ApiException('Không tìm được đường đi tới địa điểm này.');
      }
      return RouteResult.fromOsrm(data, mode, destinationName: destinationName);
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 400) {
        // NoRoute / NoSegment: một trong hai điểm không gần con đường nào
        throw const ApiException('Không tìm được đường đi tới địa điểm này.');
      }
      throw ApiException.from(e, fallback: 'Không tìm được đường đi. Kiểm tra mạng và thử lại.');
    }
  }
}
