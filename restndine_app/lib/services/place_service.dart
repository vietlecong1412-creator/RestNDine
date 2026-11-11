import 'package:dio/dio.dart' show Options;
import '../models/category_model.dart';
import '../models/place_model.dart';
import '../models/ai_summary_model.dart';
import 'api_exception.dart';
import 'api_service.dart';

/// Kết quả bấm "Hữu ích" cho một bình luận.
class HelpfulVoteResult {
  final int? helpfulCount;
  final bool alreadyVoted;
  final String? error;

  const HelpfulVoteResult({this.helpfulCount, this.alreadyVoted = false, this.error});

  bool get success => helpfulCount != null;
}

class PlaceService {
  final ApiService _api = ApiService();

  Future<List<CategoryModel>> getCategories() async {
    try {
      final response = await _api.dio.get('/api/places/categories');
      if (response.data is List) {
        return (response.data as List)
            .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      // Thiếu danh mục thì vẫn xem được địa điểm, không chặn màn hình
      return [];
    }
  }

  /// Toàn bộ địa điểm đã duyệt; tìm kiếm và lọc làm tại máy để phản hồi tức thì.
  /// Ném [ApiException] khi lỗi để giao diện phân biệt "lỗi mạng" với "không có kết quả".
  Future<List<PlaceModel>> getPlaces() async {
    try {
      final response = await _api.dio.get('/api/places');
      if (response.data is List) {
        return (response.data as List)
            .map((e) => PlaceModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw const ApiException('Dữ liệu trả về không hợp lệ.');
    } catch (e) {
      throw ApiException.from(e, fallback: 'Không tải được danh sách địa điểm.');
    }
  }

  Future<PlaceModel> getPlaceDetail(int id) async {
    try {
      final response = await _api.dio.get('/api/places/$id');
      return PlaceModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiException.from(e, fallback: 'Không tải được thông tin địa điểm.');
    }
  }

  /// Server chạy PhoBERT khi chưa có bản tóm tắt (giới hạn 120 giây, AiSummary:TimeoutSeconds),
  /// nên chờ lâu hơn hẳn mức mặc định 25 giây của các API khác.
  static const aiSummaryTimeout = Duration(seconds: 150);

  /// Ném [ApiException] khi lỗi để màn hình phân biệt được "lỗi tải" với "chưa có tóm tắt".
  Future<AiSummaryModel> getAiSummary(int id, {bool forceRefresh = false}) async {
    try {
      final response = await _api.dio.get(
        '/api/places/$id/ai-summary',
        queryParameters: {'forceRefresh': forceRefresh},
        options: Options(receiveTimeout: aiSummaryTimeout),
      );
      return AiSummaryModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiException.from(e, fallback: 'Không tải được tóm tắt AI.');
    }
  }

  /// Ném [ApiException] kèm lý do khi server từ chối.
  Future<PlaceCommentModel> addComment(int placeId, String content, int rating) async {
    try {
      final response = await _api.dio.post(
        '/api/places/$placeId/comments',
        data: {'content': content, 'rating': rating},
      );
      if (response.data['success'] == true && response.data['comment'] != null) {
        return PlaceCommentModel.fromJson(response.data['comment']);
      }
      throw ApiException(response.data['message'] ?? 'Không gửi được đánh giá.');
    } catch (e) {
      throw ApiException.from(e, fallback: 'Không gửi được đánh giá. Vui lòng thử lại.');
    }
  }

  Future<HelpfulVoteResult> voteCommentHelpful(int commentId) async {
    try {
      final response = await _api.dio.post('/api/places/comments/$commentId/helpful');
      if (response.data['success'] == true) {
        return HelpfulVoteResult(helpfulCount: response.data['helpfulCount'] as int?);
      }
      return const HelpfulVoteResult(error: 'Không ghi nhận được bình chọn.');
    } catch (e) {
      final err = ApiException.from(e, fallback: 'Không ghi nhận được bình chọn.');
      // Server trả 400 khi người dùng đã bình chọn bình luận này
      return HelpfulVoteResult(alreadyVoted: err.statusCode == 400, error: err.message);
    }
  }
}
