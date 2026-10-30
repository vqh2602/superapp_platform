import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/animations/app_motion.dart';
import '../../../../core/config/debug_mode_provider.dart';
import '../../../../core/config/endpoint_config.dart';
import '../../../../core/widgets/backend_endpoint_selector_sheet.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../data/mini_app_repository.dart';
import '../../domain/mini_app_manifest.dart';
import '../widgets/app_list_item.dart';

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
    final allApps = catalogAsync.value ?? [];

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
                child: FadeSlideIn(
                  delay: const Duration(milliseconds: 50),
                  child: BouncingTap(
                    onTap: () {
                      if (onNavigateToSearch != null) {
                        onNavigateToSearch!();
                      } else {
                        context.push('/search');
                      }
                    },
                    scaleFactor: 0.98,
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
              ),

              // 3. PROMO BANNER CAROUSEL
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: FadeSlideIn(
                  delay: Duration(milliseconds: 100),
                  child: AnimatedHomeBanner(),
                ),
              ),

              // 4. QUICK SERVICE CATEGORIES
              FadeSlideIn(
                delay: const Duration(milliseconds: 150),
                child: _buildQuickServices(context),
              ),

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
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () async {
                              await ref.read(backendEndpointProvider.notifier).setEndpoint(EndpointConfig.alwaysdataEndpoint);
                              ref.invalidate(dynamicCatalogProvider);
                              ref.invalidate(catalogCategoriesProvider);
                            },
                            icon: const Icon(Icons.cloud_rounded, size: 16),
                            label: const Text('Alwaysdata Cloud'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () async {
                              await ref.read(backendEndpointProvider.notifier).setEndpoint(EndpointConfig.localhostEndpoint);
                              ref.invalidate(dynamicCatalogProvider);
                              ref.invalidate(catalogCategoriesProvider);
                            },
                            icon: const Icon(Icons.computer_rounded, size: 16),
                            label: const Text('Localhost (3000)'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => showBackendEndpointSelectorSheet(context, ref),
                            icon: const Icon(Icons.edit_rounded, size: 16),
                            label: const Text('Nhập endpoint riêng'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () {
                          ref.invalidate(dynamicCatalogProvider);
                          ref.invalidate(catalogCategoriesProvider);
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Thử lại kết nối hiện tại'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
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
                    children: List.generate(allApps.length, (index) {
                      return FadeSlideIn(
                        delay: Duration(milliseconds: 30 * index),
                        child: AppListItem(app: allApps[index]),
                      );
                    }),
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
          BouncingTap(
            onTap: () => context.push('/profile'),
            scaleFactor: 0.92,
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
              borderRadius: BorderRadius.circular(8),
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
                      const PulseEffect(
                        minScale: 0.95,
                        maxScale: 1.05,
                        duration: Duration(milliseconds: 1600),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xFFECFDF5),
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            child: Text(
                              'VIP',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF059669),
                              ),
                            ),
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
          IconButton(
            tooltip: 'Chọn Backend Endpoint (Alwaysdata / Localhost / Custom)',
            icon: const Icon(Icons.dns_rounded, color: Color(0xFF0284C7), size: 22),
            onPressed: () => showBackendEndpointSelectorSheet(context, ref),
          ),
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

  Widget _buildQuickServices(BuildContext context) {
    final services = [
      {'name': 'Quét QR', 'icon': Icons.qr_code_scanner_rounded, 'color': const Color(0xFF0068FF), 'appId': 'flutter_scanner'},
      {'name': 'Đồ uống', 'icon': Icons.coffee_rounded, 'color': const Color(0xFFF59E0B), 'appId': 'sample_store'},
      {'name': 'Mua sắm', 'icon': Icons.shopping_bag_rounded, 'color': const Color(0xFFEE4D2D), 'appId': 'shopee'},
      {'name': 'Playground', 'icon': Icons.code_rounded, 'color': const Color(0xFF2563EB), 'appId': 'sdk_playground'},
      {'name': 'Giải trí', 'icon': Icons.play_arrow_rounded, 'color': const Color(0xFFFF0000), 'appId': 'youtube'},
      {'name': 'Video ngắn', 'icon': Icons.music_note_rounded, 'color': const Color(0xFF010101), 'appId': 'tiktok'},
      {'name': 'Trò chơi', 'icon': Icons.sports_esports_rounded, 'color': const Color(0xFF10B981), 'appId': 'free_fire'},
      {'name': 'Chụp ảnh', 'icon': Icons.camera_alt_rounded, 'color': const Color(0xFF8B5CF6), 'appId': 'capcut'},
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
          return FadeSlideIn(
            delay: Duration(milliseconds: 25 * index),
            child: BouncingTap(
              onTap: () => context.push('/miniapp/${s['appId']}'),
              scaleFactor: 0.88,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: (s['color'] as Color).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: (s['color'] as Color).withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
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
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeaturedHorizontal(BuildContext context, List<MiniAppManifest> apps) {
    return SizedBox(
      height: 126,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: apps.length > 5 ? 5 : apps.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final app = apps[index];
          return FadeSlideIn(
            direction: Axis.horizontal,
            delay: Duration(milliseconds: 40 * index),
            child: BouncingTap(
              onTap: () => context.push('/miniapp/${app.id}'),
              scaleFactor: 0.96,
              child: Container(
                width: 220,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
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
              ),
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

class AnimatedHomeBanner extends StatefulWidget {
  final VoidCallback? onTap;

  const AnimatedHomeBanner({super.key, this.onTap});

  @override
  State<AnimatedHomeBanner> createState() => _AnimatedHomeBannerState();
}

class _AnimatedHomeBannerState extends State<AnimatedHomeBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _floatAnim;
  late final Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _floatAnim = Tween<double>(begin: -4.0, end: 4.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _glowAnim = Tween<double>(begin: 0.15, end: 0.4).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          height: 154,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F2744)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF38BDF8).withValues(alpha: _glowAnim.value * 0.8),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withValues(alpha: _glowAnim.value),
                blurRadius: 18,
                spreadRadius: 1,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00BA52).withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF00BA52).withValues(alpha: 0.4),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF00E676),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'SUPERAPP PLATFORM',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF00E676),
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Hệ sinh thái Mini App',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Mở ngay ứng dụng tức thì không cần cài đặt.',
                      style: TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Transform.translate(
                offset: Offset(0, _floatAnim.value),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF2563EB).withValues(alpha: 0.3),
                        const Color(0xFF00BA52).withValues(alpha: 0.2),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00BA52).withValues(alpha: _glowAnim.value),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.rocket_launch_rounded,
                    color: Color(0xFF00E676),
                    size: 40,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
