import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _user;
  bool _isLoading = true;
  String? _errorMessage;
  String? _pendingOtpEmail;

  UserModel? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Email đang chờ nhập OTP (sau đăng ký, hoặc đăng nhập tài khoản chưa xác thực).
  String? get pendingOtpEmail => _pendingOtpEmail;

  AuthProvider() {
    checkCurrentUser();
  }

  Future<void> checkCurrentUser() async {
    _isLoading = true;
    notifyListeners();
    try {
      _user = await _authService.getCurrentUser();
    } catch (_) {
      _user = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Trả về true khi đăng nhập xong. Nếu tài khoản chưa xác thực email,
  /// trả về false và đặt [pendingOtpEmail] để màn hình chuyển sang nhập OTP.
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    _pendingOtpEmail = null;
    notifyListeners();

    final result = await _authService.login(email, password);
    _isLoading = false;

    if (result['success'] == true) {
      _user = result['user'] as UserModel;
      notifyListeners();
      return true;
    } else if (result['requiresOtp'] == true) {
      _pendingOtpEmail = result['email'] as String?;
      notifyListeners();
      return false;
    } else {
      _errorMessage = result['message'] as String?;
      notifyListeners();
      return false;
    }
  }

  /// Trả về true khi tạo tài khoản thành công; khi đó [pendingOtpEmail] được đặt
  /// và người dùng phải nhập OTP (gọi [verifyOtp]) mới đăng nhập được.
  Future<bool> register(String email, String password, {String role = 'Customer'}) async {
    _isLoading = true;
    _errorMessage = null;
    _pendingOtpEmail = null;
    notifyListeners();

    final result = await _authService.register(email, password, role: role);
    _isLoading = false;

    if (result['success'] == true) {
      _pendingOtpEmail = result['email'] as String?;
      notifyListeners();
      return true;
    } else {
      _errorMessage = result['message'] as String?;
      notifyListeners();
      return false;
    }
  }

  /// Trả về null nếu thành công (đã đăng nhập), ngược lại là thông báo lỗi.
  Future<String?> verifyOtp(String email, String code) async {
    final result = await _authService.verifyOtp(email, code);
    if (result['success'] == true) {
      _user = result['user'] as UserModel;
      _pendingOtpEmail = null;
      _errorMessage = null;
      notifyListeners();
      return null;
    }
    return result['message'] as String? ?? 'Xác thực OTP thất bại.';
  }

  Future<Map<String, dynamic>> resendOtp(String email) => _authService.resendOtp(email);

  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    notifyListeners();
  }
}
