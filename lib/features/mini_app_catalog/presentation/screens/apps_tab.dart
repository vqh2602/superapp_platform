import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/animations/app_motion.dart';
import '../../data/mini_app_repository.dart';
import '../../domain/mini_app_manifest.dart';
import '../widgets/app_list_item.dart';
import '../widgets/category_catalog_grid.dart';

class AppsTab extends ConsumerStatefulWidget {
  final VoidCallback? onNavigateToSearch;

  const AppsTab({
    super.key,
    this.onNavigateToSearch,
  });

  @override
  ConsumerState<AppsTab> createState() => _AppsTabState();
}

class _AppsTabState extends ConsumerState<AppsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedCategoryFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _goToSearch() {
    if (widget.onNavigateToSearch != null) {
      widget.onNavigateToSearch!();
    } else {
      context.push('/search');
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(dynamicCatalogProvider);
    final allApps = catalogAsync.value ?? [];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Ứng dụng',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        actions: [
          // Search Icon Button
          IconButton(
            tooltip: 'Tìm kiếm',
            icon: const Icon(Icons.search_rounded, size: 26, color: Color(0xFF0F172A)),
            onPressed: _goToSearch,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                isScrollable: false,
                indicatorColor: const Color(0xFF00BA52),
                indicatorWeight: 3.0,
                indicatorSize: TabBarIndicatorSize.label,
                labelColor: const Color(0xFF0F172A),
                unselectedLabelColor: const Color(0xFF64748B),
                labelStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                tabs: const [
                  Tab(text: 'Đề xuất'),
                  Tab(text: 'Cần thiết'),
                  Tab(text: 'Mới nhất'),
                  Tab(text: 'Phân loại'),
                ],
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Đề xuất (Recommended)
          _buildAppList(allApps),

          // Tab 2: Cần thiết (Essential)
          _buildAppList(allApps.reversed.toList()),

          // Tab 3: Mới nhất (Latest)
          _buildAppList(allApps),

          // Tab 4: Phân loại (Categories Grid matching Image 3)
          _buildCategoriesView(allApps),
        ],
      ),
    );
  }

  Widget _buildAppList(List<MiniAppManifest> apps) {
    if (apps.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.apps_outlined, color: Color(0xFF94A3B8), size: 44),
              const SizedBox(height: 12),
              const Text(
                'Không có ứng dụng nào từ Backend',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 6),
              const Text(
                'Danh sách được nạp trực tiếp từ Backend Registry.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(dynamicCatalogProvider),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Tải lại'),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: apps.length,
      separatorBuilder: (_, __) => const Padding(
        padding: EdgeInsets.only(left: 84, right: 16),
        child: Divider(height: 1, color: Color(0xFFF8FAFC)),
      ),
      itemBuilder: (context, index) {
        return FadeSlideIn(
          delay: Duration(milliseconds: 25 * index),
          child: AppListItem(app: apps[index]),
        );
      },
    );
  }

  Widget _buildCategoriesView(List<MiniAppManifest> allApps) {
    if (_selectedCategoryFilter != null) {
      final filtered = allApps.where((a) =>
          a.category.toLowerCase().contains(_selectedCategoryFilter!.toLowerCase()) ||
          _selectedCategoryFilter!.toLowerCase().contains(a.category.toLowerCase())).toList();

      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFFF8FAFC),
            child: Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.arrow_back, size: 16),
                  label: Text('Tất cả danh mục / $_selectedCategoryFilter'),
                  onPressed: () {
                    setState(() {
                      _selectedCategoryFilter = null;
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      'Chưa có Mini App nào trong danh mục này',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  )
                : _buildAppList(filtered),
          ),
        ],
      );
    }

    return ListView(
      children: [
        CategoryCatalogGrid(
          onCategorySelected: (cat) {
            setState(() {
              _selectedCategoryFilter = cat.label;
            });
          },
        ),
      ],
    );
  }
}
