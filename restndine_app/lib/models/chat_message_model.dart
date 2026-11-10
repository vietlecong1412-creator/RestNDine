import '../utils/formatters.dart';

class ChatMessageModel {
  final int id;
  final String senderId;
  final String senderEmail;
  final String receiverId;
  final String receiverEmail;
  final String content;
  final DateTime sentAt;
  final bool isRead;
  final int placeId;

  ChatMessageModel({
    required this.id,
    required this.senderId,
    required this.senderEmail,
    required this.receiverId,
    required this.receiverEmail,
    required this.content,
    required this.sentAt,
    required this.isRead,
    required this.placeId,
  });

  /// API chat (cả REST lẫn SignalR) trả `sentAt` là giờ Việt Nam dạng "dd/MM/yyyy HH:mm";
  /// vẫn đọc được ISO 8601 phòng khi server đổi định dạng.
  static DateTime _parseSentAt(Object? raw) {
    if (raw == null) return DateTime.now();
    final s = raw.toString();
    return parseVietnamDateTime(s) ?? parseServerDate(s) ?? DateTime.now();
  }

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      senderId: json['senderId'] ?? '',
      senderEmail: json['senderEmail'] ?? 'Người dùng',
      receiverId: json['receiverId'] ?? '',
      receiverEmail: json['receiverEmail'] ?? 'Chủ quán',
      content: json['content'] ?? '',
      sentAt: _parseSentAt(json['sentAt']),
      isRead: json['isRead'] ?? false,
      placeId: json['placeId'] is int ? json['placeId'] : 0,
    );
  }
}
