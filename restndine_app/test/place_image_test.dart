import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restndine_app/config/app_theme.dart';
import 'package:restndine_app/models/place_model.dart';
import 'package:restndine_app/widgets/place_image.dart';

PlaceModel _place(int id, String slug, {String? imageUrl}) => PlaceModel.fromJson({
      'id': id,
      'name': 'Quán $id',
      'latitude': 10.77,
      'longitude': 106.70,
      'imageUrl': imageUrl,
      'categories': [
        {'id': 1, 'name': slug, 'slug': slug, 'icon': ''},
      ],
    });

Future<void> _pump(WidgetTester tester, PlaceModel place) => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Center(child: SizedBox(width: 200, height: 100, child: PlaceImage(place: place))),
      ),
    );

/// Ảnh minh hoạ đang hiện (đường dẫn asset), hoặc null nếu không có.
String? _shownAsset(WidgetTester tester) {
  for (final image in tester.widgetList<Image>(find.byType(Image))) {
    final provider = image.image;
    if (provider is AssetImage) return provider.assetName;
  }
  return null;
}

void main() {
  setUp(PlaceImage.debugResetFailures);

  test('mỗi loại địa điểm có đủ ảnh minh hoạ trong app, giống hệt ảnh backend dùng cho web', () {
    for (final type in PlaceType.values) {
      for (var i = 1; i <= PlaceModel.fallbackVariants; i++) {
        final asset = File(PlaceModel.fallbackAssetFor(type, i));
        final web = File('../wwwroot/images/fallback/${type.name}-$i.jpg');
        expect(asset.existsSync(), isTrue, reason: 'thiếu ${asset.path}');
        expect(asset.readAsBytesSync(), web.readAsBytesSync(), reason: '${asset.path} khác ${web.path}');
      }
    }
  });

  test('chọn ảnh minh hoạ theo loại và id, cùng quy tắc với PlaceFallbackImage.cs', () {
    expect(_place(8, 'restaurant').fallbackAsset, 'assets/fallback/restaurant-1.jpg');
    expect(_place(9, 'cafe').fallbackAsset, 'assets/fallback/cafe-2.jpg');
    expect(_place(11, 'hotel').fallbackAsset, 'assets/fallback/hotel-4.jpg');
  });

  test('link lỗi không được thử lại ngay, link khác không bị ảnh hưởng', () {
    const dead = 'https://lh3.googleusercontent.com/gps-cs-s/het-han=w800-h500-k-no';
    expect(PlaceImage.isWorthTrying(null), isFalse);
    expect(PlaceImage.isWorthTrying('  '), isFalse);
    expect(PlaceImage.isWorthTrying(dead), isTrue);

    PlaceImage.markFailed(dead);
    expect(PlaceImage.isWorthTrying(dead), isFalse);
    expect(PlaceImage.isWorthTrying('https://example.com/khac.jpg'), isTrue);
  });

  testWidgets('địa điểm không có ảnh: hiện ảnh minh hoạ, không gọi mạng', (tester) async {
    final place = _place(9, 'cafe');
    await _pump(tester, place);

    expect(_shownAsset(tester), place.fallbackAsset);
    expect(find.byType(CachedNetworkImage), findsNothing);
  });

  testWidgets('link ảnh đã lỗi: hiện thẳng ảnh minh hoạ, không gọi mạng lần nữa', (tester) async {
    const dead = 'https://lh3.googleusercontent.com/gps-cs-s/het-han=w800-h500-k-no';
    final place = _place(11, 'hotel', imageUrl: dead);
    PlaceImage.markFailed(dead);
    await _pump(tester, place);

    expect(_shownAsset(tester), place.fallbackAsset);
    expect(find.byType(CachedNetworkImage), findsNothing);
  });
}
