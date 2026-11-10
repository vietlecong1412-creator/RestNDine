import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../models/place_model.dart';
import '../../../services/api_exception.dart';
import '../../../services/place_service.dart';
import '../../../utils/formatters.dart';
import '../../../widgets/common.dart';

const ratingLabels = ['Rất tệ', 'Tệ', 'Bình thường', 'Tốt', 'Tuyệt vời'];

/// Điểm trung bình lớn + biểu đồ phân bố 5→1 sao.
class RatingSummary extends StatelessWidget {
  final PlaceModel place;

  const RatingSummary({super.key, required this.place});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dist = place.ratingDistribution;
    final total = place.reviewCount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.field,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 104,
            child: Column(
              children: [
                Text(
                  formatRating(place.averageRating),
                  style: context.text.displaySmall!.copyWith(fontSize: 40),
                ),
                const SizedBox(height: 4),
                RatingStars(rating: place.averageRating, size: 16),
                const SizedBox(height: 6),
                Text('$total đánh giá', style: context.text.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                for (var star = 5; star >= 1; star--)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 14,
                          child: Text('$star', style: context.text.labelSmall!.copyWith(color: colors.textSecondary)),
                        ),
                        Icon(Icons.star_rounded, size: 12, color: colors.star),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: total == 0 ? 0 : dist[star - 1] / total,
                              minHeight: 7,
                              color: colors.star,
                              backgroundColor: colors.border,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 28,
                          child: Text(
                            '${dist[star - 1]}',
                            textAlign: TextAlign.right,
                            style: context.text.labelSmall!.copyWith(color: colors.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Một đánh giá: avatar, tên rút gọn, số sao, thời gian, nội dung và nút "Hữu ích".
class ReviewTile extends StatelessWidget {
  final PlaceCommentModel review;
  final int helpfulCount;
  final bool voted;
  final bool voting;
  final VoidCallback onHelpful;

  const ReviewTile({
    super.key,
    required this.review,
    required this.helpfulCount,
    required this.voted,
    required this.voting,
    required this.onHelpful,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scheme = context.scheme;
    final name = review.authorName;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(name: name, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        RatingStars(rating: review.rating.toDouble(), size: 14),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            timeAgo(review.createdAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodySmall!.copyWith(color: colors.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ExpandableText(review.content, maxLines: 5),
          const SizedBox(height: 10),
          Semantics(
            button: true,
            label: 'Đánh dấu hữu ích',
            child: InkWell(
              onTap: voted || voting ? null : onHelpful,
              borderRadius: BorderRadius.circular(999),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: voted ? scheme.primaryContainer : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: voted ? Colors.transparent : colors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (voting)
                      const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    else
                      Icon(
                        voted ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined,
                        size: 15,
                        color: voted ? scheme.onPrimaryContainer : colors.textSecondary,
                      ),
                    const SizedBox(width: 6),
                    Text(
                      helpfulCount > 0 ? 'Hữu ích · $helpfulCount' : 'Hữu ích',
                      style: context.text.labelMedium!.copyWith(
                        color: voted ? scheme.onPrimaryContainer : colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mở sheet viết đánh giá; trả về true khi đã gửi thành công.
Future<bool?> showReviewComposer(BuildContext context, {required PlaceModel place}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ReviewComposerSheet(place: place),
  );
}

class ReviewComposerSheet extends StatefulWidget {
  final PlaceModel place;

  const ReviewComposerSheet({super.key, required this.place});

  @override
  State<ReviewComposerSheet> createState() => _ReviewComposerSheetState();
}

class _ReviewComposerSheetState extends State<ReviewComposerSheet> {
  final _service = PlaceService();
  final _ctrl = TextEditingController();
  int _rating = 0;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (_rating == 0) {
      setState(() => _error = 'Bạn hãy chọn số sao trước nhé.');
      return;
    }
    if (text.length < 5) {
      setState(() => _error = 'Viết thêm vài chữ về trải nghiệm của bạn nhé (ít nhất 5 ký tự).');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _service.addComment(widget.place.id, text, _rating);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final label = _rating == 0 ? 'Chạm vào sao để chấm điểm' : ratingLabels[_rating - 1];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Đánh giá của bạn', style: context.text.titleLarge),
            const SizedBox(height: 4),
            Text(
              widget.place.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodyMedium!.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final star = i + 1;
                final active = star <= _rating;
                return Semantics(
                  label: '$star sao — ${ratingLabels[i]}',
                  selected: star == _rating,
                  button: true,
                  child: IconButton(
                    onPressed: _submitting
                        ? null
                        : () => setState(() {
                              _rating = star;
                              _error = null;
                            }),
                    iconSize: 40,
                    icon: AnimatedScale(
                      scale: active ? 1.08 : 1,
                      duration: const Duration(milliseconds: 150),
                      child: Icon(
                        active ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: active ? colors.star : colors.textMuted,
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 2),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: Text(
                label,
                key: ValueKey(label),
                textAlign: TextAlign.center,
                style: context.text.labelLarge!.copyWith(
                  color: _rating == 0 ? colors.textMuted : colors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _ctrl,
              enabled: !_submitting,
              minLines: 4,
              maxLines: 8,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              decoration: const InputDecoration(
                hintText: 'Món ăn, phục vụ, không gian... có điều gì đáng nhớ?',
                alignLabelWithHint: true,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              ErrorBanner(message: _error!),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Text('Gửi đánh giá'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Khung xương cho danh sách đánh giá.
class ReviewSkeleton extends StatelessWidget {
  const ReviewSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SkeletonPulse(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SkeletonBox(width: 42, height: 42, radius: 21),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 120, height: 13),
                    SizedBox(height: 8),
                    SkeletonBox(width: 90, height: 11),
                  ],
                ),
              ],
            ),
            SizedBox(height: 14),
            SkeletonBox(height: 12),
            SizedBox(height: 8),
            SkeletonBox(width: 220, height: 12),
          ],
        ),
      ),
    );
  }
}
