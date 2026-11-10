import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../models/place_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/place_provider.dart';
import '../../widgets/common.dart';
import '../shell/main_shell.dart';
import 'widgets/place_card.dart';
import 'widgets/search_filter_bar.dart';

/// Tab "Khám phá": lời chào, tìm kiếm ghim trên đầu, dải nổi bật và danh sách địa điểm.
class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  Future<void> _refresh(BuildContext context) async {
    final prov = context.read<PlaceProvider>();
    await prov.load();
    if (!context.mounted || prov.error == null || !prov.hasLoaded) return;
    // Đã có dữ liệu cũ: giữ nguyên danh sách, chỉ báo lỗi làm mới
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(prov.error!)));
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<PlaceProvider>();
    final scaler = MediaQuery.textScalerOf(context);
    // Ô tìm kiếm cao theo cỡ chữ hệ thống; cộng dư để không bao giờ tràn
    final headerExtent = 8 + (30 + scaler.scale(15) * 1.5) + 12 + 38 + 14;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: context.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () => _refresh(context),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                const SliverToBoxAdapter(child: _Greeting()),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _PinnedSearchHeader(
                    extent: headerExtent,
                    background: context.colors.canvas,
                    divider: context.colors.border,
                  ),
                ),
                ..._content(context, prov),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, PlaceProvider prov) {
    if (!prov.hasLoaded) {
      if (prov.error != null && !prov.isLoading) {
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Không tải được dữ liệu',
              message: prov.error,
              actionLabel: 'Thử lại',
              onAction: prov.load,
              tint: context.colors.danger,
            ),
          ),
        ];
      }
      return [
        const SliverToBoxAdapter(child: _SlowLoadingHint()),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          sliver: SliverList.separated(
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (_, __) => const SkeletonPulse(child: PlaceCardSkeleton()),
          ),
        ),
      ];
    }

    if (prov.totalCount == 0) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.storefront_outlined,
            title: 'Chưa có địa điểm nào',
            message: 'Các quán và khách sạn sẽ xuất hiện ở đây khi được duyệt.',
          ),
        ),
      ];
    }

    final showFeatured = !prov.isFiltering && prov.featuredPlaces.isNotEmpty;
    final List<PlaceModel> list =
        showFeatured ? prov.places.where((p) => !p.hasBanner).toList() : prov.places;

    return [
      if (showFeatured) ...[
        const SliverToBoxAdapter(
          child: SectionHeader(title: 'Nổi bật', subtitle: 'Địa điểm được đề xuất cho bạn'),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: prov.featuredPlaces.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => FeaturedPlaceCard(place: prov.featuredPlaces[i]),
            ),
          ),
        ),
      ],
      if (prov.isFiltering || list.isNotEmpty)
        SliverToBoxAdapter(
          child: SectionHeader(
            title: prov.isFiltering ? 'Kết quả tìm kiếm' : 'Tất cả địa điểm',
            subtitle: '${list.length} địa điểm',
            // Không có kết quả thì nút "Xóa bộ lọc" đã nằm trong trạng thái rỗng bên dưới
            trailing: prov.isFiltering && list.isNotEmpty
                ? TextButton.icon(
                    onPressed: prov.clearFilters,
                    icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                    label: const Text('Xóa bộ lọc'),
                  )
                : null,
          ),
        ),
      if (prov.isFiltering && list.isEmpty)
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.search_off_rounded,
            title: 'Không tìm thấy địa điểm phù hợp',
            message: 'Thử từ khoá khác hoặc bỏ bớt bộ lọc nhé.',
            actionLabel: 'Xóa bộ lọc',
            actionIcon: Icons.filter_alt_off_outlined,
            onAction: prov.clearFilters,
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
          sliver: SliverList.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (_, i) => PlaceCard(place: list[i]),
          ),
        ),
    ];
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting();

  static String _greet(int hour) {
    if (hour < 11) return 'Chào buổi sáng';
    if (hour < 14) return 'Chào buổi trưa';
    if (hour < 18) return 'Chào buổi chiều';
    return 'Chào buổi tối';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final greet = _greet(DateTime.now().hour);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user != null ? '$greet, ${user.displayName}' : greet,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyMedium!.copyWith(
                    color: context.colors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text('Hôm nay ăn gì, ở đâu?', style: context.text.headlineSmall),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Tooltip(
            message: 'Tài khoản',
            child: InkResponse(
              onTap: () => context.read<ShellController>().go(ShellController.account),
              radius: 28,
              child: user != null
                  ? UserAvatar(name: user.displayName, size: 46)
                  : Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: context.colors.card,
                        shape: BoxShape.circle,
                        border: Border.all(color: context.colors.border),
                      ),
                      child: Icon(Icons.person_outline_rounded, color: context.colors.textSecondary),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PinnedSearchHeader extends SliverPersistentHeaderDelegate {
  final double extent;
  final Color background;
  final Color divider;

  _PinnedSearchHeader({required this.extent, required this.background, required this.divider});

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        border: Border(
          bottom: BorderSide(color: overlapsContent ? divider : Colors.transparent),
        ),
      ),
      child: const ClipRect(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: PlaceSearchField(),
            ),
            SizedBox(height: 12),
            CategoryChips(),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_PinnedSearchHeader old) =>
      old.extent != extent || old.background != background || old.divider != divider;
}

/// Máy chủ miễn phí có thể "ngủ"; lần tải đầu lâu thì giải thích cho người dùng yên tâm chờ.
class _SlowLoadingHint extends StatefulWidget {
  const _SlowLoadingHint();

  @override
  State<_SlowLoadingHint> createState() => _SlowLoadingHintState();
}

class _SlowLoadingHintState extends State<_SlowLoadingHint> {
  Timer? _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      child: !_visible
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.colors.warningContainer,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                ),
                child: Row(
                  children: [
                    Icon(Icons.hourglass_top_rounded, size: 20, color: context.colors.warning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Máy chủ đang khởi động, lần tải đầu có thể mất khoảng một phút…',
                        style: context.text.bodySmall!.copyWith(color: context.colors.warning),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
