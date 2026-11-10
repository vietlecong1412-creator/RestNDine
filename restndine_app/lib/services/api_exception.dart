import 'package:dio/dio.dart';

/// Lỗi gọi API kèm thông báo tiếng Việt hiển thị được ngay cho người dùng.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  factory ApiException.from(Object error, {String fallback = 'Đã có lỗi xảy ra. Vui lòng thử lại.'}) {
    if (error is ApiException) return error;
    if (error is! DioException) return ApiException(fallback);

    final code = error.response?.statusCode;
    final data = error.response?.data;
    final serverMessage = data is Map ? data['message'] : (data is String && data.length < 200 ? data : null);

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException('Máy chủ phản hồi quá lâu. Vui lòng thử lại.');
      case DioExceptionType.connectionError:
        return const ApiException('Không kết nối được máy chủ. Hãy kiểm tra mạng và thử lại.');
      case DioExceptionType.badResponse:
        if (serverMessage is String && serverMessage.trim().isNotEmpty) {
          return ApiException(serverMessage, statusCode: code);
        }
        if (code == 401) {
          return ApiException('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.', statusCode: code);
        }
        if (code == 404) return ApiException('Không tìm thấy dữ liệu.', statusCode: code);
        if (code != null && code >= 500) {
          return ApiException('Máy chủ đang gặp sự cố. Vui lòng thử lại sau.', statusCode: code);
        }
        return ApiException(fallback, statusCode: code);
      default:
        return ApiException(fallback);
    }
  }

  @override
  String toString() => message;
}
