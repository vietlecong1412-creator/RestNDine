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
  static String get chatHubUrl => '$baseUrl/chatHub';

  static const String appName = 'RestNDine';
  static const String appTagline = 'Khám phá ẩm thực & điểm đến thông minh';
}
