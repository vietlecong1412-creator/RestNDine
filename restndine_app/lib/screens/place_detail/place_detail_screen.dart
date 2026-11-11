import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../config/app_theme.dart';
import '../../models/place_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_exception.dart';
import '../../services/place_service.dart';
import '../../utils/formatters.dart';
import '../../utils/launcher.dart';
import '../../widgets/common.dart';
import '../auth/auth_flow.dart';
import '../chat/chat_screen.dart';
import '../map/directions.dart';
import 'widgets/ai_summary_card.dart';
import 'widgets/gallery.dart';
import 'widgets/review_widgets.dart';

class PlaceDetailScreen extends StatefulWidget {
  final int placeId;

  /// Dữ liệu sẵn có từ danh sách: hiện ngay ảnh, tên, địa chỉ trong lúc tải chi tiết.
  final PlaceModel? preview;

  const PlaceDetailScreen({super.key, required this.placeId, this.preview});

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  static const _expandedHeight = 300.0;
  static const _reviewsPreviewCount = 3;

  final PlaceService _placeService = PlaceService();
  final ScrollController _scroll = ScrollController();
  final GlobalKey _reviewsKey = GlobalKey();

  PlaceModel? _place;
  bool _isLoading = true;
  String? _error;
  bool _collapsed = false;
  bool _showAllReviews = false;

  final Map<int, int> _helpfulCounts = {};
  final Set<int> _votedComments = {};
  final Set<int> _votingComments = {};

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadPlace();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    final collapsed = _scroll.offset > _expandedHeight - kToolbarHeight - 12;
    if (collapsed != _collapsed) setState(() => _collapsed = collapsed);
  }

  Future<void> _loadPlace() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _placeService.getPlaceDetail(widget.placeId);
      if (!mounted) return;
      setState(() {
        _place = data;
        _isLoading = false;
        _helpfulCounts.clear(); // số liệu mới từ server đã gồm các lượt bình chọn
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.statusCode == 404 ? 'Địa điểm không tồn tại hoặc đã bị ẩn.' : e.message;
        _isLoading = false;
      });
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _scrollToReviews() {
    final ctx = _reviewsKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
    }
  }

  Future<void> _writeReview(PlaceModel p) async {
    if (!await ensureLoggedIn(context, message: 'Đăng nhập để chia sẻ đánh giá của bạn.')) return;
    if (!mounted) return;
    final posted = await showReviewComposer(context, place: p);
    if (posted == true && mounted) {
      _toast('Cảm ơn bạn đã chia sẻ đánh giá!');
      await _loadPlace();
    }
  }

  Future<void> _voteHelpful(PlaceCommentModel c) async {
    if (_votedComments.contains(c.id) || _votingComments.contains(c.id)) return;
    if (!await ensureLoggedIn(context, message: 'Đăng nhập để bình chọn đánh giá hữu ích.')) return;
    if (!mounted) return;

    setState(() => _votingComments.add(c.id));
    final result = await _placeService.voteCommentHelpful(c.id);
    if (!mounted) return;
    setState(() {
      _votingComments.remove(c.id);
      if (result.success) _helpfulCounts[c.id] = result.helpfulCount!;
      if (result.success || result.alreadyVoted) _votedComments.add(c.id);
    });
    if (!result.success && result.error != null) _toast(result.error!);
  }

  Future<void> _openChat(PlaceModel p) async {
    if (!await ensureLoggedIn(context, message: 'Đăng nhập để nhắn tin với chủ quán.')) return;
    if (!mounted) return;
    if (p.ownerId == context.read<AuthProvider>().user?.id) {
      _toast('Đây là địa điểm của bạn. Hãy trả lời khách trên trang web RestNDine.');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(placeId: p.id, placeName: p.name, receiverId: p.ownerId!, place: p),
      ),
    );
  }

  void _copyLink(PlaceModel p) =>
      Launcher.copy(context, '${AppConfig.baseUrl}/Place/Details/${p.id}', 'liên kết địa điểm');

  @override
  Widget build(BuildContext context) {
    final p = _place ?? widget.preview;
    if (p == null) {
      return _isLoading ? const _DetailSkeleton() : _DetailError(message: _error, onRetry: _loadPlace);
    }

    final colors = context.colors;
    final auth = context.watch<AuthProvider>();
    final isOwner = p.hasOwner && p.ownerId == auth.user?.id;
    final canChat = _place != null && p.hasOwner && !isOwner;

    return Scaffold(
      backgroundColor: colors.card,
      body: RefreshIndicator(
        onRefresh: _loadPlace,
        edgeOffset: kToolbarHeight + MediaQuery.paddingOf(context).top,
        child: CustomScrollView(
          controller: _scroll,
          slivers: [
            _buildAppBar(p),
            SliverToBoxAdapter(
              child: _Overview(
                place: p,
                detailsLoaded: _place != null,
                isOwner: isOwner,
                onReviewsTap: _scrollToReviews,
                onDirections: () => openDirections(context, p),
                onCall: p.hasPhone ? () => Launcher.call(context, p.phoneNumber!) : null,
                onWriteReview: () => _writeReview(p),
                onShare: () => _copyLink(p),
              ),
            ),
            SliverToBoxAdapter(child: _InfoSection(place: p)),
            if (p.amenities != null) SliverToBoxAdapter(child: _AmenitiesSection(place: p)),
            if (p.description != null)
              SliverToBoxAdapter(
                child: _Section(
                  title: 'Giới thiệu',
                  child: ExpandableText(p.description!, maxLines: 4),
                ),
              ),
            if (p.hasValidLocation)
              SliverToBoxAdapter(
                child: _Section(
                  title: 'Vị trí',
                  child: LocationPreview(place: p, onOpen: () => openDirections(context, p)),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: AiSummaryCard(
                  placeId: p.id,
                  initialSummaryCache: p.aiSummaryCache,
                  canRefresh: auth.user?.isAdmin == true || isOwner,
                ),
              ),
            ),
            SliverToBoxAdapter(
              key: _reviewsKey,
              child: _buildReviews(p),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
      bottomNavigationBar: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        child: canChat
            ? _ChatBar(
                onChat: () => _openChat(p),
                onCall: p.hasPhone ? () => Launcher.call(context, p.phoneNumber!) : null,
              )
            : const SizedBox(width: double.infinity),
      ),
    );
  }

  Widget _buildAppBar(PlaceModel p) {
    final colors = context.colors;
    final collapsedStyle = context.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;

    return SliverAppBar(
      pinned: true,
      stretch: true,
      expandedHeight: _expandedHeight,
      backgroundColor: colors.card,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: _collapsed ? collapsedStyle : SystemUiOverlayStyle.light,
      automaticallyImplyLeading: false,
      leadingWidth: 64,
      leading: Center(
        child: _CircleButton(
          icon: Icons.arrow_back_rounded,
          tooltip: 'Quay lại',
          solid: !_collapsed,
          onTap: () => Navigator.of(context).maybePop(),
        ),
      ),
      titleSpacing: 0,
      title: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: _collapsed ? 1 : 0,
        child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleMedium),
      ),
      actions: [
        _CircleButton(
          icon: Icons.share_outlined,
          tooltip: 'Sao chép liên kết',
          solid: !_collapsed,
          onTap: () => _copyLink(p),
        ),
        const SizedBox(width: 12),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        stretchModes: const [StretchMode.zoomBackground],
        background: HeaderGallery(place: p),
      ),
    );
  }

  Widget _buildReviews(PlaceModel p) {
    final detailed = _place;
    Widget body;

    if (detailed == null) {
      body = _error != null
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(child: ErrorBanner(message: _error!)),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Thử lại',
                    onPressed: _loadPlace,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            )
          : const Column(children: [ReviewSkeleton(), ReviewSkeleton()]);
    } else if (detailed.comments.isEmpty) {
      body = Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: context.colors.field,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        child: Column(
          children: [
            Icon(Icons.rate_review_outlined, size: 36, color: context.colors.textMuted),
            const SizedBox(height: 10),
            Text('Chưa có đánh giá nào', style: context.text.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Hãy là người đầu tiên chia sẻ trải nghiệm tại đây!',
              textAlign: TextAlign.center,
              style: context.text.bodySmall,
            ),
            const SizedBox(height: 14),
            FilledButton.tonalIcon(
              onPressed: () => _writeReview(detailed),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Viết đánh giá'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            ),
          ],
        ),
      );
    } else {
      final reviews = detailed.comments;
      final visible = _showAllReviews ? reviews : reviews.take(_reviewsPreviewCount).toList();
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RatingSummary(place: detailed),
          const SizedBox(height: 4),
          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0) const Divider(),
            ReviewTile(
              review: visible[i],
              helpfulCount: _helpfulCounts[visible[i].id] ?? visible[i].helpfulCount,
              voted: _votedComments.contains(visible[i].id),
              voting: _votingComments.contains(visible[i].id),
              onHelpful: () => _voteHelpful(visible[i]),
            ),
          ],
          if (reviews.length > _reviewsPreviewCount) ...[
            const SizedBox(height: 4),
            OutlinedButton(
              onPressed: () => setState(() => _showAllReviews = !_showAllReviews),
              child: Text(_showAllReviews ? 'Thu gọn' : 'Xem tất cả ${reviews.length} đánh giá'),
            ),
          ],
        ],
      );
    }

    return _Section(
      title: 'Đánh giá',
      trailing: TextButton.icon(
        onPressed: () => _writeReview(p),
        icon: const Icon(Icons.edit_outlined, size: 18),
        label: const Text('Viết đánh giá'),
      ),
      child: body,
    );
  }
}

/// Phần đầu: danh mục, tên, điểm, giá và các nút hành động nhanh.
class _Overview extends StatelessWidget {
  final PlaceModel place;
  final bool detailsLoaded;
  final bool isOwner;
  final VoidCallback onReviewsTap;
  final VoidCallback onDirections;
  final VoidCallback? onCall;
  final VoidCallback onWriteReview;
  final VoidCallback onShare;

  const _Overview({
    required this.place,
    required this.detailsLoaded,
    required this.isOwner,
    required this.onReviewsTap,
    required this.onDirections,
    required this.onCall,
    required this.onWriteReview,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hotelStars = place.type == PlaceType.hotel ? (place.starRating ?? 0) : 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (place.hasBanner) const SponsoredBadge(),
              if (isOwner)
                Pill(
                  label: 'Địa điểm của bạn',
                  icon: Icons.storefront_rounded,
                  color: colors.success,
                  background: colors.successContainer,
                ),
              for (final c in place.categories) Pill(label: '${c.icon ?? ''} ${c.name}'.trim()),
            ],
          ),
          const SizedBox(height: 12),
          Text(place.name, style: context.text.headlineSmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (!detailsLoaded)
                const SkeletonPulse(child: SkeletonBox(width: 130, height: 16))
              else if (place.reviewCount > 0)
                InkWell(
                  onTap: onReviewsTap,
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_rounded, color: colors.star, size: 20),
                      const SizedBox(width: 3),
                      Text(
                        formatRating(place.averageRating),
                        style: context.text.titleSmall!.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(${place.reviewCount} đánh giá)',
                        style: context.text.bodySmall!.copyWith(
                          decoration: TextDecoration.underline,
                          decorationColor: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Text('Chưa có đánh giá', style: context.text.bodySmall),
              if (hotelStars > 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RatingStars(rating: hotelStars.toDouble(), size: 15),
                    const SizedBox(width: 5),
                    Text('Khách sạn $hotelStars sao', style: context.text.bodySmall),
                  ],
                ),
              if (place.displayPrice != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.payments_outlined, size: 17, color: colors.success),
                    const SizedBox(width: 5),
                    Text(
                      place.displayPrice!,
                      style: context.text.labelMedium!.copyWith(color: colors.success, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _QuickAction(icon: Icons.directions_outlined, label: 'Chỉ đường', onTap: onDirections),
              _QuickAction(icon: Icons.call_outlined, label: 'Gọi điện', onTap: onCall),
              _QuickAction(icon: Icons.rate_review_outlined, label: 'Đánh giá', onTap: onWriteReview),
              _QuickAction(icon: Icons.share_outlined, label: 'Chia sẻ', onTap: onShare),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _QuickAction({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final enabled = onTap != null;
    return Expanded(
      child: Opacity(
        opacity: enabled ? 1 : 0.38,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: scheme.onPrimaryContainer),
                ),
                const SizedBox(height: 8),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Khối nội dung có tiêu đề, ngăn cách bằng đường kẻ mảnh.
class _Section extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Widget child;

  const _Section({required this.title, this.trailing, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(title, style: context.text.titleLarge!.copyWith(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              ?trailing,
            ],
          ),
          SizedBox(height: trailing == null ? 12 : 6),
          child,
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final PlaceModel place;

  const _InfoSection({required this.place});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      if (place.address != null)
        _InfoRow(
          icon: Icons.location_on_outlined,
          value: place.address!,
          label: 'Địa chỉ · giữ để sao chép',
          actionIcon: Icons.directions_outlined,
          onTap: () => openDirections(context, place),
          onLongPress: () => Launcher.copy(context, place.address!, 'địa chỉ'),
        ),
      if (place.hasPhone)
        _InfoRow(
          icon: Icons.call_outlined,
          value: place.phoneNumber!,
          label: 'Số điện thoại',
          actionIcon: Icons.phone_forwarded_outlined,
          onTap: () => Launcher.call(context, place.phoneNumber!),
          onLongPress: () => Launcher.copy(context, place.phoneNumber!, 'số điện thoại'),
        ),
      if (place.openingHours != null)
        _InfoRow(icon: Icons.schedule_rounded, value: place.openingHours!, label: 'Giờ mở cửa'),
      if (place.website != null)
        _InfoRow(
          icon: Icons.language_rounded,
          value: place.website!,
          label: 'Website',
          actionIcon: Icons.open_in_new_rounded,
          onTap: () => Launcher.website(context, place.website!),
        ),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return _Section(title: 'Thông tin', child: Column(children: rows));
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final IconData? actionIcon;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _InfoRow({
    required this.icon,
    required this.value,
    required this.label,
    this.actionIcon,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: colors.field, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 21, color: colors.textSecondary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: context.text.bodyMedium!.copyWith(fontWeight: FontWeight.w600, height: 1.4)),
                  const SizedBox(height: 1),
                  Text(label, style: context.text.bodySmall!.copyWith(color: colors.textMuted)),
                ],
              ),
            ),
            if (actionIcon != null) ...[
              const SizedBox(width: 8),
              Icon(actionIcon, size: 20, color: context.scheme.primary),
            ],
          ],
        ),
      ),
    );
  }
}

class _AmenitiesSection extends StatelessWidget {
  final PlaceModel place;

  const _AmenitiesSection({required this.place});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final items = place.amenityList;
    return _Section(
      title: place.type == PlaceType.hotel ? 'Tiện nghi' : 'Tiện ích',
      child: items.isEmpty
          ? ExpandableText(place.amenities!, maxLines: 4)
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in items)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: colors.field,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 16, color: colors.success),
                        const SizedBox(width: 6),
                        Flexible(child: Text(item, style: context.text.labelMedium)),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool solid;
  final VoidCallback onTap;

  const _CircleButton({required this.icon, required this.tooltip, required this.solid, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: solid ? colors.card.withValues(alpha: 0.94) : Colors.transparent,
        boxShadow: solid ? const [BoxShadow(color: Color(0x26000000), blurRadius: 10, offset: Offset(0, 2))] : null,
      ),
      child: IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        onPressed: onTap,
        icon: Icon(icon, size: 22, color: colors.textPrimary),
      ),
    );
  }
}

class _ChatBar extends StatelessWidget {
  final VoidCallback onChat;
  final VoidCallback? onCall;

  const _ChatBar({required this.onChat, this.onCall});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              if (onCall != null) ...[
                Tooltip(
                  message: 'Gọi điện',
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: onCall,
                      style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(52, 52)),
                      child: const Icon(Icons.call_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: FilledButton.icon(
                  onPressed: onChat,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                  label: const Text('Nhắn tin với chủ quán'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.card,
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: const SkeletonPulse(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(height: 300, radius: 0),
            Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 120, height: 22, radius: 99),
                  SizedBox(height: 14),
                  SkeletonBox(width: 260, height: 26),
                  SizedBox(height: 12),
                  SkeletonBox(width: 180, height: 14),
                  SizedBox(height: 24),
                  SkeletonBox(height: 70, radius: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailError extends StatelessWidget {
  final String? message;
  final VoidCallback onRetry;

  const _DetailError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: EmptyState(
        icon: Icons.wrong_location_outlined,
        title: 'Không tải được địa điểm',
        message: message,
        actionLabel: 'Thử lại',
        onAction: onRetry,
        tint: context.colors.danger,
      ),
    );
  }
}
