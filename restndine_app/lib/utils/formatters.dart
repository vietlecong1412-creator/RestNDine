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
