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

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      senderId: json['senderId'] ?? '',
      senderEmail: json['senderEmail'] ?? 'Người dùng',
      receiverId: json['receiverId'] ?? '',
      receiverEmail: json['receiverEmail'] ?? 'Chủ quán',
      content: json['content'] ?? '',
      sentAt: json['sentAt'] != null
          ? DateTime.tryParse(json['sentAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isRead: json['isRead'] ?? false,
      placeId: json['placeId'] is int ? json['placeId'] : 0,
    );
  }
}
