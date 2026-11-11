import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/location_provider.dart';
import '../utils/formatters.dart';
import 'common.dart';

/// Lấy vị trí khi người dùng bấm nút; không được thì báo lý do kèm nút mở đúng trang Cài đặt.
/// Trả về null nếu không lấy được (đã báo cho người dùng).
Future<LatLng?> locateWithFeedback(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    return await context.read<LocationProvider>().locate();
  } on LocationIssue catch (issue) {
    final (message, action) = switch (issue) {
      LocationIssue.serviceDisabled => ('Định vị của máy đang tắt. Bật lên để xem các quán quanh bạn.', 'Bật định vị'),
      LocationIssue.denied => ('Cần quyền vị trí để tìm các quán gần bạn.', null),
      LocationIssue.deniedForever => ('Bạn đã chặn quyền vị trí của RestNDine. Mở Cài đặt để cho phép lại.', 'Cài đặt'),
      LocationIssue.unavailable => ('Chưa xác định được vị trí. Hãy thử lại sau ít phút.', null),
    };
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        action: action == null
            ? null
            : SnackBarAction(label: action, onPressed: () => LocationProvider.openSettingsFor(issue)),
      ));
    return null;
  }
}

/// Lời mời bật vị trí ở tab Khám phá khi chưa biết người dùng đang ở đâu: app gợi ý quán
/// gần nhất nên đây là việc nên làm đầu tiên.
class NearbyPrompt extends StatelessWidget {
  const NearbyPrompt({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final locating = context.select<LocationProvider, bool>((l) => l.locating);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: context.scheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Row(
        children: [
          Icon(Icons.near_me_rounded, color: context.scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Xem quán gần bạn', style: context.text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  'Bật vị trí để xếp các quán gần bạn nhất lên đầu.',
                  style: context.text.bodySmall!.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: locating ? null : () => locateWithFeedback(context),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            child: locating
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2))
                : const Text('Bật vị trí'),
          ),
        ],
      ),
    );
  }
}

/// Nhãn "cách bạn bao xa" đặt trên ảnh của thẻ địa điểm.
class DistanceBadge extends StatelessWidget {
  final double meters;

  const DistanceBadge({super.key, required this.meters});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cách bạn ${formatDistance(meters)}',
      excludeSemantics: true,
      child: Pill(
        label: formatDistance(meters),
        icon: Icons.near_me_rounded,
        color: Colors.white,
        background: const Color(0xB3000000),
      ),
    );
  }
}
