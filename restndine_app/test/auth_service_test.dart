import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restndine_app/services/api_service.dart';
import 'package:restndine_app/services/auth_service.dart';

/// Trả mã lỗi cố định cho /api/auth/me.
class _MeAdapter implements HttpClientAdapter {
  int status = 200;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    final body = status == 200
        ? {
            'success': true,
            'user': {'id': 'u1', 'email': 'minh@gmail.com', 'userName': 'minh@gmail.com', 'roles': ['Customer']},
          }
        : {'success': false, 'message': 'lỗi'};
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final adapter = _MeAdapter();
  final auth = AuthService();
  const savedUser = '{"id":"u1","email":"minh@gmail.com","userName":"minh@gmail.com","roles":["Customer"]}';

  setUp(() => ApiService().dio.httpClientAdapter = adapter);

  test('server lỗi tạm thời: vẫn giữ phiên bằng thông tin đã lưu', () async {
    FlutterSecureStorage.setMockInitialValues({ApiService.tokenKey: 't', 'current_user': savedUser});
    adapter.status = 500;
    final user = await auth.getCurrentUser();
    expect(user?.email, 'minh@gmail.com');
    expect(await ApiService().getToken(), 't');
  });

  test('token bị từ chối (401): đăng xuất thật', () async {
    FlutterSecureStorage.setMockInitialValues({ApiService.tokenKey: 't', 'current_user': savedUser});
    adapter.status = 401;
    expect(await auth.getCurrentUser(), isNull);
    expect(await ApiService().getToken(), isNull);
  });

  test('không có token: chưa đăng nhập, không gọi server', () async {
    FlutterSecureStorage.setMockInitialValues({});
    adapter.status = 200;
    expect(await auth.getCurrentUser(), isNull);
  });
}
