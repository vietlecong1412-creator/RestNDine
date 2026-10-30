import 'package:flutter/material.dart';
import '../models/category_model.dart';
import '../models/place_model.dart';
import '../services/place_service.dart';

class PlaceProvider extends ChangeNotifier {
  final PlaceService _placeService = PlaceService();

  List<CategoryModel> _categories = [];
  List<PlaceModel> _places = [];
  final Set<int> _selectedCategoryIds = {};
  String _searchQuery = '';
  PlaceModel? _selectedPlace;
  bool _isLoading = false;

  List<CategoryModel> get categories => _categories;
  List<PlaceModel> get places => _places;
  Set<int> get selectedCategoryIds => _selectedCategoryIds;
  String get searchQuery => _searchQuery;
  PlaceModel? get selectedPlace => _selectedPlace;
  bool get isLoading => _isLoading;

  PlaceProvider() {
    init();
  }

  Future<void> init() async {
    await loadCategories();
    await loadPlaces();
  }

  Future<void> loadCategories() async {
    _categories = await _placeService.getCategories();
    notifyListeners();
  }

  Future<void> loadPlaces() async {
    _isLoading = true;
    notifyListeners();

    try {
      _places = await _placeService.getPlaces(
        search: _searchQuery,
        categoryIds: _selectedCategoryIds.toList(),
      );
    } catch (_) {
      _places = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void toggleCategory(int categoryId) {
    if (_selectedCategoryIds.contains(categoryId)) {
      _selectedCategoryIds.remove(categoryId);
    } else {
      _selectedCategoryIds.add(categoryId);
    }
    notifyListeners();
    loadPlaces();
  }

  void clearCategories() {
    _selectedCategoryIds.clear();
    notifyListeners();
    loadPlaces();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
    loadPlaces();
  }

  void selectPlace(PlaceModel? place) {
    _selectedPlace = place;
    notifyListeners();
  }
}
