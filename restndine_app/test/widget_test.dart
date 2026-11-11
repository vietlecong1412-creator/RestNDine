import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restndine_app/config/map_tiles.dart';
import 'package:restndine_app/main.dart';
import 'package:restndine_app/services/api_service.dart';

/// Trả danh sách rỗng cho mọi API để test không gọi mạng thật.
class _EmptyApi implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async =>
      ResponseBody.fromString(jsonEncode([]), 200, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });

  @override
  void close({bool force = false}) {}
}

/// Ô bản đồ trong suốt 1×1 px để test không tải tile thật.
class _BlankTiles extends TileProvider {
  static final _png = MemoryImage(base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII='));

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) => _png;
}

void main() {
  testWidgets('App mở vào bản đồ, có thanh điều hướng 3 tab', (WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    ApiService().dio.httpClientAdapter = _EmptyApi();
    MapTiles.debugTileProvider = _BlankTiles();

    await tester.pumpWidget(const RestNDineApp());
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.text('Bản đồ'), findsOneWidget);
    expect(find.text('Khám phá'), findsOneWidget);
    expect(find.text('Tài khoản'), findsWidgets);

    await tester.tap(find.text('Khám phá'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Chưa có địa điểm nào'), findsOneWidget);
  });
}
