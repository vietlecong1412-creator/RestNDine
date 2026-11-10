import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restndine_app/providers/place_provider.dart';
import 'package:restndine_app/services/api_service.dart';

const _categories = [
  {'id': 1, 'name': 'Nhà hàng', 'slug': 'restaurant', 'icon': ''},
  {'id': 2, 'name': 'Khách sạn', 'slug': 'hotel', 'icon': ''},
  {'id': 3, 'name': 'Quán cà phê', 'slug': 'cafe', 'icon': ''},
];

Map<String, dynamic> _place(int id, String name, int cat, {bool sponsored = false, String? address}) => {
      'id': id,
      'name': name,
      'address': address,
      'latitude': 10.78,
      'longitude': 106.70,
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
            _place(1, 'Phở Hòa Pasteur', 1, sponsored: true, address: 'Quận 3'),
            _place(2, 'Cơm Tấm Ba Ghiền', 1, address: 'Phú Nhuận'),
            _place(3, 'Khách sạn Rex', 2, address: 'Quận 1'),
            _place(4, 'Cộng Cà Phê', 3, address: 'Quận 1'),
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

    prov.setSearchQuery('quan 1');
    expect(prov.places.map((p) => p.id), [3, 4]);

    prov.setSearchQuery('ca phe');
    expect(prov.places.map((p) => p.id), [4]);
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
