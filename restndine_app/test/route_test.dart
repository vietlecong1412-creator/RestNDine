import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:restndine_app/models/place_model.dart';
import 'package:restndine_app/providers/route_provider.dart';
import 'package:restndine_app/services/api_exception.dart';
import 'package:restndine_app/services/route_service.dart';

/// Rút gọn từ phản hồi thật của routing.openstreetmap.de (Lê Lợi → Nhà thờ Đức Bà).
Map<String, dynamic> _osrm({double distance = 1039}) => {
      'code': 'Ok',
      'routes': [
        {
          'distance': distance,
          'duration': 98.2,
          'geometry': {
            'coordinates': [
              [106.7019, 10.7756],
              [106.7004, 10.7769],
              [106.6990, 10.7798],
            ],
          },
          'legs': [
            {
              'steps': [
                {'name': 'Lê Lợi', 'distance': 162.0, 'maneuver': {'type': 'depart', 'modifier': 'right', 'location': [106.7019, 10.7756]}},
                {'name': 'Pasteur', 'distance': 659.0, 'maneuver': {'type': 'turn', 'modifier': 'right', 'location': [106.7004, 10.7769]}},
                {'name': '', 'distance': 0.0, 'maneuver': {'type': 'arrive', 'modifier': 'left', 'location': [106.6990, 10.7798]}},
              ],
            },
          ],
        },
      ],
    };

PlaceModel _place() => PlaceModel.fromJson({
      'id': 7,
      'name': 'Nhà thờ Đức Bà',
      'latitude': 10.7798,
      'longitude': 106.6990,
      'categories': const [],
    });

class _FakeRoutes extends RouteService {
  _FakeRoutes() : super(dio: Dio());

  final calls = <(LatLng, TravelMode)>[];
  Completer<RouteResult>? pending;
  ApiException? failWith;

  @override
  Future<RouteResult> fetch(LatLng from, LatLng to, TravelMode mode, {String? destinationName}) {
    calls.add((from, mode));
    if (failWith != null) return Future.error(failWith!);
    if (pending != null) return pending!.future;
    return Future.value(RouteResult.fromOsrm(_osrm(), mode, destinationName: destinationName));
  }
}

void main() {
  test('chỉ dẫn tiếng Việt từ maneuver của OSRM', () {
    expect(describeManeuver(type: 'turn', modifier: 'right', name: 'Pasteur'), 'Rẽ phải vào Pasteur');
    expect(describeManeuver(type: 'turn', modifier: 'slight left', name: ''), 'Chếch sang trái');
    expect(describeManeuver(type: 'depart', name: 'Lê Lợi'), 'Xuất phát theo Lê Lợi');
    expect(describeManeuver(type: 'roundabout', exit: 2, name: 'Lê Duẩn'), 'Vào vòng xoay, ra ở lối thứ 2 vào Lê Duẩn');
    expect(describeManeuver(type: 'end of road', modifier: 'left', name: 'Hàm Nghi'), 'Cuối đường, rẽ trái vào Hàm Nghi');
    expect(describeManeuver(type: 'arrive', modifier: 'left', destinationName: 'Phở Hòa'), 'Đến Phở Hòa, ở bên trái');
  });

  test('đọc tuyến đường: toạ độ, khoảng cách, các bước', () {
    final r = RouteResult.fromOsrm(_osrm(), TravelMode.drive, destinationName: 'Nhà thờ Đức Bà');
    expect(r.points.first, const LatLng(10.7756, 106.7019)); // OSRM trả [kinh độ, vĩ độ]
    expect(r.distance, 1039);
    expect(r.steps.map((s) => s.instruction), [
      'Xuất phát theo Lê Lợi',
      'Rẽ phải vào Pasteur',
      'Đến Nhà thờ Đức Bà, ở bên trái',
    ]);
  });

  test('khoảng cách tới tuyến đường', () {
    final line = [const LatLng(10.7700, 106.7000), const LatLng(10.7700, 106.7100)];
    expect(distanceToRoute(const LatLng(10.7700, 106.7050), line), lessThan(1));
    // 0,001 độ vĩ ≈ 111 m về phía bắc
    expect(distanceToRoute(const LatLng(10.7710, 106.7050), line), closeTo(111, 2));
  });

  test('bắt đầu, đổi cách đi, tắt chỉ đường', () async {
    final service = _FakeRoutes();
    final route = RouteProvider(service: service);
    await route.start(_place(), const LatLng(10.7756, 106.7019));
    expect(route.active, isTrue);
    expect(route.result?.mode, TravelMode.drive);

    await route.setMode(TravelMode.walk);
    expect(service.calls.map((c) => c.$2), [TravelMode.drive, TravelMode.walk]);
    expect(route.result?.mode, TravelMode.walk);

    route.clear();
    expect(route.active, isFalse);
    expect(route.result, isNull);
  });

  test('kết quả về muộn sau khi đã tắt chỉ đường thì bỏ qua', () async {
    final service = _FakeRoutes()..pending = Completer();
    final route = RouteProvider(service: service);
    final started = route.start(_place(), const LatLng(10.7756, 106.7019));
    expect(route.loading, isTrue);
    route.clear();
    service.pending!.complete(RouteResult.fromOsrm(_osrm(), TravelMode.drive));
    await started;
    expect(route.active, isFalse);
    expect(route.result, isNull);
  });

  test('lỗi tìm đường hiện thông báo', () async {
    final service = _FakeRoutes()..failWith = const ApiException('Không tìm được đường đi tới địa điểm này.');
    final route = RouteProvider(service: service);
    await route.start(_place(), const LatLng(10.7756, 106.7019));
    expect(route.error, 'Không tìm được đường đi tới địa điểm này.');
    expect(route.result, isNull);
  });

  test('đi chệch khỏi tuyến thì tìm lại, nhưng không dồn dập', () async {
    final service = _FakeRoutes();
    final route = RouteProvider(service: service);
    await route.start(_place(), const LatLng(10.7756, 106.7019));

    route.updatePosition(const LatLng(10.7757, 106.7018)); // vẫn trên tuyến
    expect(service.calls, hasLength(1));

    route.updatePosition(const LatLng(10.7800, 106.7100)); // chệch xa, nhưng vừa tìm xong
    expect(service.calls, hasLength(1));
  });
}
