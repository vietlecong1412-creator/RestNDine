import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

class AppConfig {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5229';
    }
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:5229';
      }
    } catch (_) {
      // Platform check not supported (e.g., on web or special environments)
    }
    return 'http://localhost:5229';
  }

  static String get apiBaseUrl => '$baseUrl/api';

  /// Backend lưu ảnh tải lên dưới dạng đường dẫn tương đối ("/images/places/abc.jpg");
  /// đổi thành URL đầy đủ để app tải được. Link ngoài (http...) giữ nguyên.
  static String? resolveUrl(String? url) {
    final u = url?.trim();
    if (u == null || u.isEmpty) return null;
    return u.startsWith('/') ? '$baseUrl$u' : u;
  }

  /// Ảnh do chính backend của app phục vụ (không phải link ngoài dễ hết hạn).
  static bool isOwnUrl(String url) => url.startsWith('$baseUrl/');
  static String get chatHubUrl => '$baseUrl/chatHub';

  static const String appName = 'RestNDine';
  static const String appTagline = 'Khám phá ẩm thực & điểm đến thông minh';
}
