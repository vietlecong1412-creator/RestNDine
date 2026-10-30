import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../models/place_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/place_service.dart';
import '../auth/login_screen.dart';
import '../chat/chat_screen.dart';
import '../home/widgets/place_image.dart';
import 'widgets/ai_summary_card.dart';

class PlaceDetailScreen extends StatefulWidget {
  final int placeId;

  const PlaceDetailScreen({super.key, required this.placeId});

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  final PlaceService _placeService = PlaceService();
  PlaceModel? _place;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlace();
  }

  Future<void> _loadPlace() async {
    final data = await _placeService.getPlaceDetail(widget.placeId);
    if (mounted) {
      setState(() {
        _place = data;
        _isLoading = false;
      });
    }
  }

  void _showAddCommentDialog() {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    final commentCtrl = TextEditingController();
    int selectedRating = 5;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Đánh giá & Bình luận',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  // Rating Stars
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final star = index + 1;
                      return IconButton(
                        icon: Icon(
                          star <= selectedRating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 32,
                        ),
                        onPressed: () {
                          setModalState(() => selectedRating = star);
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: commentCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Chia sẻ trải nghiệm của bạn về món ăn, dịch vụ, không gian...',
                    ),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        final text = commentCtrl.text.trim();
                        if (text.isEmpty) return;
                        Navigator.of(ctx).pop();

                        final messenger = ScaffoldMessenger.of(context);
                        final comment = await _placeService.addComment(
                          widget.placeId,
                          text,
                          selectedRating,
                        );

                        if (comment != null && mounted) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Cảm ơn bạn đã gửi đánh giá!'),
                              backgroundColor: AppTheme.accentColor,
                            ),
                          );
                          _loadPlace();
                        }
                      },
                      child: const Text('Gửi đánh giá'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_place == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Không tìm thấy thông tin địa điểm')),
      );
    }

    final p = _place!;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Collapsible Image Header
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            leading: CircleAvatar(
              backgroundColor: Colors.black.withOpacity(0.4),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  PlaceImage(place: p),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.transparent,
                          Colors.black.withOpacity(0.6),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Details Body
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Categories chips
                  Wrap(
                    spacing: 8,
                    children: p.categories.map((cat) {
                      return Chip(
                        label: Text('${cat.icon ?? ""} ${cat.name}'.trim()),
                        backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                        labelStyle: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),

                  // Place Name
                  Text(
                    p.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Rating & Price
                  Row(
                    children: [
                      if (p.starRating != null) ...[
                        const Icon(Icons.star, color: Colors.amber, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          '${p.starRating}.0 / 5.0',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(width: 14),
                      ],
                      if (p.priceRange != null && p.priceRange!.isNotEmpty) ...[
                        const Icon(Icons.payments_outlined, color: AppTheme.accentColor, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          p.priceRange!,
                          style: const TextStyle(
                            color: AppTheme.accentColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Address
                  if (p.address != null && p.address!.isNotEmpty)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on, color: AppTheme.primaryColor, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            p.address!,
                            style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                          ),
                        ),
                      ],
                    ),

                  // Phone
                  if (p.phoneNumber != null && p.phoneNumber!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.phone, color: Colors.blue, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          p.phoneNumber!,
                          style: const TextStyle(fontSize: 14, color: Colors.blue, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Description
                  if (p.description != null && p.description!.isNotEmpty) ...[
                    const Text('Giới thiệu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(
                      p.description!,
                      style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF424242)),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // AI Summary Card (PhoBERT)
                  AiSummaryCard(
                    placeId: p.id,
                    initialSummaryCache: p.aiSummaryCache,
                    canRefresh: context.watch<AuthProvider>().user?.roles.contains('Admin') == true ||
                        (p.ownerId != null && p.ownerId == context.watch<AuthProvider>().user?.id),
                  ),

                  const SizedBox(height: 24),

                  // Comments Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Đánh giá cộng đồng (${p.comments.length})',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Viết đánh giá'),
                        onPressed: _showAddCommentDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (p.comments.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      alignment: Alignment.center,
                      child: Text(
                        'Chưa có bình luận nào. Hãy là người đầu tiên đánh giá!',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    )
                  else
                    ...p.comments.map((c) => _buildCommentTile(c)),

                  const SizedBox(height: 80), // Spacing for bottom button
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Nhắn tin với chủ quán'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    if (!auth.isAuthenticated) {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                      return;
                    }

                    if (p.ownerId == null || p.ownerId!.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Địa điểm này chưa có chủ quán nhận quản lý.')),
                      );
                      return;
                    }

                    if (p.ownerId == auth.user?.id) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đây là địa điểm của bạn. Vui lòng trả lời khách trên trang web.')),
                      );
                      return;
                    }

                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          placeId: p.id,
                          placeName: p.name,
                          receiverId: p.ownerId!,
                        ),
                      ),
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

  Widget _buildCommentTile(PlaceCommentModel c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                c.userEmail,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < c.rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(c.content, style: const TextStyle(fontSize: 13, height: 1.4)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${c.createdAt.day}/${c.createdAt.month}/${c.createdAt.year}',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
              ),
              InkWell(
                onTap: () async {
                  final newCount = await _placeService.voteCommentHelpful(c.id);
                  if (newCount != null && mounted) {
                    setState(() {});
                  }
                },
                child: Row(
                  children: [
                    Icon(Icons.thumb_up_alt_outlined, size: 13, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      'Hữu ích (${c.helpfulCount})',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
