import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/home_tab.dart';
import 'screens/apps_tab.dart';
import 'screens/games_tab.dart';
import 'screens/search_screen.dart';
import 'screens/profile_tab.dart';

class MiniAppCatalogScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;

  const MiniAppCatalogScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<MiniAppCatalogScreen> createState() => _MiniAppCatalogScreenState();
}

class _MiniAppCatalogScreenState extends ConsumerState<MiniAppCatalogScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
  }

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeTab(onNavigateToSearch: () => _onTabSelected(3)),
      AppsTab(onNavigateToSearch: () => _onTabSelected(3)),
      GamesTab(onNavigateToSearch: () => _onTabSelected(3)),
      SearchScreen(
        showBackButton: false,
        onBack: () => _onTabSelected(0),
      ),
      const ProfileTab(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabSelected,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: const Color(0xFF00BA52),
          unselectedItemColor: const Color(0xFF64748B),
          selectedFontSize: 11,
          unselectedFontSize: 11,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: AnimatedScale(
                scale: 1.14,
                duration: Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                child: Icon(Icons.home_rounded),
              ),
              label: 'Trang chủ',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_outlined),
              activeIcon: AnimatedScale(
                scale: 1.14,
                duration: Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                child: Icon(Icons.grid_view_rounded),
              ),
              label: 'Ứng dụng',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.sports_esports_outlined),
              activeIcon: AnimatedScale(
                scale: 1.14,
                duration: Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                child: Icon(Icons.sports_esports_rounded),
              ),
              label: 'Trò chơi',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.search_rounded),
              activeIcon: AnimatedScale(
                scale: 1.14,
                duration: Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                child: Icon(Icons.search_rounded),
              ),
              label: 'Tìm kiếm',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: AnimatedScale(
                scale: 1.14,
                duration: Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                child: Icon(Icons.person_rounded),
              ),
              label: 'Của tôi',
            ),
          ],
        ),
      ),
    );
  }
}
