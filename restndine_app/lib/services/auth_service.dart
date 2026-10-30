import 'package:dio/dio.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _api = ApiService();

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
      final msg = (data is Map ? data['message'] : null) ?? 'Lỗi kết nối máy chủ.';
      return {'success': false, 'message': msg};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
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
        'message': response.data['message'] ?? 'Đăng ký thất bại.',
      };
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map ? data['message'] : null) ?? 'Lỗi kết nối máy chủ.';
      return {'success': false, 'message': msg};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
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
        return {'success': true, 'user': user};
      }

      return {
        'success': false,
        'message': response.data['message'] ?? 'Xác thực OTP thất bại.',
      };
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map ? data['message'] : null) ?? 'Lỗi kết nối máy chủ.';
      return {'success': false, 'message': msg};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
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
        'message': (data is Map ? data['message'] : null) ?? 'Lỗi kết nối máy chủ.',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<UserModel?> getCurrentUser() async {
    try {
      final token = await _api.getToken();
      if (token == null) return null;

      final response = await _api.dio.get('/api/auth/me');
      if (response.data['success'] == true && response.data['user'] != null) {
        return UserModel.fromJson(response.data['user']);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    await _api.clearToken();
  }
}
