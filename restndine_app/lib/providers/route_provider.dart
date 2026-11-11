import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import '../models/place_model.dart';
import '../services/api_exception.dart';
import '../services/route_service.dart';

/// Chỉ đường ngay trong app: địa điểm đích, cách đi và tuyến đường hiện tại, dùng chung cho
/// trang chi tiết (bấm "Chỉ đường") và tab Bản đồ (vẽ tuyến, bảng thông tin).
class RouteProvider extends ChangeNotifier {
  RouteProvider({RouteService? service}) : _service = service ?? RouteService();

  /// Đi chệch khỏi tuyến xa hơn mức này (mét) thì tìm đường lại từ chỗ đang đứng.
  static const offRouteMeters = 60.0;

  /// Máy chủ miễn phí: không tìm lại dồn dập dù GPS báo chệch liên tục.
  static const minRerouteInterval = Duration(seconds: 20);

  final RouteService _service;
  PlaceModel? _target;
  LatLng? _from;
  TravelMode _mode = TravelMode.drive;
  RouteResult? _result;
  bool _loading = false;
  String? _error;
  DateTime? _lastFetch;
  int _request = 0;

  /// Đang chỉ đường (kể cả lúc đang tải hay lỗi).
  bool get active => _target != null;
  PlaceModel? get target => _target;
  TravelMode get mode => _mode;
  RouteResult? get result => _result;
  bool get loading => _loading;
  String? get error => _error;

  /// Bắt đầu chỉ đường từ [from] tới [target] với cách đi đang chọn.
  Future<void> start(PlaceModel target, LatLng from) {
    _target = target;
    _from = from;
    _result = null;
    return _fetch();
  }

  Future<void> setMode(TravelMode mode) {
    if (mode == _mode) return Future.value();
    _mode = mode;
    _result = null;
    return _fetch();
  }

  Future<void> retry() => _fetch();

  /// Gọi khi vị trí người dùng thay đổi: đi chệch khỏi tuyến thì tìm lại từ chỗ mới.
  void updatePosition(LatLng position) {
    final r = _result;
    if (!active || _loading || r == null) return;
    final last = _lastFetch;
    if (last != null && DateTime.now().difference(last) < minRerouteInterval) return;
    if (distanceToRoute(position, r.points) > offRouteMeters) {
      _from = position;
      _fetch();
    }
  }

  void clear() {
    _target = null;
    _from = null;
    _result = null;
    _error = null;
    _loading = false;
    _request++; // bỏ qua kết quả của request đang chạy (nếu có)
    notifyListeners();
  }

  Future<void> _fetch() async {
    final target = _target, from = _from;
    if (target == null || from == null) return;
    final id = ++_request;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final r = await _service.fetch(from, LatLng(target.latitude, target.longitude), _mode,
          destinationName: target.name);
      if (id == _request) _result = r;
    } on ApiException catch (e) {
      if (id == _request) _error = e.message;
    } finally {
      // Request cũ (đổi cách đi, đóng chỉ đường giữa chừng) thì không đụng tới trạng thái mới
      if (id == _request) {
        _loading = false;
        _lastFetch = DateTime.now();
        notifyListeners();
      }
    }
  }
}

/// Khoảng cách gần nhất (mét) từ [p] tới đường gấp khúc [line]. Chiếu phẳng quanh [p] là đủ chính xác
/// ở khoảng cách vài trăm mét.
double distanceToRoute(LatLng p, List<LatLng> line) {
  if (line.isEmpty) return double.infinity;
  const metersPerDegree = 111320.0;
  final kx = math.cos(p.latitude * math.pi / 180) * metersPerDegree;
  (double, double) local(LatLng q) => ((q.longitude - p.longitude) * kx, (q.latitude - p.latitude) * metersPerDegree);

  if (line.length == 1) {
    final (x, y) = local(line.first);
    return math.sqrt(x * x + y * y);
  }
  var best = double.infinity;
  for (var i = 0; i < line.length - 1; i++) {
    final (ax, ay) = local(line[i]);
    final (bx, by) = local(line[i + 1]);
    final dx = bx - ax, dy = by - ay;
    final len2 = dx * dx + dy * dy;
    final t = len2 == 0 ? 0.0 : (-(ax * dx + ay * dy) / len2).clamp(0.0, 1.0);
    final cx = ax + t * dx, cy = ay + t * dy;
    best = math.min(best, math.sqrt(cx * cx + cy * cy));
  }
  return best;
}
