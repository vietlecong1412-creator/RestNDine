import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:signalr_netcore/signalr_client.dart' show HubConnectionState;
import '../../config/app_theme.dart';
import '../../models/chat_message_model.dart';
import '../../models/place_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_exception.dart';
import '../../services/chat_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/common.dart';
import '../../widgets/place_image.dart';

class ChatScreen extends StatefulWidget {
  final int placeId;
  final String placeName;
  final String receiverId;

  /// Dùng cho ảnh đại diện và gợi ý câu hỏi theo loại địa điểm.
  final PlaceModel? place;

  const ChatScreen({
    super.key,
    required this.placeId,
    required this.placeName,
    required this.receiverId,
    this.place,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

enum _SendState { sending, failed }

/// Tin đã hiện trên màn hình nhưng server chưa xác nhận.
class _PendingMessage {
  final int localId;
  final String content;
  final DateTime createdAt;
  _SendState state = _SendState.sending;

  _PendingMessage(this.localId, this.content) : createdAt = DateTime.now();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _msgCtrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  final List<ChatMessageModel> _messages = [];
  final List<_PendingMessage> _pending = [];
  bool _isLoading = true;
  String? _loadError;
  HubConnectionState? _connState;
  int _localSeq = 0;

  String get _myId => context.read<AuthProvider>().user?.id ?? '';

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _chatService.connect(_onIncoming, onState: (s) {
      if (mounted) setState(() => _connState = s);
    });
  }

  @override
  void dispose() {
    _chatService.disconnect();
    _msgCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final list = await _chatService.getMessages(widget.placeId);
      if (!mounted) return;
      setState(() {
        for (final m in list) {
          _addMessage(m);
        }
        _messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _isLoading = false;
      });
    }
  }

  void _addMessage(ChatMessageModel m) {
    if (m.id != 0 && _messages.any((x) => x.id == m.id)) return;
    _messages.add(m);
  }

  void _onIncoming(ChatMessageModel msg) {
    if (!mounted || msg.placeId != widget.placeId) return;
    setState(() {
      // Tin của chính mình về qua SignalR trước phản hồi HTTP: bỏ bản tạm cùng nội dung
      if (msg.senderId == _myId) {
        final i = _pending.indexWhere((p) => p.state == _SendState.sending && p.content == msg.content);
        if (i >= 0) _pending.removeAt(i);
      }
      _addMessage(msg);
    });
  }

  void _send([String? preset]) {
    final content = (preset ?? _msgCtrl.text).trim();
    if (content.isEmpty) return;
    if (preset == null) _msgCtrl.clear();
    final pending = _PendingMessage(++_localSeq, content);
    setState(() => _pending.add(pending));
    _deliver(pending);
  }

  Future<void> _deliver(_PendingMessage pending) async {
    try {
      final sent = await _chatService.sendMessage(widget.placeId, widget.receiverId, pending.content);
      if (!mounted) return;
      setState(() {
        _pending.remove(pending);
        _addMessage(sent);
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => pending.state = _SendState.failed);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _onFailedTap(_PendingMessage pending) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.refresh_rounded),
              title: const Text('Gửi lại'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => pending.state = _SendState.sending);
                _deliver(pending);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: context.colors.danger),
              title: Text('Xóa tin nhắn', style: TextStyle(color: context.colors.danger)),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _pending.remove(pending));
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  List<Object> _buildItems(String myId) {
    final bubbles = <_Bubble>[
      for (final m in _messages) _Bubble(text: m.content, time: m.sentAt, mine: m.senderId == myId),
      for (final p in _pending) _Bubble(text: p.content, time: p.createdAt, mine: true, pending: p),
    ];

    bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
    bool sameGroup(_Bubble a, _Bubble b) =>
        a.mine == b.mine && sameDay(a.time, b.time) && b.time.difference(a.time).inMinutes.abs() <= 5;

    final items = <Object>[];
    for (var i = 0; i < bubbles.length; i++) {
      final b = bubbles[i];
      final prev = i > 0 ? bubbles[i - 1] : null;
      final next = i < bubbles.length - 1 ? bubbles[i + 1] : null;
      if (prev == null || !sameDay(prev.time, b.time)) items.add(b.time);
      b.firstInGroup = prev == null || !sameGroup(prev, b);
      b.lastInGroup = next == null || !sameGroup(b, next);
      items.add(b);
    }
    return items;
  }

  String get _statusText {
    switch (_connState) {
      case HubConnectionState.Connecting:
      case HubConnectionState.Reconnecting:
        return 'Đang kết nối…';
      case HubConnectionState.Disconnected:
        return 'Ngoại tuyến · tin mới có thể đến chậm';
      default:
        return 'Chủ quán';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final myId = context.watch<AuthProvider>().user?.id ?? '';
    final offline = _connState == HubConnectionState.Disconnected && !_isLoading;

    return Scaffold(
      backgroundColor: colors.card,
      appBar: AppBar(
        backgroundColor: colors.card,
        titleSpacing: 0,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 40,
                height: 40,
                child: widget.place != null
                    ? PlaceImage(place: widget.place!, displayWidth: 40)
                    : ColoredBox(
                        color: context.scheme.primaryContainer,
                        child: Icon(Icons.storefront_rounded, color: context.scheme.onPrimaryContainer),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.placeName, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleMedium),
                  Text(
                    _statusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall!.copyWith(color: offline ? colors.warning : colors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (offline)
            IconButton(
              tooltip: 'Tải lại tin nhắn',
              onPressed: _loadHistory,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: colors.border),
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody(myId)),
          _Composer(controller: _msgCtrl, focusNode: _focus, onSend: _send),
        ],
      ),
    );
  }

  Widget _buildBody(String myId) {
    if (_isLoading && _messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null && _messages.isEmpty) {
      return EmptyState(
        icon: Icons.forum_outlined,
        title: 'Không tải được tin nhắn',
        message: _loadError,
        actionLabel: 'Thử lại',
        onAction: _loadHistory,
        tint: context.colors.danger,
      );
    }
    if (_messages.isEmpty && _pending.isEmpty) {
      return _EmptyChat(
        placeName: widget.placeName,
        isHotel: widget.place?.type == PlaceType.hotel,
        onSuggestion: (text) {
          _msgCtrl.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
          _focus.requestFocus();
        },
      );
    }

    final items = _buildItems(myId);
    return ListView.builder(
      reverse: true, // tin mới nhất ở dưới cùng, tự cuộn theo bàn phím
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[items.length - 1 - index];
        if (item is DateTime) return _DaySeparator(day: item);
        final bubble = item as _Bubble;
        return _BubbleView(
          bubble: bubble,
          onFailedTap: bubble.pending != null ? () => _onFailedTap(bubble.pending!) : null,
        );
      },
    );
  }
}

class _Bubble {
  final String text;
  final DateTime time;
  final bool mine;
  final _PendingMessage? pending;
  bool firstInGroup = true;
  bool lastInGroup = true;

  _Bubble({required this.text, required this.time, required this.mine, this.pending});
}

class _BubbleView extends StatelessWidget {
  final _Bubble bubble;
  final VoidCallback? onFailedTap;

  const _BubbleView({required this.bubble, this.onFailedTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scheme = context.scheme;
    final mine = bubble.mine;
    final state = bubble.pending?.state;
    final failed = state == _SendState.failed;
    const big = Radius.circular(20);
    const small = Radius.circular(6);

    final radius = mine
        ? BorderRadius.only(
            topLeft: big,
            bottomLeft: big,
            topRight: bubble.firstInGroup ? big : small,
            bottomRight: bubble.lastInGroup ? big : small,
          )
        : BorderRadius.only(
            topRight: big,
            bottomRight: big,
            topLeft: bubble.firstInGroup ? big : small,
            bottomLeft: bubble.lastInGroup ? big : small,
          );

    Widget? status;
    if (state == _SendState.sending) {
      status = _StatusLine(icon: Icons.schedule_rounded, text: 'Đang gửi…', color: colors.textMuted);
    } else if (failed) {
      status = _StatusLine(icon: Icons.error_outline_rounded, text: 'Chưa gửi được · chạm để thử lại', color: colors.danger);
    } else if (bubble.lastInGroup) {
      status = Text(formatTime(bubble.time), style: context.text.labelSmall!.copyWith(color: colors.textMuted));
    }

    return Padding(
      padding: EdgeInsets.only(
        top: bubble.firstInGroup ? 10 : 2,
        left: mine ? 56 : 0,
        right: mine ? 0 : 56,
      ),
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: failed ? onFailedTap : null,
            onLongPress: () async {
              await Clipboard.setData(ClipboardData(text: bubble.text));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(content: Text('Đã sao chép tin nhắn')));
            },
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: state == _SendState.sending ? 0.7 : 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: failed
                      ? colors.dangerContainer
                      : mine
                          ? scheme.primary
                          : colors.field,
                  borderRadius: radius,
                ),
                child: Text(
                  bubble.text,
                  style: context.text.bodyMedium!.copyWith(
                    height: 1.4,
                    color: failed
                        ? colors.danger
                        : mine
                            ? scheme.onPrimary
                            : colors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
          if (status != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
              child: status,
            ),
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _StatusLine({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(text, style: context.text.labelSmall!.copyWith(color: color)),
      ],
    );
  }
}

class _DaySeparator extends StatelessWidget {
  final DateTime day;

  const _DaySeparator({required this.day});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 6),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: context.colors.field,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            formatDayLabel(day),
            style: context.text.labelSmall!.copyWith(color: context.colors.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  final String placeName;
  final bool isHotel;
  final ValueChanged<String> onSuggestion;

  const _EmptyChat({required this.placeName, required this.isHotel, required this.onSuggestion});

  @override
  Widget build(BuildContext context) {
    final suggestions = isHotel
        ? const ['Còn phòng trống tối nay không ạ?', 'Giá phòng một đêm bao nhiêu ạ?', 'Mấy giờ nhận phòng ạ?', 'Có chỗ đậu xe không ạ?']
        : const ['Quán còn bàn trống không ạ?', 'Quán mở cửa đến mấy giờ ạ?', 'Cho mình xin thực đơn với ạ', 'Có chỗ đậu xe không ạ?'];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(color: context.scheme.primaryContainer, shape: BoxShape.circle),
            child: Icon(Icons.waving_hand_rounded, size: 36, color: context.scheme.onPrimaryContainer),
          ),
          const SizedBox(height: 18),
          Text('Bắt đầu trò chuyện', style: context.text.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Gửi câu hỏi cho chủ $placeName. Bạn sẽ thấy phản hồi ngay tại đây.',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium!.copyWith(color: context.colors.textSecondary),
          ),
          const SizedBox(height: 22),
          Text('Gợi ý câu hỏi', style: context.text.labelMedium!.copyWith(color: context.colors.textMuted)),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in suggestions)
                ActionChip(
                  label: Text(s),
                  onPressed: () => onSuggestion(s),
                  avatar: Icon(Icons.chat_bubble_outline_rounded, size: 16, color: context.scheme.primary),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;

  const _Composer({required this.controller, required this.focusNode, required this.onSend});

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
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 2000,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Nhập tin nhắn…',
                    counterText: '',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    enabledBorder:
                        OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: context.scheme.primary, width: 1.4),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (_, value, __) {
                  final canSend = value.text.trim().isNotEmpty;
                  return AnimatedScale(
                    scale: canSend ? 1 : 0.9,
                    duration: const Duration(milliseconds: 150),
                    child: IconButton.filled(
                      tooltip: 'Gửi',
                      onPressed: canSend ? onSend : null,
                      icon: const Icon(Icons.send_rounded, size: 20),
                      style: IconButton.styleFrom(minimumSize: const Size(46, 46)),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
