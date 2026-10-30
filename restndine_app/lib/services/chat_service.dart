import 'dart:async';
import 'package:dio/dio.dart';
import 'package:signalr_netcore/signalr_client.dart';
import '../config/app_config.dart';
import '../models/chat_message_model.dart';
import 'api_service.dart';

class ChatService {
  final ApiService _api = ApiService();
  HubConnection? _hubConnection;

  Future<void> connect(Function(ChatMessageModel) onMessage) async {
    try {
      final token = await _api.getToken();
      if (token == null) return;

      final hubUrl = '${AppConfig.chatHubUrl}?access_token=$token';

      _hubConnection = HubConnectionBuilder()
          .withUrl(hubUrl)
          .withAutomaticReconnect()
          .build();

      _hubConnection?.on('ReceiveMessage', (arguments) {
        if (arguments != null && arguments.isNotEmpty) {
          final data = arguments[0];
          if (data is Map<String, dynamic>) {
            final msg = ChatMessageModel.fromJson(data);
            onMessage(msg);
          }
        }
      });

      await _hubConnection?.start();
    } catch (_) {
      // SignalR connection error handled silently or with fallback
    }
  }

  Future<void> disconnect() async {
    try {
      await _hubConnection?.stop();
    } catch (_) {}
  }

  Future<List<ChatMessageModel>> getMessages(int placeId, {String? customerId}) async {
    try {
      final Map<String, dynamic> q = {'placeId': placeId};
      if (customerId != null) q['customerId'] = customerId;

      final res = await _api.dio.get('/api/chat/messages', queryParameters: q);
      if (res.data['success'] == true && res.data['messages'] is List) {
        return (res.data['messages'] as List)
            .map((e) => ChatMessageModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<ChatMessageModel?> sendMessage(int placeId, String receiverId, String content) async {
    try {
      final formData = FormData.fromMap({
        'placeId': placeId,
        'receiverId': receiverId,
        'content': content,
      });

      final res = await _api.dio.post('/api/chat/send', data: formData);
      if (res.data['success'] == true && res.data['message'] != null) {
        return ChatMessageModel.fromJson(res.data['message']);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
