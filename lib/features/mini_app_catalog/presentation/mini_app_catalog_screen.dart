import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/mini_app_repository.dart';
import '../domain/mini_app_manifest.dart';
import '../../authentication/presentation/controllers/auth_controller.dart';
import '../../../../core/config/app_theme.dart';

class MiniAppCatalogScreen extends ConsumerStatefulWidget {
  const MiniAppCatalogScreen({super.key});

  @override
  ConsumerState<MiniAppCatalogScreen> createState() => _MiniAppCatalogScreenState();
}

class _MiniAppCatalogScreenState extends ConsumerState<MiniAppCatalogScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.currentUser;
    final dynamicCatalog = ref.watch(dynamicCatalogProvider);
    final categoriesAsync = ref.watch(catalogCategoriesProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Super App Platform'),
        actions: [
          IconButton(
            tooltip: 'Làm mới danh mục',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(dynamicCatalogProvider);
              ref.invalidate(catalogCategoriesProvider);
            },
          ),
          IconButton(
            tooltip: 'Debug Logs',
            icon: const Icon(Icons.bug_report_outlined),
            onPressed: () => context.push('/debug'),
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout_rounded, color: Colors.red),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Đăng xuất'),
                  content: const Text(
                      'Bạn có chắc muốn đăng xuất phiên hiện tại? Các Mini App đang mở sẽ bị thu hồi quyền.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Hủy'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Đăng xuất'),
                    ),
                  ],
                ),
              );

              if (confirm == true && context.mounted) {
                await ref.read(authStateProvider.notifier).logout();
                if (context.mounted) {
                  context.go('/login');
                }
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dynamicCatalogProvider);
          ref.invalidate(catalogCategoriesProvider);
          await ref.read(dynamicCatalogProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Active User Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.primary,
                    child: Text(
                      user != null ? user.name[0] : '?',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'Chưa đăng nhập',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: ${user?.id ?? 'N/A'} • Role: ${user?.role ?? 'N/A'}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppTheme.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Master Session Active',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Search Bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm Mini App theo tên hoặc mô tả...',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(catalogSearchQueryProvider.notifier).state = '';
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              onChanged: (val) {
                ref.read(catalogSearchQueryProvider.notifier).state = val;
              },
            ),
            const SizedBox(height: 14),

            // Category Filter Chips
            categoriesAsync.when(
              data: (categories) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: categories.map((cat) {
                    final isSelected = selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        label: Text(cat),
                        selected: isSelected,
                        onSelected: (_) {
                          ref.read(selectedCategoryProvider.notifier).state = cat;
                        },
                        selectedColor: AppTheme.primary.withValues(alpha: 0.15),
                        checkmarkColor: AppTheme.primary,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? AppTheme.primary : const Color(0xFF475569),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              loading: () => const SizedBox(height: 32),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),

            // Section Header
            Row(
              children: [
                const Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.widgets_rounded, size: 20, color: AppTheme.primary),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'DANH SÁCH MINI APPS ĐƯỢC DUYỆT',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: Color(0xFF475569),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_sync_outlined, size: 14, color: AppTheme.primary),
                      SizedBox(width: 4),
                      Text(
                        'Dynamic Registry',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Dynamic Mini Apps List
            dynamicCatalog.when(
              data: (apps) {
                if (apps.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.inbox_outlined, size: 44, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 12),
                        const Text(
                          'Không tìm thấy Mini App nào phù hợp',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Thử xóa bộ lọc tìm kiếm hoặc kéo xuống để làm mới danh mục.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: () {
                            _searchController.clear();
                            ref.read(catalogSearchQueryProvider.notifier).state = '';
                            ref.read(selectedCategoryProvider.notifier).state = 'All';
                          },
                          child: const Text('Xem tất cả'),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: apps.map((app) => _buildAppCard(context, app)).toList(),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(strokeWidth: 2.5),
                      SizedBox(height: 12),
                      Text('Đang nạp danh mục Mini App động...', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ),
              error: (err, _) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Lỗi kết nối Registry: $err',
                        style: const TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    ),
                    TextButton(
                      onPressed: () => ref.invalidate(dynamicCatalogProvider),
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Super App Architecture Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.layers_outlined, color: AppTheme.primary, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Kiến trúc Nền tảng Động (Dynamic Architecture)',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Mini Apps được publish động qua Registry API. Master App tự động fetch và render mà không cần rebuild APK/IPA.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildTag('FVM 3.41.9'),
                      _buildTag('NestJS Monolith'),
                      _buildTag('PostgreSQL Registry'),
                      _buildTag('Dynamic Catalog'),
                      _buildTag('Type A: Web'),
                      _buildTag('Type B: Schema No-Code'),
                      _buildTag('Zero Rebuild'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppCard(BuildContext context, MiniAppManifest app) {
    final isPlayground = app.id == 'sdk_playground';
    final isSchema = app.isSchemaApp;

    IconData appIcon;
    switch (app.icon) {
      case 'code':
        appIcon = Icons.code_rounded;
        break;
      case 'storefront':
      case 'store':
        appIcon = Icons.storefront_rounded;
        break;
      case 'coffee':
      case 'cafe':
        appIcon = Icons.coffee_rounded;
        break;
      case 'shopping':
        appIcon = Icons.shopping_bag_rounded;
        break;
      default:
        appIcon = Icons.apps_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPlayground ? AppTheme.primary.withValues(alpha: 0.4) : const Color(0xFFE2E8F0),
          width: isPlayground ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isPlayground
                        ? AppTheme.primary.withValues(alpha: 0.1)
                        : (isSchema ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    appIcon,
                    color: isPlayground
                        ? AppTheme.primary
                        : (isSchema ? const Color(0xFF059669) : const Color(0xFF475569)),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              app.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2F6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'v${app.version}',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isSchema ? const Color(0xFFD1FAE5) : const Color(0xFFE0E7FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isSchema ? 'NO-CODE' : 'WEB',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isSchema ? const Color(0xFF047857) : const Color(0xFF4338CA),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        app.description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            app.category,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${app.capabilities.length} caps',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    context.push('/miniapp/${app.id}');
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: Text(isPlayground ? 'Playground' : 'Mở App'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPlayground
                        ? AppTheme.primary
                        : (isSchema ? const Color(0xFF059669) : const Color(0xFF334155)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
      ),
    );
  }
}
