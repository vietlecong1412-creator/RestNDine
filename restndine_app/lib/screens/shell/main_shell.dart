import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/place_provider.dart';
import '../../widgets/place_image.dart';
import '../home/explore_screen.dart';
import '../map/map_screen.dart';
import '../profile/profile_screen.dart';

/// Tab đang mở của thanh điều hướng dưới; màn hình con gọi [go] để chuyển tab.
/// Bản đồ là màn hình chính (app gợi ý quán quanh bạn) nên đứng đầu và mở khi khởi động.
class ShellController extends ChangeNotifier {
  static const map = 0;
  static const explore = 1;
  static const account = 2;

  int _index = map;
  int get index => _index;

  void go(int index) {
    if (index == _index) return;
    _index = index;
    notifyListeners();
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  /// Chờ dữ liệu tải xong và yên một lúc rồi mới dựng sẵn tab Khám phá ở chế độ ẩn.
  static const _explorePrewarmDelay = Duration(seconds: 2);

  // Tab Khám phá không dựng lúc khởi động để không tranh mạng với tile bản đồ
  final Set<int> _visited = {ShellController.map};
  Timer? _explorePrewarm;

  @override
  void initState() {
    super.initState();
    // Hỏi quyền vị trí ngay khi mở app (sau khung hình đầu để hộp thoại hiện trên nền bản đồ);
    // đã cấp từ trước thì chỉ lấy vị trí, đã chặn hẳn thì không làm phiền
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<LocationProvider>().startup();
      // Giải mã sẵn ảnh minh hoạ để thẻ địa điểm đầu tiên cũng có ảnh ngay khi chạm
      PlaceImage.precacheFallbacks(context);
    });
  }

  @override
  void dispose() {
    _explorePrewarm?.cancel();
    super.dispose();
  }

  /// Dựng sẵn tab Khám phá (ẩn trong IndexedStack): ảnh các thẻ đầu tiên được tải trong lúc
  /// người dùng xem bản đồ, nên lần đầu chuyển tab là có ngay.
  void _schedulePrewarm(bool placesLoaded) {
    if (!placesLoaded || _explorePrewarm != null || _visited.contains(ShellController.explore)) return;
    _explorePrewarm = Timer(_explorePrewarmDelay, () {
      if (mounted) setState(() => _visited.add(ShellController.explore));
    });
  }

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<ShellController>();
    _visited.add(nav.index);
    _schedulePrewarm(context.select<PlaceProvider, bool>((p) => p.hasLoaded));

    return PopScope(
      // Nút Back của Android quay về tab Bản đồ trước khi thoát app
      canPop: nav.index == ShellController.map,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) nav.go(ShellController.map);
      },
      child: Scaffold(
        body: IndexedStack(
          index: nav.index,
          children: [
            const MapScreen(),
            _visited.contains(ShellController.explore) ? const ExploreScreen() : const SizedBox.shrink(),
            const ProfileScreen(),
          ],
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: NavigationBar(
            selectedIndex: nav.index,
            onDestinationSelected: (i) {
              // Ô tìm kiếm ở tab bị ẩn vẫn giữ focus nên phải đóng bàn phím khi đổi tab
              FocusManager.instance.primaryFocus?.unfocus();
              nav.go(i);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.map_outlined),
                selectedIcon: Icon(Icons.map_rounded),
                label: 'Bản đồ',
              ),
              NavigationDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore_rounded),
                label: 'Khám phá',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Tài khoản',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
