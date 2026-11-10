import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../config/app_theme.dart';
import '../../../models/ai_summary_model.dart';
import '../../../services/place_service.dart';
import '../../../utils/formatters.dart';
import '../../../widgets/common.dart';

class AiSummaryCard extends StatefulWidget {
  final int placeId;
  final String? initialSummaryCache;

  /// Chỉ chủ địa điểm và Admin được yêu cầu phân tích lại.
  final bool canRefresh;

  const AiSummaryCard({
    super.key,
    required this.placeId,
    this.initialSummaryCache,
    this.canRefresh = false,
  });

  @override
  State<AiSummaryCard> createState() => _AiSummaryCardState();
}

class _AiSummaryCardState extends State<AiSummaryCard> {
  static const _collapsedHeight = 168.0;

  final PlaceService _placeService = PlaceService();
  AiSummaryModel? _summaryData;
  bool _isLoading = false;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _fetchSummary(forceRefresh: false);
  }

  Future<void> _fetchSummary({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    final data = await _placeService.getAiSummary(widget.placeId, forceRefresh: forceRefresh);
    if (mounted) {
      setState(() {
        _summaryData = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.aiContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: colors.ai.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 14, widget.canRefresh ? 4 : 16, 0),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF7C3AED), Color(0xFFDB2777)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tóm tắt từ AI', style: context.text.titleMedium),
                      Text('Phân tích cảm xúc từ đánh giá của khách', style: context.text.bodySmall),
                    ],
                  ),
                ),
                if (widget.canRefresh)
                  IconButton(
                    tooltip: 'Phân tích lại',
                    icon: Icon(Icons.refresh_rounded, color: colors.ai),
                    onPressed: _isLoading ? null : () => _fetchSummary(forceRefresh: true),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _isLoading ? _buildLoadingState() : _buildContent(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final data = _summaryData;
    final summary = (data != null && data.summary.trim().isNotEmpty)
        ? data.summary
        : widget.initialSummaryCache?.trim() ?? '';

    if (summary.isEmpty) {
      return Text(
        widget.canRefresh
            ? 'Chưa có bản tóm tắt. Nhấn nút làm mới để AI phân tích đánh giá của khách.'
            : 'Chưa đủ đánh giá để AI tóm tắt. Hãy là người đầu tiên chia sẻ trải nghiệm!',
        style: context.text.bodyMedium!.copyWith(color: context.colors.textSecondary),
      );
    }

    final stats = data?.sentimentStats;
    final long = summary.length > 380;

    return Column(
      key: const ValueKey('content'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (stats != null && stats.total > 0) ...[
          _buildSentimentBreakdown(context, stats),
          const SizedBox(height: 16),
        ],
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          alignment: Alignment.topCenter,
          child: !long || _expanded
              ? _markdown(context, summary)
              : ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.6, 1],
                    colors: [Colors.black, Colors.transparent],
                  ).createShader(rect),
                  blendMode: BlendMode.dstIn,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: _collapsedHeight),
                    child: ClipRect(
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: _markdown(context, summary),
                      ),
                    ),
                  ),
                ),
        ),
        if (long)
          TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            style: TextButton.styleFrom(
              foregroundColor: context.colors.ai,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 36),
            ),
            child: Text(_expanded ? 'Thu gọn' : 'Xem toàn bộ tóm tắt'),
          ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(Icons.memory_rounded, size: 14, color: context.colors.textMuted),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                _footerText(data),
                style: context.text.bodySmall!.copyWith(color: context.colors.textMuted, fontSize: 11.5),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _footerText(AiSummaryModel? data) {
    final updated = data?.updatedAt;
    if (data != null && !data.isCached) return 'Phân tích bởi PhoBERT · vừa cập nhật';
    if (updated != null) return 'Phân tích bởi PhoBERT · cập nhật ${timeAgo(updated).toLowerCase()}';
    return 'Phân tích bởi PhoBERT';
  }

  Widget _markdown(BuildContext context, String data) {
    final text = context.text;
    final colors = context.colors;
    final body = text.bodyMedium!.copyWith(height: 1.55, color: colors.textPrimary);
    return MarkdownBody(
      data: data,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: body,
        listBullet: body,
        strong: body.copyWith(fontWeight: FontWeight.w700),
        h1: text.titleMedium,
        h2: text.titleMedium,
        h3: text.titleSmall!.copyWith(fontSize: 15),
        h3Padding: const EdgeInsets.only(top: 6),
        blockSpacing: 10,
      ),
    );
  }

  Widget _buildSentimentBreakdown(BuildContext context, SentimentStats stats) {
    final colors = context.colors;
    final segments = [
      (stats.positive, stats.positivePercentage, colors.success, 'Tích cực'),
      (stats.neutral, stats.neutralPercentage, colors.star, 'Trung tính'),
      (stats.negative, stats.negativePercentage, colors.danger, 'Tiêu cực'),
    ];

    final visible = [for (final s in segments) if (s.$1 > 0) s];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: SizedBox(
            height: 10,
            child: Row(
              // stretch: các đoạn màu không có con nên phải được kéo đủ chiều cao 10px
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < visible.length; i++) ...[
                  if (i > 0) const SizedBox(width: 3),
                  Expanded(flex: visible[i].$1, child: ColoredBox(color: visible[i].$3)),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            for (final (_, pct, color, label) in segments)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(
                    '$label ${pct.toStringAsFixed(0)}%',
                    style: context.text.labelMedium!.copyWith(color: colors.textSecondary),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return const SkeletonPulse(
      key: ValueKey('loading'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(height: 10, radius: 99),
          SizedBox(height: 16),
          SkeletonBox(height: 12),
          SizedBox(height: 8),
          SkeletonBox(height: 12),
          SizedBox(height: 8),
          SkeletonBox(width: 180, height: 12),
        ],
      ),
    );
  }
}
