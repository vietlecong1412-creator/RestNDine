import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

/// Nguồn bản đồ nền (Esri World Street Map) dùng chung cho mọi bản đồ trong app.
class MapTiles {
  MapTiles._();

  static const urlTemplate =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}';
  static const userAgent = 'com.restndine.restndine_app';

  /// Test gán nguồn tile cục bộ để không gọi mạng; null = tải từ Esri như bình thường.
  static TileProvider? debugTileProvider;

  static TileLayer layer() => TileLayer(
        urlTemplate: urlTemplate,
        userAgentPackageName: userAgent,
        maxNativeZoom: 19,
        tileProvider: debugTileProvider,
      );

  /// Ghi công nguồn bản đồ theo điều khoản của Esri, nhỏ gọn ở góc dưới trái.
  static const Widget attribution = Align(
    alignment: Alignment.bottomLeft,
    child: Padding(
      padding: EdgeInsets.all(6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color(0xD9FFFFFF),
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Text(
            '© Esri',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: Color(0xFF5F6368)),
          ),
        ),
      ),
    ),
  );
}
