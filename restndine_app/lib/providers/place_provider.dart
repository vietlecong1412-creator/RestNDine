import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import '../models/category_model.dart';
import '../models/place_model.dart';
import '../services/api_exception.dart';
import '../services/place_service.dart';
import '../utils/formatters.dart';

class PlaceProvider extends ChangeNotifier {
  final PlaceService _placeService = PlaceService();

  List<CategoryModel> _categories = [];
  List<PlaceModel> _allPlaces = [];
  List<PlaceModel> _places = [];
  List<PlaceModel> _featured = [];
  final Set<int> _selectedCategoryIds = {};
  String _searchQuery = '';
  PlaceModel? _selectedPlace;
  LatLng? _origin;
  Map<int, double> _distances = const {};
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _error;

  List<CategoryModel> get categories => _categories;

  /// Địa điểm sau khi áp dụng tìm kiếm và bộ lọc.
  List<PlaceModel> get places => _places;

  /// Địa điểm đang chạy quảng cáo (banner đã duyệt).
  List<PlaceModel> get featuredPlaces => _featured;
  int get totalCount => _allPlaces.length;
  Set<int> get selectedCategoryIds => _selectedCategoryIds;
  String get searchQuery => _searchQuery;
  PlaceModel? get selectedPlace => _selectedPlace;
  bool get isLoading => _isLoading;

  /// Đã tải thành công ít nhất một lần.
  bool get hasLoaded => _hasLoaded;

  /// Lỗi của lần tải gần nhất (null nếu thành công).
  String? get error => _error;
  bool get isFiltering => _searchQuery.trim().isNotEmpty || _selectedCategoryIds.isNotEmpty;

  /// Đã biết vị trí người dùng: danh sách xếp theo khoảng cách, thẻ hiện "cách bạn x km".
  bool get hasUserLocation => _origin != null;

  /// Khoảng cách (mét) từ vị trí người dùng tới [place]; null nếu chưa có vị trí hoặc địa điểm
  /// thiếu toạ độ.
  double? distanceTo(PlaceModel place) => _distances[place.id];

  /// Đi xa hơn mức này so với lần sắp xếp trước mới sắp xếp lại: danh sách không nhảy thứ tự
  /// liên tục khi người dùng vừa đi vừa xem.
  static const resortDistance = 200.0;

  PlaceProvider({bool autoLoad = true}) {
    if (autoLoad) load();
  }

  /// Cập nhật vị trí người dùng (từ LocationProvider). Chỉ sắp xếp lại khi lần đầu có vị trí
  /// hoặc đã đi xa hơn [resortDistance].
  void setUserLocation(LatLng? position) {
    final old = _origin;
    if (position == null || old == null) {
      if (position == old) return;
    } else if (distanceMeters(old.latitude, old.longitude, position.latitude, position.longitude) <
        resortDistance) {
      return;
    }
    _origin = position;
    _computeDistances();
    _applyFilters();
    notifyListeners();
  }

  void _computeDistances() {
    final o = _origin;
    _distances = o == null
        ? const {}
        : {
            for (final p in _allPlaces)
              if (p.hasValidLocation) p.id: distanceMeters(o.latitude, o.longitude, p.latitude, p.longitude),
          };
  }

  Future<void> load() async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _placeService.getCategories(),
        _placeService.getPlaces(),
      ]);
      _allPlaces = results[1] as List<PlaceModel>;
      final categories = results[0] as List<CategoryModel>;
      // API danh mục lỗi tạm thời thì dựng lại từ danh mục đi kèm từng địa điểm
      _categories = categories.isNotEmpty ? categories : _categoriesFromPlaces(_allPlaces);
      _featured = _allPlaces.where((p) => p.hasBanner).toList(growable: false);
      _hasLoaded = true;
      _computeDistances();
      _applyFilters();
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void toggleCategory(int categoryId) {
    if (!_selectedCategoryIds.remove(categoryId)) {
      _selectedCategoryIds.add(categoryId);
    }
    _applyFilters();
    notifyListeners();
  }

  void clearCategories() {
    if (_selectedCategoryIds.isEmpty) return;
    _selectedCategoryIds.clear();
    _applyFilters();
    notifyListeners();
  }

  void setSearchQuery(String query) {
    if (query == _searchQuery) return;
    _searchQuery = query;
    _applyFilters();
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedCategoryIds.clear();
    _applyFilters();
    notifyListeners();
  }

  void selectPlace(PlaceModel? place) {
    if (place?.id == _selectedPlace?.id) return;
    _selectedPlace = place;
    notifyListeners();
  }

  static List<CategoryModel> _categoriesFromPlaces(List<PlaceModel> places) {
    final byId = <int, CategoryModel>{};
    for (final p in places) {
      for (final c in p.categories) {
        byId.putIfAbsent(c.id, () => c);
      }
    }
    return byId.values.toList()..sort((a, b) => a.id.compareTo(b.id));
  }

  void _applyFilters() {
    final tokens = foldVietnamese(_searchQuery).split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

    // (địa điểm, điểm khớp, vị trí gốc); vị trí gốc giữ thứ tự server (quảng bá, hạng sao) khi bằng điểm
    // và chưa biết vị trí người dùng
    final matches = <(PlaceModel, int, int)>[];
    for (var i = 0; i < _allPlaces.length; i++) {
      final p = _allPlaces[i];
      if (_selectedCategoryIds.isNotEmpty &&
          !p.categories.any((c) => _selectedCategoryIds.contains(c.id))) {
        continue;
      }
      final score = p.searchScore(tokens);
      if (score > 0) matches.add((p, score, i));
    }
    // Đang tìm: khớp nhiều hơn đứng trước, bằng điểm thì quán gần hơn đứng trước.
    // Không tìm: quán gần nhất trước (nơi thiếu toạ độ xuống cuối), giống trang web
    final hasOrigin = _origin != null;
    if (tokens.isNotEmpty || hasOrigin) {
      int byDistance((PlaceModel, int, int) a, (PlaceModel, int, int) b) {
        if (hasOrigin) {
          final da = _distances[a.$1.id] ?? double.infinity;
          final db = _distances[b.$1.id] ?? double.infinity;
          if (da != db) return da.compareTo(db);
        }
        return a.$3.compareTo(b.$3);
      }

      matches.sort((a, b) => a.$2 != b.$2 ? b.$2.compareTo(a.$2) : byDistance(a, b));
    }
    _places = [for (final m in matches) m.$1];

    // Dải "Nổi bật" cũng ưu tiên nơi gần bạn
    final featured = _allPlaces.where((p) => p.hasBanner).toList();
    if (hasOrigin) {
      featured.sort((a, b) =>
          (_distances[a.id] ?? double.infinity).compareTo(_distances[b.id] ?? double.infinity));
    }
    _featured = featured;

    // Địa điểm đang chọn trên bản đồ không còn trong kết quả thì bỏ chọn
    final selected = _selectedPlace;
    if (selected != null && !_places.any((p) => p.id == selected.id)) {
      _selectedPlace = null;
    }
  }
}
