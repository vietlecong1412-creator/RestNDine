import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:restndine_app/models/place_model.dart';
import 'package:restndine_app/providers/place_provider.dart';
import 'package:restndine_app/services/api_service.dart';

const _categories = [
  {'id': 1, 'name': 'Nhà hàng', 'slug': 'restaurant', 'icon': ''},
  {'id': 2, 'name': 'Khách sạn', 'slug': 'hotel', 'icon': ''},
  {'id': 3, 'name': 'Quán cà phê', 'slug': 'cafe', 'icon': ''},
];

Map<String, dynamic> _place(
  int id,
  String name,
  int cat, {
  bool sponsored = false,
  String? address,
  required double lat,
  required double lng,
}) =>
    {
      'id': id,
      'name': name,
      'address': address,
      'latitude': lat,
      'longitude': lng,
      'bannerUrl': sponsored ? 'b.jpg' : null,
      'bannerStatus': sponsored ? 2 : 0,
      'categories': [_categories[cat - 1]],
    };

class _Adapter implements HttpClientAdapter {
  bool fail = false;
  bool failCategories = false;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    if (fail || (failCategories && o.uri.path == '/api/places/categories')) {
      throw DioException(requestOptions: o, type: DioExceptionType.connectionError);
    }
    final data = o.uri.path == '/api/places/categories'
        ? _categories
        : [
            // Người dùng trong test đứng ở (10.776, 106.703): gần 3, rồi 1 (~550 m), 4 (~1,6 km), 2 (~3,7 km)
            _place(1, 'Phở Hòa Pasteur', 1, sponsored: true, address: 'Quận 3', lat: 10.780, lng: 106.700),
            _place(2, 'Cơm Tấm Ba Ghiền', 1, address: 'Phú Nhuận', lat: 10.800, lng: 106.680),
            _place(3, 'Khách sạn Rex', 2, address: 'Quận 1, Thành phố Hồ Chí Minh', lat: 10.776, lng: 106.703),
            _place(4, 'Cộng Cà Phê', 3, address: 'Quận 1', lat: 10.770, lng: 106.690),
          ];
    return ResponseBody.fromString(jsonEncode(data), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final adapter = _Adapter();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    adapter
      ..fail = false
      ..failCategories = false;
    ApiService().dio.httpClientAdapter = adapter;
  });

  test('tìm kiếm tại máy, không phân biệt dấu, khớp cả tên danh mục', () async {
    final prov = PlaceProvider(autoLoad: false);
    await prov.load();
    expect(prov.places, hasLength(4));
    expect(prov.featuredPlaces.map((p) => p.id), [1]);

    prov.setSearchQuery('com tam');
    expect(prov.places.map((p) => p.id), [2]);

    // Thứ tự theo điểm khớp, xem test xếp hạng bên dưới
    prov.setSearchQuery('quan 1');
    expect(prov.places.map((p) => p.id), unorderedEquals([3, 4]));

    prov.setSearchQuery('ca phe');
    expect(prov.places.map((p) => p.id), [4]);
  });

  test('"pho" tìm quán phở, không khớp chữ "Thành phố" trong địa chỉ', () async {
    final prov = PlaceProvider(autoLoad: false);
    await prov.load();

    prov.setSearchQuery('pho');
    expect(prov.places.map((p) => p.id), [1]);

    // Tên thành phố vẫn tìm được
    prov.setSearchQuery('ho chi minh');
    expect(prov.places.map((p) => p.id), [3]);
  });

  test('kết quả khớp tên/danh mục xếp trước kết quả chỉ khớp địa chỉ', () async {
    final prov = PlaceProvider(autoLoad: false);
    await prov.load();

    // 4 khớp danh mục "Quán cà phê"; 1 và 3 chỉ khớp "Quận" trong địa chỉ, giữ thứ tự gốc
    prov.setSearchQuery('quan');
    expect(prov.places.map((p) => p.id), [4, 1, 3]);

    // Chỉ khớp đầu từ trong địa chỉ: "uan" không khớp "Quận"/"Nhuận"
    prov.setSearchQuery('uan');
    expect(prov.places, isEmpty);
  });

  test('có vị trí người dùng: quán gần nhất lên đầu, kèm khoảng cách', () async {
    final prov = PlaceProvider(autoLoad: false);
    await prov.load();
    expect(prov.hasUserLocation, isFalse);
    expect(prov.distanceTo(prov.places.first), isNull);

    prov.setUserLocation(const LatLng(10.776, 106.703));
    expect(prov.hasUserLocation, isTrue);
    expect(prov.places.map((p) => p.id), [3, 1, 4, 2]);
    expect(prov.distanceTo(prov.places.first), lessThan(5));
    expect(prov.distanceTo(prov.places[1]), closeTo(550, 60));

    // Đang tìm: điểm khớp trước, bằng điểm thì gần hơn trước (3 gần hơn 1)
    prov.setSearchQuery('quan');
    expect(prov.places.map((p) => p.id), [4, 3, 1]);
  });

  test('đi vài chục mét không xếp lại danh sách, đi xa thì xếp lại', () async {
    final prov = PlaceProvider(autoLoad: false);
    await prov.load();
    prov.setUserLocation(const LatLng(10.776, 106.703));
    var notified = 0;
    prov.addListener(() => notified++);

    prov.setUserLocation(const LatLng(10.7765, 106.7030)); // ~55 m
    expect(notified, 0);
    expect(prov.places.first.id, 3);

    prov.setUserLocation(const LatLng(10.800, 106.681)); // tới gần quán 2
    expect(notified, 1);
    expect(prov.places.first.id, 2);
  });

  test('khớp nguyên từ trong tên xếp trên khớp đầu từ ("Phố Cổ" trên "Hoa Phong")', () {
    PlaceModel named(String name) => PlaceModel.fromJson({'id': 1, 'name': name, 'categories': const []});
    final whole = named('Café Phố Cổ').searchScore(['pho']);
    final prefix = named('Khách sạn Hoa Phong').searchScore(['pho']);
    final inside = named('Saphora').searchScore(['pho']);
    expect(whole, greaterThan(prefix));
    expect(prefix, greaterThan(inside));
    expect(inside, greaterThan(0));
  });

  test('lọc nhiều danh mục và xoá bộ lọc', () async {
    final prov = PlaceProvider(autoLoad: false);
    await prov.load();

    prov.toggleCategory(2);
    prov.toggleCategory(3);
    expect(prov.places.map((p) => p.id), [3, 4]);
    expect(prov.isFiltering, isTrue);

    prov.clearFilters();
    expect(prov.places, hasLength(4));
    expect(prov.isFiltering, isFalse);
  });

  test('bỏ chọn địa điểm trên bản đồ khi nó bị lọc mất', () async {
    final prov = PlaceProvider(autoLoad: false);
    await prov.load();
    prov.selectPlace(prov.places.first);
    prov.toggleCategory(2);
    expect(prov.selectedPlace, isNull);
  });

  test('API danh mục lỗi thì dựng danh mục từ danh sách địa điểm', () async {
    adapter.failCategories = true;
    final prov = PlaceProvider(autoLoad: false);
    await prov.load();
    expect(prov.categories.map((c) => c.slug), ['restaurant', 'hotel', 'cafe']);
  });

  test('lỗi mạng được báo là lỗi, không phải "không có kết quả"', () async {
    adapter.fail = true;
    final prov = PlaceProvider(autoLoad: false);
    await prov.load();
    expect(prov.hasLoaded, isFalse);
    expect(prov.error, contains('Không kết nối được máy chủ'));
  });
}
