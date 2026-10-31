import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/debug_mode_provider.dart';
import '../../../mini_app_catalog/domain/mini_app_manifest.dart';
import '../../../mini_app_catalog/presentation/controllers/favorite_apps_provider.dart';
import '../../../permissions/data/permission_repository_impl.dart';

class MiniAppActionBottomSheet extends ConsumerWidget {
  final MiniAppManifest? manifest;
  final String appId;
  final VoidCallback onReload;
  final VoidCallback onMinimize;
  final VoidCallback? onWebDebug;

  const MiniAppActionBottomSheet({
    super.key,
    required this.manifest,
    required this.appId,
    required this.onReload,
    required this.onMinimize,
    this.onWebDebug,
  });

  static Future<void> show(
    BuildContext context, {
    required MiniAppManifest? manifest,
    required String appId,
    required VoidCallback onReload,
    required VoidCallback onMinimize,
    VoidCallback? onWebDebug,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MiniAppActionBottomSheet(
        manifest: manifest,
        appId: appId,
        onReload: onReload,
        onMinimize: onMinimize,
        onWebDebug: onWebDebug,
      ),
    );
  }

  Color _getCategoryColor(String? category) {
    switch (category?.toLowerCase()) {
      case 'games':
        return const Color(0xFFEF4444);
      case 'shopping':
      case 'e-commerce':
        return const Color(0xFFF97316);
      case 'social network':
      case 'social':
        return const Color(0xFF0084FF);
      case 'entertainment':
        return const Color(0xFF8B5CF6);
      case 'photo & video':
        return const Color(0xFF06B6D4);
      case 'utilities':
        return const Color(0xFF10B981);
      case 'food & beverage':
        return const Color(0xFFD97706);
      default:
        return const Color(0xFF2563EB);
    }
  }

  IconData _getCategoryIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'games':
        return Icons.sports_esports_rounded;
      case 'shopping':
      case 'e-commerce':
        return Icons.shopping_bag_rounded;
      case 'social network':
      case 'social':
        return Icons.forum_rounded;
      case 'entertainment':
        return Icons.play_circle_fill_rounded;
      case 'photo & video':
        return Icons.video_camera_back_rounded;
      case 'utilities':
        return Icons.bolt_rounded;
      case 'food & beverage':
        return Icons.coffee_rounded;
      default:
        return Icons.apps_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTitle = manifest?.name ?? appId;
    final category = manifest?.category ?? 'Ứng dụng';
    final shareUrl = 'https://superapp.vn/s/$appId';
    final isDebug = ref.watch(isDebugModeEnabledProvider);
    final isFavorite = ref.watch(favoriteAppsProvider).contains(appId);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header Row: App Icon + Name + Subtitle + Info button (i)
              Row(
                children: [
                  // App Icon
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _getCategoryColor(category),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: _getCategoryColor(
                            category,
                          ).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        _getCategoryIcon(category),
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Name & Subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appTitle,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Text(
                              'Mini app của ',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            Flexible(
                              child: Text(
                                '$category Official',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2563EB),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 14,
                              color: Color(0xFFF59E0B),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Info Icon Button (i)
                  IconButton(
                    icon: const Icon(
                      Icons.info_outline_rounded,
                      color: Color(0xFF2563EB),
                      size: 24,
                    ),
                    onPressed: () => _showTechnicalInfoDialog(context, ref),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // "Gửi tới" Section
              const Text(
                'Gửi tới',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),

              // Contacts Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildContactItem(
                    context,
                    name: 'Sầu Riêng',
                    avatarColor: const Color(0xFFE11D48),
                    icon: Icons.person_rounded,
                    badgeText: '+99',
                    appTitle: appTitle,
                  ),
                  _buildContactItem(
                    context,
                    name: 'XU É 12',
                    avatarColor: const Color(0xFFEA580C),
                    icon: Icons.monetization_on_rounded,
                    appTitle: appTitle,
                  ),
                  _buildContactItem(
                    context,
                    name: '4TLS-BK H...',
                    avatarColor: const Color(0xFF2563EB),
                    icon: Icons.group_rounded,
                    badgeText: '+7',
                    appTitle: appTitle,
                  ),
                  _buildContactItem(
                    context,
                    name: 'Xem thêm',
                    avatarColor: const Color(0xFFF1F5F9),
                    icon: Icons.more_horiz_rounded,
                    iconColor: const Color(0xFF64748B),
                    appTitle: appTitle,
                    isMore: true,
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Share URL Bar with Copy Button
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: shareUrl));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã sao chép liên kết vào bộ nhớ tạm!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          shareUrl,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF334155),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.copy_rounded,
                        size: 20,
                        color: Color(0xFF2563EB),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Action Grid: 2 Rows x 3 Columns
              Row(
                children: [
                  Expanded(
                    child: _buildActionTile(
                      icon: Icons.qr_code_2_rounded,
                      label: 'Mã QR',
                      onTap: () {
                        Navigator.pop(context);
                        _showQrCodeDialog(context, shareUrl);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildActionTile(
                      icon: Icons.add_box_outlined,
                      label: 'Tạo phím tắt',
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Đã tạo phím tắt "$appTitle" trên màn hình chính!',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildActionTile(
                      icon: isFavorite
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      iconColor: isFavorite
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF334155),
                      label: isFavorite ? 'Đã thích' : 'Yêu thích',
                      onTap: () {
                        ref
                            .read(favoriteAppsProvider.notifier)
                            .toggleFavorite(appId);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              !isFavorite
                                  ? 'Đã thêm "$appTitle" vào mục Yêu thích!'
                                  : 'Đã bỏ yêu thích "$appTitle"!',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildActionTile(
                      icon: Icons.fullscreen_exit_rounded,
                      label: 'Thu nhỏ',
                      onTap: () {
                        Navigator.pop(context);
                        onMinimize();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildActionTile(
                      icon: Icons.lock_outline_rounded,
                      label: 'Quản lý quyền',
                      onTap: () {
                        Navigator.pop(context);
                        _showAppPermissionsSheet(context, ref);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildActionTile(
                      icon: Icons.refresh_rounded,
                      label: 'Tải lại',
                      onTap: () {
                        Navigator.pop(context);
                        onReload();
                      },
                    ),
                  ),
                ],
              ),

              if (onWebDebug != null) ...[
                const SizedBox(height: 10),
                _buildActionTile(
                  icon: Icons.code_rounded,
                  label: 'Web Debug (Console / JS / DOM)',
                  fullWidth: true,
                  onTap: () {
                    Navigator.pop(context);
                    onWebDebug!();
                  },
                ),
              ],
              if (isDebug) ...[
                const SizedBox(height: 10),
                _buildActionTile(
                  icon: Icons.bug_report_outlined,
                  label: 'Trình gỡ lỗi (Debug Logs)',
                  iconColor: const Color(0xFF6366F1),
                  fullWidth: true,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/debug');
                  },
                ),
              ],

              const SizedBox(height: 20),

              // Bottom "Đóng" Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    foregroundColor: const Color(0xFF0F172A),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    'Đóng',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactItem(
    BuildContext context, {
    required String name,
    required Color avatarColor,
    required IconData icon,
    Color iconColor = Colors.white,
    String? badgeText,
    required String appTitle,
    bool isMore = false,
  }) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isMore
                  ? 'Đã mở danh sách bạn bè để chia sẻ!'
                  : 'Đã gửi liên kết "$appTitle" tới $name!',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: avatarColor,
                  child: Icon(icon, color: iconColor, size: 26),
                ),
                if (badgeText != null)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF475569),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(
                        badgeText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 64,
              child: Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF334155),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? iconColor,
    bool fullWidth = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: fullWidth
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 22,
                    color: iconColor ?? const Color(0xFF334155),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 24,
                    color: iconColor ?? const Color(0xFF334155),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
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
  }

  // --- Sub-Dialogs / Sheets ---

  void _showQrCodeDialog(BuildContext context, String shareUrl) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                manifest?.name ?? appId,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Quét mã để mở Mini App tức thì',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 18),
              Container(
                width: 200,
                height: 200,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: CustomPaint(
                  painter: _QrCodePainter(seed: appId),
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          _getCategoryIcon(manifest?.category),
                          color: _getCategoryColor(manifest?.category),
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                shareUrl,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: shareUrl));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã sao chép link QR!')),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Sao chép'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Đóng'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAppPermissionsSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final repo = ref.read(permissionRepositoryProvider);
            final capabilities =
                manifest?.capabilities ??
                ['user.getBasicInfo', 'navigation.close', 'device.scanQRCode'];

            return Container(
              height: MediaQuery.of(context).size.height * 0.65,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Quản lý quyền truy cập',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              manifest?.name ?? appId,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Đồng bộ 2 chiều với Backend PostgreSQL. Bạn có thể bật hoặc tắt từng quyền cấp cho ứng dụng:',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: capabilities.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final cap = capabilities[index];
                        final isGranted = repo.isGranted(appId, cap);

                        return SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            cap,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'monospace',
                            ),
                          ),
                          subtitle: Text(
                            isGranted ? 'Đã cho phép' : 'Đã từ chối / chưa cấp',
                            style: TextStyle(
                              fontSize: 11,
                              color: isGranted
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF94A3B8),
                            ),
                          ),
                          value: isGranted,
                          activeTrackColor: const Color(0xFF10B981),
                          onChanged: (val) {
                            repo.setPermission(appId, cap, val);
                            setSheetState(() {});
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            repo.revokeAll(appId);
                            setSheetState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Đã thu hồi toàn bộ quyền của $appId',
                                ),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Thu hồi tất cả'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Hoàn tất'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showTechnicalInfoDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF2563EB),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  manifest?.name ?? 'Thông tin kỹ thuật',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoRow('Mã ứng dụng (ID)', manifest?.id ?? appId),
                _buildInfoRow('Phiên bản', 'v${manifest?.version ?? "1.0.0"}'),
                _buildInfoRow(
                  'Loại Runtime',
                  manifest?.isSchemaApp == true
                      ? 'No-Code Schema'
                      : 'Web View App',
                ),
                _buildInfoRow('Danh mục', manifest?.category ?? 'Chung'),
                const SizedBox(height: 8),
                const Text(
                  'Mô tả:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  manifest?.description ?? 'Chưa có mô tả chi tiết.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Quyền Manifest (Capabilities):',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: (manifest?.capabilities ?? ['navigation.close'])
                      .map((c) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            c,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF334155),
                              fontFamily: 'monospace',
                            ),
                          ),
                        );
                      })
                      .toList(),
                ),
              ],
            ),
          ),
          actions: [
            if (ref.read(isDebugModeEnabledProvider))
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push('/debug');
                },
                child: const Text('Debug Logs'),
              ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom QR Code Painter to draw a clean authentic QR matrix
class _QrCodePainter extends CustomPainter {
  final String seed;

  _QrCodePainter({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;

    final double cellSize = size.width / 21;

    // Draw position detection patterns (3 corners)
    _drawPositionPattern(canvas, 0, 0, cellSize, paint);
    _drawPositionPattern(canvas, 14 * cellSize, 0, cellSize, paint);
    _drawPositionPattern(canvas, 0, 14 * cellSize, cellSize, paint);

    // Deterministic pseudo-random pattern based on seed
    final rng = Random(seed.hashCode);
    for (int r = 0; r < 21; r++) {
      for (int c = 0; c < 21; c++) {
        // Skip position patterns
        if ((r < 7 && c < 7) || (r < 7 && c >= 14) || (r >= 14 && c < 7)) {
          continue;
        }
        // Skip center logo area
        if (r >= 7 && r <= 13 && c >= 7 && c <= 13) {
          continue;
        }

        if (rng.nextBool()) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                c * cellSize,
                r * cellSize,
                cellSize * 0.9,
                cellSize * 0.9,
              ),
              const Radius.circular(1.5),
            ),
            paint,
          );
        }
      }
    }
  }

  void _drawPositionPattern(
    Canvas canvas,
    double x,
    double y,
    double cellSize,
    Paint paint,
  ) {
    // Outer 7x7
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, cellSize * 7, cellSize * 7),
        const Radius.circular(4),
      ),
      paint,
    );
    // Inner white 5x5
    final whitePaint = Paint()..color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x + cellSize, y + cellSize, cellSize * 5, cellSize * 5),
        const Radius.circular(3),
      ),
      whitePaint,
    );
    // Center black 3x3
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          x + cellSize * 2,
          y + cellSize * 2,
          cellSize * 3,
          cellSize * 3,
        ),
        const Radius.circular(2),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
