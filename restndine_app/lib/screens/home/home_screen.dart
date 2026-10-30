import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/place_provider.dart';
import '../auth/login_screen.dart';
import '../profile/profile_screen.dart';
import 'widgets/map_view.dart';
import 'widgets/place_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isMapView = true;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final placeProv = context.watch<PlaceProvider>();
    final authProv = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.primaryGradientEnd],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.restaurant_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('RestNDine'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _isMapView ? 'Chuyển sang dạng Danh sách' : 'Chuyển sang Bản đồ',
            icon: Icon(
              _isMapView ? Icons.view_list_rounded : Icons.map_outlined,
              color: AppTheme.primaryColor,
            ),
            onPressed: () => setState(() => _isMapView = !_isMapView),
          ),
          IconButton(
            tooltip: 'Tài khoản',
            icon: Icon(
              authProv.isAuthenticated ? Icons.account_circle : Icons.account_circle_outlined,
              color: authProv.isAuthenticated ? AppTheme.primaryColor : Colors.grey.shade700,
            ),
            onPressed: () {
              if (authProv.isAuthenticated) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                // Search Input
                TextField(
                  controller: _searchCtrl,
                  onSubmitted: (val) => placeProv.setSearchQuery(val),
                  decoration: InputDecoration(
                    hintText: 'Tìm nhà hàng, khách sạn, quán cafe...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              placeProv.setSearchQuery('');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
                const SizedBox(height: 10),

                // Category Chips List
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      // All Chip
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: const Text('Tất cả'),
                          selected: placeProv.selectedCategoryIds.isEmpty,
                          onSelected: (_) => placeProv.clearCategories(),
                          selectedColor: AppTheme.primaryColor.withOpacity(0.15),
                          checkmarkColor: AppTheme.primaryColor,
                          labelStyle: TextStyle(
                            color: placeProv.selectedCategoryIds.isEmpty
                                ? AppTheme.primaryColor
                                : AppTheme.textPrimary,
                            fontWeight: placeProv.selectedCategoryIds.isEmpty
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      // Dynamic Categories
                      ...placeProv.categories.map((cat) {
                        final isSel = placeProv.selectedCategoryIds.contains(cat.id);
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text('${cat.icon ?? ""} ${cat.name}'.trim()),
                            selected: isSel,
                            onSelected: (_) => placeProv.toggleCategory(cat.id),
                            selectedColor: AppTheme.primaryColor.withOpacity(0.15),
                            checkmarkColor: AppTheme.primaryColor,
                            labelStyle: TextStyle(
                              color: isSel ? AppTheme.primaryColor : AppTheme.textPrimary,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main View Body: Map or List
          Expanded(
            child: placeProv.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _isMapView
                    ? InteractiveMapView(
                        places: placeProv.places,
                        selectedPlace: placeProv.selectedPlace,
                        onPlaceSelected: (p) => placeProv.selectPlace(p),
                      )
                    : RefreshIndicator(
                        onRefresh: () => placeProv.loadPlaces(),
                        child: placeProv.places.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade400),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Không tìm thấy địa điểm phù hợp',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: placeProv.places.length,
                                itemBuilder: (context, index) {
                                  return PlaceCard(place: placeProv.places[index]);
                                },
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}
