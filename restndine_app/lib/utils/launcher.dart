import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/place_model.dart';

/// Mở ứng dụng ngoài (gọi điện, Google Maps, trình duyệt), báo lỗi bằng SnackBar.
class Launcher {
  Launcher._();

  static Future<void> call(BuildContext context, String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    return _open(context, Uri(scheme: 'tel', path: cleaned), 'Không mở được ứng dụng gọi điện.');
  }

  static Future<void> directions(BuildContext context, PlaceModel place) {
    final uri = place.hasValidLocation
        ? Uri.https('www.google.com', '/maps/dir/', {
            'api': '1',
            'destination': '${place.latitude},${place.longitude}',
          })
        : Uri.https('www.google.com', '/maps/search/', {
            'api': '1',
            'query': [place.name, place.address].whereType<String>().join(', '),
          });
    return _open(context, uri, 'Không mở được bản đồ chỉ đường.');
  }

  static Future<void> website(BuildContext context, String url) {
    final trimmed = url.trim();
    final uri = Uri.tryParse(trimmed.startsWith('http') ? trimmed : 'https://$trimmed');
    if (uri == null) return Future.value();
    return _open(context, uri, 'Không mở được website.');
  }

  static Future<void> copy(BuildContext context, String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Đã sao chép $label')));
  }

  static Future<void> _open(BuildContext context, Uri uri, String error) async {
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!opened) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
    }
  }
}
