import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../data/mini_app_repository.dart';
import '../../domain/mini_app_manifest.dart';
import '../widgets/app_list_item.dart';
import '../../../../core/config/debug_mode_provider.dart';

class HomeTab extends ConsumerWidget {
  final VoidCallback? onNavigateToSearch;

  const HomeTab({
    super.key,
    this.onNavigateToSearch,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.currentUser;
    final catalogAsync = ref.watch(dynamicCatalogProvider);
    final allApps = catalogAsync.valueOrNull ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(miniAppRepositoryProvider).getPublishedMiniApps(
              forceRefresh: true,
            );
            ref.invalidate(dynamicCatalogProvider);
            ref.invalidate(catalogCategoriesProvider);
            await ref.read(dynamicCatalogProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              // 1. HEADER: TÀI KHOẢN (Account Header)
              _buildAccountHeader(context, ref, user),

              // 2. SEARCH BAR SHORTCUT
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: InkWell(
                  onTap: () {
                    if (onNavigateToSearch != null) {
                      onNavigateToSearch!();
                    } else {
                      context.push('/search');
                    }
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 22),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Tìm kiếm ứng dụng hoặc trò chơi...',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. PROMO BANNER CAROUSEL
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildBanner(context),
              ),

              // 4. QUICK SERVICE CATEGORIES
              _buildQuickServices(context),

              const SizedBox(height: 16),

              // 5. ỨNG DỤNG NỔI BẬT (Featured Mini Apps)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Ứng dụng nổi bật',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // Switch to Ứng dụng tab if needed
                      },
                      child: const Row(
                        children: [
                          Text('Xem tất cả', style: TextStyle(color: Color(0xFF00BA52), fontSize: 13, fontWeight: FontWeight.bold)),
                          Icon(Icons.chevron_right, size: 16, color: Color(0xFF00BA52)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (catalogAsync.isLoading && allApps.isEmpty) ...[
                const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF00BA52)),
                  ),
                ),
              ] else if (catalogAsync.hasError && allApps.isEmpty) ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.cloud_off_rounded, color: Color(0xFFDC2626), size: 36),
                      const SizedBox(height: 8),
                      const Text(
                        'Không thể tải Mini App từ Backend',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF991B1B), fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${catalogAsync.error}'.replaceFirst('Exception: ', ''),
                        style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          ref.invalidate(dynamicCatalogProvider);
                          ref.invalidate(catalogCategoriesProvider);
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Thử lại'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (allApps.isEmpty) ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.inbox_outlined, color: Color(0xFF94A3B8), size: 40),
                      const SizedBox(height: 8),
                      const Text(
                        'Chưa có Mini App nào từ Backend',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Danh sách Mini App lấy trực tiếp từ Backend Registry. Hãy tải lên và publish qua Manager.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          ref.invalidate(dynamicCatalogProvider);
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Tải lại'),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                _buildFeaturedHorizontal(context, allApps),

                const SizedBox(height: 16),

                // 6. DANH SÁCH MINI APP ĐƯỢC ĐỀ XUẤT (List with only Name + Description, "Mở" button)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: const Text(
                    'Khám phá Mini Apps',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: allApps.map((app) {
                      return AppListItem(app: app);
                    }).toList(),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // 7. ARCHITECTURE INFO
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildArchitectureCard(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountHeader(BuildContext context, WidgetRef ref, dynamic user) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          InkWell(
            onTap: () => context.push('/profile'),
            child: CircleAvatar(
              radius: 26,
              backgroundColor: const Color(0xFF2563EB),
              child: Text(
                user != null && user.name.isNotEmpty ? user.name[0] : '?',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // User Info
          Expanded(
            child: InkWell(
              onTap: () => context.push('/profile'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user?.name ?? 'Tài khoản khách',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'VIP',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00BA52),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          user != null ? 'ID: ${user.id} • ${user.role}' : 'Chưa đăng nhập',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Header Quick Actions
          if (ref.watch(isDebugModeEnabledProvider))
            IconButton(
              tooltip: 'Debug Logs',
              icon: const Icon(Icons.bug_report_outlined, color: Color(0xFF64748B), size: 22),
              onPressed: () => context.push('/debug'),
            ),
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 22),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Đăng xuất'),
                  content: const Text('Bạn có chắc muốn đăng xuất khỏi Super App?'),
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
    );
  }

  Widget _buildBanner(BuildContext context) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00BA52).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'SUPER APP PLATFORM',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00BA52),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Hệ sinh thái Mini App',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Mở ngay ứng dụng tức thì không cần cài đặt.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.rocket_launch_rounded, color: Color(0xFF00BA52), size: 36),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickServices(BuildContext context) {
    final services = [
      {'name': 'Đồ uống', 'icon': Icons.coffee_rounded, 'color': const Color(0xFFF59E0B), 'appId': 'sample_store'},
      {'name': 'Mua sắm', 'icon': Icons.shopping_bag_rounded, 'color': const Color(0xFFEE4D2D), 'appId': 'shopee'},
      {'name': 'Playground', 'icon': Icons.code_rounded, 'color': const Color(0xFF2563EB), 'appId': 'sdk_playground'},
      {'name': 'Giải trí', 'icon': Icons.play_arrow_rounded, 'color': const Color(0xFFFF0000), 'appId': 'youtube'},
      {'name': 'Video ngắn', 'icon': Icons.music_note_rounded, 'color': const Color(0xFF010101), 'appId': 'tiktok'},
      {'name': 'Trò chơi', 'icon': Icons.sports_esports_rounded, 'color': const Color(0xFF10B981), 'appId': 'free_fire'},
      {'name': 'Chụp ảnh', 'icon': Icons.camera_alt_rounded, 'color': const Color(0xFF8B5CF6), 'appId': 'capcut'},
      {'name': 'Mạng XH', 'icon': Icons.forum_rounded, 'color': const Color(0xFF0084FF), 'appId': 'messenger'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 12,
          crossAxisSpacing: 10,
          childAspectRatio: 0.9,
        ),
        itemCount: services.length,
        itemBuilder: (context, index) {
          final s = services[index];
          return InkWell(
            onTap: () => context.push('/miniapp/${s['appId']}'),
            borderRadius: BorderRadius.circular(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: (s['color'] as Color).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(s['icon'] as IconData, color: s['color'] as Color, size: 24),
                ),
                const SizedBox(height: 6),
                Text(
                  s['name'] as String,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeaturedHorizontal(BuildContext context, List<MiniAppManifest> apps) {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: apps.length > 5 ? 5 : apps.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final app = apps[index];
          return Container(
            width: 220,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: app.icon.startsWith('http://') || app.icon.startsWith('https://')
                        ? Image.network(app.icon, fit: BoxFit.cover,
                            errorBuilder: (_, error, stackTrace) => const Icon(Icons.apps_rounded, color: Color(0xFF2563EB), size: 24))
                        : const Icon(Icons.apps_rounded, color: Color(0xFF2563EB), size: 24),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        app.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        app.category,
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                        maxLines: 1,
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 24,
                        child: ElevatedButton(
                          onPressed: () => context.push('/miniapp/${app.id}'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00BA52),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          child: const Text('Mở'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildArchitectureCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.layers_outlined, color: Color(0xFF00BA52), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Kiến trúc Siêu Ứng Dụng (Dynamic Registry)',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            'Mini Apps được publish qua Registry. Client tự động nạp và thực thi runtime mà không cần build lại ứng dụng native.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
          ),
        ],
      ),
    );
  }
}
