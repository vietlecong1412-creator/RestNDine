import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../models/place_model.dart';
import '../../providers/location_provider.dart';
import '../../providers/place_provider.dart';
import '../../providers/route_provider.dart';
import '../../services/route_service.dart';
import '../../utils/formatters.dart';
import '../../utils/launcher.dart';
import '../../widgets/location_widgets.dart';
import '../shell/main_shell.dart';

/// Nút "Chỉ đường" ở mọi nơi: tìm đường từ vị trí hiện tại và vẽ ngay trên tab Bản đồ của app.
/// Địa điểm thiếu toạ độ thì không tìm đường được, để Google Maps tìm theo tên.
Future<void> openDirections(BuildContext context, PlaceModel place) async {
  if (!place.hasValidLocation) return Launcher.directions(context, place);

  // Lấy sẵn các provider: sau khi chờ định vị, màn hình gọi hàm này có thể đã bị đóng
  final route = context.read<RouteProvider>();
  final places = context.read<PlaceProvider>();
  final shell = context.read<ShellController>();
  final navigator = Navigator.of(context);

  final from = context.read<LocationProvider>().position ?? await locateWithFeedback(context);
  if (from == null) return; // đã báo lý do cho người dùng

  places.selectPlace(null);
  route.start(place, from);
  navigator.popUntil((r) => r.isFirst);
  shell.go(ShellController.map);
}

/// Đường đi trên bản đồ (đặt trong `FlutterMap.children`, dưới lớp ghim): nét liền khi đi xe,
/// chấm chấm khi đi bộ, giống quy ước của các ứng dụng bản đồ.
class RouteLine extends StatelessWidget {
  const RouteLine({super.key});

  static const color = Color(0xFF1A73E8);

  @override
  Widget build(BuildContext context) {
    final result = context.select<RouteProvider, RouteResult?>((r) => r.active ? r.result : null);
    if (result == null) return const SizedBox.shrink();
    final walking = result.mode == TravelMode.walk;
    return PolylineLayer(
      polylines: [
        Polyline(
          points: result.points,
          strokeWidth: walking ? 7 : 6,
          color: color,
          borderStrokeWidth: walking ? 0 : 2,
          borderColor: Colors.white,
          pattern: walking ? const StrokePattern.dotted(spacingFactor: 1.8) : const StrokePattern.solid(),
        ),
      ],
    );
  }
}

/// Bảng chỉ đường ở đáy bản đồ: đích đến, chọn cách đi, khoảng cách/thời gian, các bước,
/// và nút mở Google Maps cho ai cần dẫn đường bằng giọng nói.
class RoutePanel extends StatelessWidget {
  const RoutePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final route = context.watch<RouteProvider>();
    final target = route.target;
    if (target == null) return const SizedBox.shrink();
    final colors = context.colors;
    final result = route.result;

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: colors.shadow, blurRadius: 24, offset: const Offset(0, 8))],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 6, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.directions_rounded, color: RouteLine.color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Đường tới', style: context.text.bodySmall),
                    Text(target.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleMedium),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Tắt chỉ đường',
                onPressed: route.clear,
                icon: Icon(Icons.close_rounded, color: colors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: SegmentedButton<TravelMode>(
              showSelectedIcon: false,
              segments: [
                for (final m in TravelMode.values)
                  ButtonSegment(value: m, icon: Icon(m.icon, size: 20), label: Text(m.label)),
              ],
              selected: {route.mode},
              onSelectionChanged: (s) => route.setMode(s.first),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: _summary(context, route, result),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: result == null ? null : () => _showSteps(context, result),
                    icon: const Icon(Icons.format_list_numbered_rounded, size: 20),
                    label: Text(result == null ? 'Các bước' : 'Các bước (${result.steps.length})'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.tonalIcon(
                    // Dẫn đường bằng giọng nói, tự đổi tuyến theo giao thông: để Google Maps làm
                    onPressed: () => Launcher.directions(context, target),
                    icon: const Icon(Icons.navigation_rounded, size: 20),
                    label: const Text('Google Maps'),
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary(BuildContext context, RouteProvider route, RouteResult? result) {
    final colors = context.colors;
    if (route.loading && result == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(minHeight: 3, borderRadius: BorderRadius.circular(3)),
          const SizedBox(height: 8),
          Text('Đang tìm đường…', style: context.text.bodyMedium!.copyWith(color: colors.textSecondary)),
        ],
      );
    }
    if (route.error != null && result == null) {
      return Row(
        children: [
          Icon(Icons.error_outline_rounded, color: colors.danger, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(route.error!, style: context.text.bodyMedium)),
          TextButton(onPressed: route.retry, child: const Text('Thử lại')),
        ],
      );
    }
    if (result == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(children: [
            TextSpan(
              text: formatDuration(result.duration),
              style: context.text.titleLarge!.copyWith(color: colors.success, fontWeight: FontWeight.w800),
            ),
            TextSpan(text: '  ·  ${formatDistance(result.distance)}', style: context.text.titleMedium),
          ]),
        ),
        const SizedBox(height: 2),
        Text(
          route.loading
              ? 'Đang cập nhật tuyến đường…'
              : result.mode == TravelMode.drive
                  ? 'Thời gian ước tính, chưa tính kẹt xe'
                  : 'Thời gian đi bộ ước tính',
          style: context.text.bodySmall!.copyWith(color: colors.textMuted),
        ),
      ],
    );
  }

  void _showSteps(BuildContext context, RouteResult result) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  '${result.mode.label} · ${formatDistance(result.distance)} · ${formatDuration(result.duration)}',
                  style: sheetContext.text.titleMedium,
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: result.steps.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 64),
                  itemBuilder: (_, i) {
                    final s = result.steps[i];
                    return ListTile(
                      leading: Icon(s.icon, color: RouteLine.color),
                      title: Text(s.instruction),
                      trailing: s.distance >= 1
                          ? Text(formatDistance(s.distance), style: sheetContext.text.bodySmall)
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
