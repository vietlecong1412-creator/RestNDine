import 'package:flutter/material.dart';
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

  PlaceProvider({bool autoLoad = true}) {
    if (autoLoad) load();
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

    _places = _allPlaces.where((p) {
      if (_selectedCategoryIds.isNotEmpty &&
          !p.categories.any((c) => _selectedCategoryIds.contains(c.id))) {
        return false;
      }
      return tokens.every(p.searchText.contains);
    }).toList(growable: false);

    // Địa điểm đang chọn trên bản đồ không còn trong kết quả thì bỏ chọn
    final selected = _selectedPlace;
    if (selected != null && !_places.any((p) => p.id == selected.id)) {
      _selectedPlace = null;
    }
  }
}
