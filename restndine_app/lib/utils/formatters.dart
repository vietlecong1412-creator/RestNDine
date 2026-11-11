import 'dart:math' as math;

import 'package:flutter/widgets.dart';

String _two(int v) => v.toString().padLeft(2, '0');

/// Server lưu giờ theo UTC; chuỗi không ghi múi giờ cũng được coi là UTC.
DateTime? parseServerDate(Object? raw) {
  if (raw == null) return null;
  final s = raw.toString().trim();
  if (s.isEmpty) return null;
  final hasZone = RegExp(r'(Z|[+-]\d{2}:?\d{2})$', caseSensitive: false).hasMatch(s);
  return DateTime.tryParse(hasZone ? s : '${s}Z')?.toLocal();
}

/// API chat trả giờ Việt Nam (UTC+7) dạng "dd/MM/yyyy HH:mm".
DateTime? parseVietnamDateTime(String raw) {
  final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})\s+(\d{1,2}):(\d{2})').firstMatch(raw.trim());
  if (m == null) return null;
  final g = [for (var i = 1; i <= 5; i++) int.parse(m.group(i)!)];
  return DateTime.utc(g[2], g[1], g[0], g[3], g[4]).subtract(const Duration(hours: 7)).toLocal();
}

String formatDate(DateTime t) => '${_two(t.day)}/${_two(t.month)}/${t.year}';

String formatTime(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';

int _calendarDaysBetween(DateTime from, DateTime to) =>
    DateTime(to.year, to.month, to.day).difference(DateTime(from.year, from.month, from.day)).inDays;

/// "Vừa xong", "5 phút trước", "Hôm qua", "3 ngày trước"... quá 4 tuần thì ghi ngày.
String timeAgo(DateTime time, {DateTime? now}) {
  now ??= DateTime.now();
  final diff = now.difference(time);
  if (diff.inSeconds < 60) return 'Vừa xong';
  if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
  final days = _calendarDaysBetween(time, now);
  if (days == 0) return '${diff.inHours} giờ trước';
  if (days == 1) return 'Hôm qua';
  if (days < 7) return '$days ngày trước';
  if (days < 28) return '${days ~/ 7} tuần trước';
  return formatDate(time);
}

const _weekdays = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'];

/// Nhãn ngày cho dải phân cách trong khung chat.
String formatDayLabel(DateTime t, {DateTime? now}) {
  now ??= DateTime.now();
  final days = _calendarDaysBetween(t, now);
  if (days == 0) return 'Hôm nay';
  if (days == 1) return 'Hôm qua';
  if (days > 1 && days < 7) return '${_weekdays[t.weekday - 1]}, ${_two(t.day)}/${_two(t.month)}';
  return formatDate(t);
}

/// 4.666 → "4,7" (dấu phẩy thập phân kiểu Việt).
String formatRating(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

/// Không hiển thị nguyên email người khác: "minh.nguyen@gmail.com" → "minh.nguyen".
String displayNameFromEmail(String email) {
  final at = email.indexOf('@');
  return at > 0 ? email.substring(0, at) : email;
}

/// Chữ cái đại diện cho avatar.
String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'[\s._\-]+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  final first = parts.first.characters.first;
  if (parts.length == 1) return first.toUpperCase();
  return (first + parts[1].characters.first).toUpperCase();
}

const _viGroups = {
  'a': 'àáảãạăằắẳẵặâầấẩẫậ',
  'd': 'đ',
  'e': 'èéẻẽẹêềếểễệ',
  'i': 'ìíỉĩị',
  'o': 'òóỏõọôồốổỗộơờớởỡợ',
  'u': 'ùúủũụưừứửữự',
  'y': 'ỳýỷỹỵ',
};

final Map<int, int> _foldMap = {
  for (final e in _viGroups.entries)
    for (final r in e.value.runes) r: e.key.codeUnitAt(0),
};

/// Chữ thường, bỏ dấu tiếng Việt: "Phở Hà Nội" → "pho ha noi".
/// Giúp tìm kiếm khớp cả khi người dùng gõ không dấu.
String foldVietnamese(String input) {
  final out = StringBuffer();
  for (final r in input.toLowerCase().runes) {
    if (r >= 0x0300 && r <= 0x036F) continue; // dấu kết hợp (chuỗi dạng NFD)
    out.writeCharCode(_foldMap[r] ?? r);
  }
  return out.toString();
}

/// [token] xuất hiện ở đầu một từ trong [text] (cả hai đã qua [foldVietnamese]).
/// "pho" khớp "pho bo" nhưng không khớp "sophia"; tránh các âm tiết ngắn khớp lung tung.
bool containsWordPrefix(String text, String token) => _wordMatch(text, token, whole: false);

/// [token] là nguyên một từ trong [text]: "pho" khớp "pho co" nhưng không khớp "phong".
bool containsWholeWord(String text, String token) => _wordMatch(text, token, whole: true);

bool _wordMatch(String text, String token, {required bool whole}) {
  var i = text.indexOf(token);
  while (i >= 0) {
    final end = i + token.length;
    if ((i == 0 || !_isWordChar(text.codeUnitAt(i - 1))) &&
        (!whole || end == text.length || !_isWordChar(text.codeUnitAt(end)))) {
      return true;
    }
    i = text.indexOf(token, i + 1);
  }
  return false;
}

bool _isWordChar(int c) =>
    (c >= 0x61 && c <= 0x7A) || (c >= 0x30 && c <= 0x39) || c > 0x7F; // a-z, 0-9, chữ ngoài ASCII

/// Khoảng cách đường chim bay (mét) giữa hai toạ độ, công thức haversine.
double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  const earthRadius = 6371000.0;
  double rad(double deg) => deg * math.pi / 180;
  final dLat = rad(lat2 - lat1), dLng = rad(lng2 - lng1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * earthRadius * math.asin(math.sqrt(a));
}

/// "350 m", "1,2 km", "15 km" — làm tròn vừa đủ, dấu phẩy thập phân kiểu Việt Nam.
String formatDistance(double meters) {
  if (meters < 1000) return '${(meters / 10).round() * 10} m';
  final km = meters / 1000;
  if (km < 10) return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
  return '${km.round()} km';
}

/// "Dưới 1 phút", "12 phút", "1 giờ 5 phút".
String formatDuration(double seconds) {
  final minutes = (seconds / 60).round();
  if (minutes < 1) return 'Dưới 1 phút';
  if (minutes < 60) return '$minutes phút';
  final h = minutes ~/ 60, m = minutes % 60;
  return m == 0 ? '$h giờ' : '$h giờ $m phút';
}
