import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../home/explore_screen.dart';
import '../map/map_screen.dart';
import '../profile/profile_screen.dart';

/// Tab đang mở của thanh điều hướng dưới; màn hình con gọi [go] để chuyển tab.
class ShellController extends ChangeNotifier {
  static const explore = 0;
  static const map = 1;
  static const account = 2;

  int _index = explore;
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
  // Bản đồ chỉ dựng khi mở tab lần đầu để không tải tile lúc khởi động
  final Set<int> _visited = {ShellController.explore};

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<ShellController>();
    _visited.add(nav.index);

    return PopScope(
      // Nút Back của Android quay về tab Khám phá trước khi thoát app
      canPop: nav.index == ShellController.explore,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) nav.go(ShellController.explore);
      },
      child: Scaffold(
        body: IndexedStack(
          index: nav.index,
          children: [
            const ExploreScreen(),
            _visited.contains(ShellController.map) ? const MapScreen() : const SizedBox.shrink(),
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
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore_rounded),
                label: 'Khám phá',
              ),
              NavigationDestination(
                icon: Icon(Icons.map_outlined),
                selectedIcon: Icon(Icons.map_rounded),
                label: 'Bản đồ',
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
