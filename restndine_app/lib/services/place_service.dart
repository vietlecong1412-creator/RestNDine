import '../models/category_model.dart';
import '../models/place_model.dart';
import '../models/ai_summary_model.dart';
import 'api_service.dart';

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
      return [];
    }
  }

  Future<List<PlaceModel>> getPlaces({String? search, List<int>? categoryIds}) async {
    try {
      final Map<String, dynamic> queryParams = {};
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (categoryIds != null && categoryIds.isNotEmpty) {
        queryParams['categoryIds'] = categoryIds;
      }

      final response = await _api.dio.get('/api/places', queryParameters: queryParams);
      if (response.data is List) {
        return (response.data as List)
            .map((e) => PlaceModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<PlaceModel?> getPlaceDetail(int id) async {
    try {
      final response = await _api.dio.get('/api/places/$id');
      if (response.statusCode == 200 && response.data != null) {
        return PlaceModel.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<AiSummaryModel?> getAiSummary(int id, {bool forceRefresh = false}) async {
    try {
      final response = await _api.dio.get(
        '/api/places/$id/ai-summary',
        queryParameters: {'forceRefresh': forceRefresh},
      );
      if (response.data != null) {
        return AiSummaryModel.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<PlaceCommentModel?> addComment(int placeId, String content, int rating) async {
    try {
      final response = await _api.dio.post(
        '/api/places/$placeId/comments',
        data: {'content': content, 'rating': rating},
      );
      if (response.data['success'] == true && response.data['comment'] != null) {
        return PlaceCommentModel.fromJson(response.data['comment']);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<int?> voteCommentHelpful(int commentId) async {
    try {
      final response = await _api.dio.post('/api/places/comments/$commentId/helpful');
      if (response.data['success'] == true) {
        return response.data['helpfulCount'] as int?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
