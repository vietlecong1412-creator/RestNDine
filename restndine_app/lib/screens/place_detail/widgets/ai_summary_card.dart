import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../config/app_theme.dart';
import '../../../models/ai_summary_model.dart';
import '../../../services/place_service.dart';

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
  final PlaceService _placeService = PlaceService();
  AiSummaryModel? _summaryData;
  bool _isLoading = false;

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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.purple.shade50.withOpacity(0.6),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade600,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RestNDine AI Insights',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4A148C),
                        ),
                      ),
                      Text(
                        'Tóm tắt & phân tích cảm xúc từ PhoBERT',
                        style: TextStyle(fontSize: 11, color: Colors.purple),
                      ),
                    ],
                  ),
                ),
                if (widget.canRefresh)
                  IconButton(
                    tooltip: 'Cập nhật phân tích mới',
                    icon: const Icon(Icons.refresh, size: 20, color: Colors.purple),
                    onPressed: _isLoading ? null : () => _fetchSummary(forceRefresh: true),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: _isLoading
                ? _buildLoadingState()
                : _summaryData == null || _summaryData!.summary.isEmpty
                    ? Text(
                        widget.initialSummaryCache ??
                            'Chưa có dữ liệu phân tích. Hãy nhấn nút làm mới để kích hoạt AI.',
                        style: const TextStyle(fontSize: 13, height: 1.5),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Sentiment Bar Chart
                          if (_summaryData!.sentimentStats != null &&
                              _summaryData!.sentimentStats!.total > 0)
                            _buildSentimentBreakdown(_summaryData!.sentimentStats!),

                          const SizedBox(height: 14),

                          // Markdown Content
                          MarkdownBody(
                            data: _summaryData!.summary,
                            styleSheet: MarkdownStyleSheet(
                              p: const TextStyle(fontSize: 13.5, height: 1.5),
                              h3: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Icon(
                                _summaryData!.isCached ? Icons.cached : Icons.flash_on,
                                size: 13,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _summaryData!.isCached
                                    ? 'Dữ liệu bộ nhớ đệm AI (Cache)'
                                    : 'Phân tích trực tiếp từ PhoBERT',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSentimentBreakdown(SentimentStats stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Tỷ lệ phản hồi người dùng:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            Text(
              '${stats.total} đánh giá',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                if (stats.positivePercentage > 0)
                  Expanded(
                    flex: stats.positive,
                    child: Container(color: const Color(0xFF4CAF50)),
                  ),
                if (stats.neutralPercentage > 0)
                  Expanded(
                    flex: stats.neutral,
                    child: Container(color: const Color(0xFFFFB703)),
                  ),
                if (stats.negativePercentage > 0)
                  Expanded(
                    flex: stats.negative,
                    child: Container(color: const Color(0xFFE53935)),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _legendItem(const Color(0xFF4CAF50), 'Tích cực (${stats.positivePercentage.toStringAsFixed(0)}%)'),
            _legendItem(const Color(0xFFFFB703), 'Trung tính (${stats.neutralPercentage.toStringAsFixed(0)}%)'),
            _legendItem(const Color(0xFFE53935), 'Tiêu cực (${stats.negativePercentage.toStringAsFixed(0)}%)'),
          ],
        ),
      ],
    );
  }

  Widget _legendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildLoadingState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(color: Colors.purple, strokeWidth: 2.5),
            SizedBox(height: 14),
            Text(
              'RestNDine AI đang phân tích bình luận...',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.purple,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
