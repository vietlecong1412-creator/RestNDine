import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../models/chat_message_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  final int placeId;
  final String placeName;
  final String receiverId;

  const ChatScreen({
    super.key,
    required this.placeId,
    required this.placeName,
    required this.receiverId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessageModel> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistoryAndConnect();
  }

  @override
  void dispose() {
    _chatService.disconnect();
    _msgCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHistoryAndConnect() async {
    final list = await _chatService.getMessages(widget.placeId);
    if (mounted) {
      setState(() {
        _messages.addAll(list);
        _isLoading = false;
      });
      _scrollToBottom();
    }

    // Connect SignalR
    await _chatService.connect((newMsg) {
      if (mounted && newMsg.placeId == widget.placeId) {
        setState(() {
          // Check if message already exists
          if (!_messages.any((m) => m.id == newMsg.id && m.id != 0)) {
            _messages.add(newMsg);
          }
        });
        _scrollToBottom();
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();

    final sent = await _chatService.sendMessage(widget.placeId, widget.receiverId, text);
    if (!mounted) return;

    if (sent != null) {
      setState(() {
        if (!_messages.any((m) => m.id == sent.id && m.id != 0)) {
          _messages.add(sent);
        }
      });
      _scrollToBottom();
    } else {
      // Gửi lỗi: trả lại nội dung để người dùng không phải gõ lại
      if (_msgCtrl.text.isEmpty) _msgCtrl.text = text;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không gửi được tin nhắn. Vui lòng thử lại.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final currentUserId = auth.user?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.placeName, style: const TextStyle(fontSize: 16)),
            const Row(
              children: [
                Icon(Icons.circle, color: Colors.green, size: 8),
                SizedBox(width: 4),
                Text(
                  'Trực tuyến (SignalR)',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 54, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              'Chưa có tin nhắn nào.\nHãy gửi lời chào đến chủ quán!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe = msg.senderId == currentUserId;

                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.75,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isMe ? AppTheme.primaryColor : Colors.white,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(14),
                                  topRight: const Radius.circular(14),
                                  bottomLeft: Radius.circular(isMe ? 14 : 2),
                                  bottomRight: Radius.circular(isMe ? 2 : 14),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    msg.content,
                                    style: TextStyle(
                                      color: isMe ? Colors.white : AppTheme.textPrimary,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${msg.sentAt.hour.toString().padLeft(2, '0')}:${msg.sentAt.minute.toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      color: isMe ? Colors.white70 : Colors.grey.shade500,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Message Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Nhập tin nhắn...',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: AppTheme.primaryColor,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 18),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
