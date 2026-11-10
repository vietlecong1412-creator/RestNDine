import 'dart:async';
import 'package:dio/dio.dart';
import 'package:signalr_netcore/signalr_client.dart';
import '../config/app_config.dart';
import '../models/chat_message_model.dart';
import 'api_exception.dart';
import 'api_service.dart';

class ChatService {
  final ApiService _api = ApiService();
  HubConnection? _hubConnection;
  StreamSubscription<HubConnectionState>? _stateSub;

  /// Kết nối SignalR để nhận tin mới; [onState] báo trạng thái kết nối cho giao diện.
  Future<void> connect(
    void Function(ChatMessageModel) onMessage, {
    void Function(HubConnectionState state)? onState,
  }) async {
    try {
      final token = await _api.getToken();
      if (token == null) return;

      final hubUrl = '${AppConfig.chatHubUrl}?access_token=$token';

      _hubConnection = HubConnectionBuilder()
          .withUrl(hubUrl)
          .withAutomaticReconnect()
          .build();

      if (onState != null) {
        _stateSub = _hubConnection!.stateStream.listen(onState);
      }

      _hubConnection?.on('ReceiveMessage', (arguments) {
        if (arguments != null && arguments.isNotEmpty) {
          final data = arguments[0];
          if (data is Map) {
            onMessage(ChatMessageModel.fromJson(Map<String, dynamic>.from(data)));
          }
        }
      });

      await _hubConnection?.start();
    } catch (_) {
      // Không có realtime thì vẫn gửi/nhận qua REST, giao diện hiển thị trạng thái mất kết nối
      onState?.call(HubConnectionState.Disconnected);
    }
  }

  Future<void> disconnect() async {
    await _stateSub?.cancel();
    try {
      await _hubConnection?.stop();
    } catch (_) {}
  }

  /// Ném [ApiException] khi lỗi để màn hình không nhầm thành "chưa có tin nhắn".
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
    } catch (e) {
      throw ApiException.from(e, fallback: 'Không tải được tin nhắn.');
    }
  }

  Future<ChatMessageModel> sendMessage(int placeId, String receiverId, String content) async {
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
      throw const ApiException('Không gửi được tin nhắn.');
    } catch (e) {
      throw ApiException.from(e, fallback: 'Không gửi được tin nhắn.');
    }
  }
}
