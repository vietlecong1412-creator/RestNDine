import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';
import 'api_exception.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _api = ApiService();
  static const _storage = FlutterSecureStorage();
  static const _userKey = 'current_user';

  Future<void> _saveUser(UserModel user) => _storage.write(key: _userKey, value: jsonEncode(user.toJson()));

  Future<UserModel?> _readSavedUser() async {
    try {
      final raw = await _storage.read(key: _userKey);
      return raw == null ? null : UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// ASP.NET Identity trả lỗi tiếng Anh; dịch các lỗi hay gặp khi đăng ký.
  static String _translateIdentityErrors(String message) {
    const map = {
      'at least one non alphanumeric': 'Mật khẩu cần ít nhất một ký tự đặc biệt (ví dụ @, #, !).',
      'at least one digit': 'Mật khẩu cần ít nhất một chữ số.',
      'at least one lowercase': 'Mật khẩu cần ít nhất một chữ thường.',
      'at least one uppercase': 'Mật khẩu cần ít nhất một chữ hoa.',
      'must be at least': 'Mật khẩu phải có ít nhất 6 ký tự.',
      'is already taken': 'Email này đã được sử dụng.',
      'is invalid': 'Email không hợp lệ.',
    };
    final parts = message.split(';').map((p) => p.trim()).where((p) => p.isNotEmpty);
    final translated = parts.map((p) {
      final lower = p.toLowerCase();
      for (final e in map.entries) {
        if (lower.contains(e.key)) return e.value;
      }
      return p;
    });
    return translated.toSet().join('\n');
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _api.dio.post(
        '/api/auth/login',
        data: {'email': email, 'password': password},
      );

      if (response.data['success'] == true) {
        final token = response.data['token'];
        await _api.saveToken(token);
        final user = UserModel.fromJson(response.data['user']);
        await _saveUser(user);
        return {'success': true, 'user': user};
      }

      return {
        'success': false,
        'message': response.data['message'] ?? 'Đăng nhập thất bại.',
      };
    } on DioException catch (e) {
      final data = e.response?.data;
      // 403 + requiresOtp: tài khoản chưa xác thực email, server đã gửi OTP
      if (data is Map && data['requiresOtp'] == true) {
        return {
          'success': false,
          'requiresOtp': true,
          'email': data['email'] ?? email,
          'message': data['message'],
        };
      }
      return {'success': false, 'message': ApiException.from(e, fallback: 'Đăng nhập thất bại.').message};
    } catch (e) {
      return {'success': false, 'message': ApiException.from(e, fallback: 'Đăng nhập thất bại.').message};
    }
  }

  /// Đăng ký không trả token — server gửi OTP, client phải gọi [verifyOtp].
  Future<Map<String, dynamic>> register(String email, String password, {String role = 'Customer'}) async {
    try {
      final response = await _api.dio.post(
        '/api/auth/register',
        data: {'email': email, 'password': password, 'role': role},
      );

      if (response.data['success'] == true) {
        return {
          'success': true,
          'requiresOtp': response.data['requiresOtp'] == true,
          'email': response.data['email'] ?? email,
          'message': response.data['message'],
        };
      }

      return {
        'success': false,
        'message': _translateIdentityErrors(response.data['message'] ?? 'Đăng ký thất bại.'),
      };
    } catch (e) {
      final msg = ApiException.from(e, fallback: 'Đăng ký thất bại.').message;
      return {'success': false, 'message': _translateIdentityErrors(msg)};
    }
  }

  Future<Map<String, dynamic>> verifyOtp(String email, String code) async {
    try {
      final response = await _api.dio.post(
        '/api/auth/verify-otp',
        data: {'email': email, 'code': code},
      );

      if (response.data['success'] == true) {
        await _api.saveToken(response.data['token']);
        final user = UserModel.fromJson(response.data['user']);
        await _saveUser(user);
        return {'success': true, 'user': user};
      }

      return {
        'success': false,
        'message': response.data['message'] ?? 'Xác thực OTP thất bại.',
      };
    } catch (e) {
      return {'success': false, 'message': ApiException.from(e, fallback: 'Xác thực OTP thất bại.').message};
    }
  }

  Future<Map<String, dynamic>> resendOtp(String email) async {
    try {
      final response = await _api.dio.post(
        '/api/auth/resend-otp',
        data: {'email': email},
      );
      return {'success': true, 'message': response.data['message']};
    } on DioException catch (e) {
      final data = e.response?.data;
      return {
        'success': false,
        'retryAfterSeconds': data is Map ? data['retryAfterSeconds'] : null,
        'message': ApiException.from(e, fallback: 'Không gửi lại được mã.').message,
      };
    } catch (e) {
      return {'success': false, 'message': ApiException.from(e, fallback: 'Không gửi lại được mã.').message};
    }
  }

  /// Khôi phục phiên lúc mở app. Chỉ coi là đã đăng xuất khi server từ chối token (401/403);
  /// lỗi mạng hay lỗi server tạm thời thì thử lại rồi dùng thông tin người dùng đã lưu.
  Future<UserModel?> getCurrentUser() async {
    final String? token;
    try {
      token = await _api.getToken();
    } catch (_) {
      return null;
    }
    if (token == null) return null;

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await _api.dio.get('/api/auth/me');
        if (response.data['success'] == true && response.data['user'] != null) {
          final user = UserModel.fromJson(response.data['user']);
          await _saveUser(user);
          return user;
        }
        break;
      } on DioException catch (e) {
        final code = e.response?.statusCode;
        if (code == 401 || code == 403) {
          await logout();
          return null;
        }
        if (attempt == 0) await Future<void>.delayed(const Duration(milliseconds: 1500));
      } catch (_) {
        break;
      }
    }
    return _readSavedUser();
  }

  Future<void> logout() async {
    await _api.clearToken();
    try {
      await _storage.delete(key: _userKey);
    } catch (_) {}
  }
}
