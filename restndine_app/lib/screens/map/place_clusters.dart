import 'dart:math' as math;

import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:latlong2/latlong.dart' show LatLng;
import '../../models/place_model.dart';

/// Một nhóm địa điểm gần nhau trên bản đồ ở một mức zoom; nhóm một phần tử là ghim thường.
class PlaceCluster {
  PlaceCluster(this.places, this.point);

  /// Theo thứ tự gốc của danh sách (quảng bá, hạng sao trước).
  final List<PlaceModel> places;

  /// Trọng tâm của nhóm, nơi đặt marker.
  final LatLng point;

  int get count => places.length;
  bool get isSingle => places.length == 1;

  /// Khung bao các địa điểm, để phóng tới khi chạm vào nhóm.
  late final LatLngBounds bounds = LatLngBounds.fromPoints([
    for (final p in places) LatLng(p.latitude, p.longitude),
  ]);

  /// Mọi địa điểm cùng một chỗ (chung toà nhà, trùng dữ liệu): phóng to cũng không tách ra được.
  bool get isSameSpot =>
      bounds.north - bounds.south < 1e-5 && bounds.east - bounds.west < 1e-5;
}

/// Gom địa điểm theo lưới ô vuông [cellSize] px ở từng mức zoom nguyên (grid clustering).
///
/// Ô lưới cố định theo toạ độ thế giới nên khi kéo bản đồ các nhóm đứng yên, không nhảy;
/// kết quả mỗi mức zoom được nhớ lại vì danh sách địa điểm không đổi giữa các khung hình.
class PlaceClusterer {
  PlaceClusterer(
    List<PlaceModel> places, {
    this.cellSize = 64,
    this.mergeDistance = 52,
    this.maxClusterZoom = 16,
  }) : _points = [
          for (var i = 0; i < places.length; i++)
            if (places[i].hasValidLocation) _Projected(places[i], i),
        ];

  /// Cạnh ô lưới, tính bằng pixel logic ở mức zoom nguyên.
  final double cellSize;

  /// Hai ô kề nhau có tâm gần hơn khoảng này (px) thì gộp, để vòng tròn không đè lên nhau.
  /// Bằng đường kính vòng tròn lớn nhất; dùng cùng zoom làm tròn xuống nên trên màn hình
  /// khoảng cách thực tế chỉ có thể lớn hơn.
  final double mergeDistance;

  /// Zoom lớn hơn mức này thì ghim đã đủ thưa: chỉ gom các địa điểm trùng toạ độ.
  final int maxClusterZoom;

  final List<_Projected> _points;
  final Map<int, List<PlaceCluster>> _byZoom = {};

  List<PlaceCluster> clustersAt(int zoom) => _byZoom.putIfAbsent(zoom, () => _build(zoom));

  List<PlaceCluster> _build(int zoom) {
    if (zoom > maxClusterZoom) {
      final sameSpot = <(double, double), List<_Projected>>{};
      for (final p in _points) {
        (sameSpot[(p.place.latitude, p.place.longitude)] ??= []).add(p);
      }
      return [for (final g in sameSpot.values) _cluster(g)];
    }

    // Kích thước bản đồ thế giới ở mức zoom này: 256 px ở zoom 0, gấp đôi mỗi mức
    final world = 256 * math.pow(2, zoom).toDouble();
    final cells = <(int, int), _Cell>{};
    for (final p in _points) {
      final px = p.x * world, py = p.y * world;
      (cells[((px / cellSize).floor(), (py / cellSize).floor())] ??= _Cell()).add(p, px, py);
    }

    // Nhóm nằm sát hai bên đường kẻ ô sẽ đè lên nhau: gộp các ô kề nhau có tâm quá gần.
    // Ô đông nhất làm hạt nhân trước; ô đã làm hạt nhân thì không bị gộp tiếp, tránh gộp dây chuyền
    // (Sài Gòn nuốt Nha Trang rồi nuốt luôn Đà Nẵng).
    final ordered = cells.entries.toList()..sort((a, b) => b.value.members.length - a.value.members.length);
    for (final e in ordered) {
      final cell = e.value;
      if (cell.absorbed) continue;
      cell.seeded = true;
      for (var dx = -1; dx <= 1; dx++) {
        for (var dy = -1; dy <= 1; dy++) {
          if (dx == 0 && dy == 0) continue;
          final other = cells[(e.key.$1 + dx, e.key.$2 + dy)];
          if (other == null || other.absorbed || other.seeded) continue;
          final ox = other.cx - cell.cx, oy = other.cy - cell.cy;
          if (ox * ox + oy * oy < mergeDistance * mergeDistance) cell.absorb(other);
        }
      }
    }
    return [
      for (final c in cells.values)
        if (!c.absorbed) _cluster(c.members),
    ];
  }

  static PlaceCluster _cluster(List<_Projected> members) {
    members.sort((a, b) => a.index - b.index);
    final places = [for (final m in members) m.place];
    return PlaceCluster(places, _centroid(places));
  }

  static LatLng _centroid(List<PlaceModel> places) {
    if (places.length == 1) return LatLng(places.first.latitude, places.first.longitude);
    var lat = 0.0, lng = 0.0;
    for (final p in places) {
      lat += p.latitude;
      lng += p.longitude;
    }
    return LatLng(lat / places.length, lng / places.length);
  }
}

/// Một ô lưới đang gom; tâm là trung bình toạ độ pixel của các thành viên.
class _Cell {
  final List<_Projected> members = [];
  double _sumX = 0, _sumY = 0;
  bool absorbed = false;

  /// Đã làm hạt nhân gộp các ô xung quanh; không bị ô khác gộp nữa.
  bool seeded = false;

  double get cx => _sumX / members.length;
  double get cy => _sumY / members.length;

  void add(_Projected p, double px, double py) {
    members.add(p);
    _sumX += px;
    _sumY += py;
  }

  void absorb(_Cell other) {
    members.addAll(other.members);
    _sumX += other._sumX;
    _sumY += other._sumY;
    other.absorbed = true;
  }
}

/// Toạ độ Web Mercator chuẩn hoá về [0, 1], tính một lần cho mọi mức zoom.
class _Projected {
  _Projected(this.place, this.index)
      : x = (place.longitude + 180) / 360,
        y = _mercatorY(place.latitude);

  final PlaceModel place;

  /// Vị trí trong danh sách gốc, để giữ thứ tự khi liệt kê địa điểm của một nhóm.
  final int index;
  final double x;
  final double y;

  static double _mercatorY(double latitude) {
    final rad = latitude.clamp(-85.05112878, 85.05112878) * math.pi / 180;
    return (1 - math.log(math.tan(rad) + 1 / math.cos(rad)) / math.pi) / 2;
  }
}
