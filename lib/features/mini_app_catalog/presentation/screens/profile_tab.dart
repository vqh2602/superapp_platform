import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../../core/config/app_theme.dart';
import '../../../../core/config/debug_mode_provider.dart';

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Của tôi',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile User Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: AppTheme.primary,
                  child: Text(
                    user != null && user.name.isNotEmpty ? user.name[0] : '?',
                    style: const TextStyle(
                      fontSize: 26,
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
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? 'N/A',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'ID: ${user?.id ?? "N/A"} • ${user?.role ?? "Guest"}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Menu Options
          Material(
            color: Colors.white,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _buildMenuItem(
                  icon: Icons.person_outline_rounded,
                  title: 'Chi tiết hồ sơ Native',
                  subtitle: 'Xem hồ sơ đầy đủ đồng bộ với Mini App',
                  onTap: () => context.push('/profile'),
                ),
                if (ref.watch(isDebugModeEnabledProvider)) ...[
                  const Divider(height: 1, indent: 56, color: Color(0xFFF1F5F9)),
                  _buildMenuItem(
                    icon: Icons.bug_report_outlined,
                    title: 'Trung tâm Debug Logs',
                    subtitle: 'Theo dõi Bridge logs và sự kiện RPC',
                    onTap: () => context.push('/debug'),
                  ),
                ],
                const Divider(height: 1, indent: 56, color: Color(0xFFF1F5F9)),
                _buildMenuItem(
                  icon: Icons.assignment_outlined,
                  title: 'Native Form Bridge Demo',
                  subtitle: 'Kiểm thử Native Page Navigation',
                  onTap: () => context.push('/form'),
                ),
                const Divider(height: 1, indent: 56, color: Color(0xFFF1F5F9)),
                _buildMenuItem(
                  icon: Icons.verified_user_outlined,
                  title: 'Bảo mật & Quyền riêng tư',
                  subtitle: 'Quản lý quyền cấp cho Mini Apps',
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Logout Button
          ElevatedButton.icon(
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
            icon: const Icon(Icons.logout_rounded, size: 20),
            label: const Text('Đăng xuất tài khoản'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFEF2F2),
              foregroundColor: Colors.red,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFFECACA)),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF334155), size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF0F172A)),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
    );
  }
}
