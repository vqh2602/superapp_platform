import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../authentication/presentation/controllers/auth_controller.dart';
import '../../../../core/config/app_theme.dart';

class NativeProfileScreen extends ConsumerWidget {
  const NativeProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Native Profile'),
      ),
      body: user == null
          ? const Center(child: Text('Chưa đăng nhập'))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 46,
                        backgroundColor: AppTheme.primary,
                        child: Text(
                          user.name[0],
                          style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        user.name,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${user.id} • ${user.role.toUpperCase()}',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Thông tin tài khoản',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const Divider(height: 24),
                        _buildInfoRow('Họ và tên', user.name),
                        _buildInfoRow('Số điện thoại', user.phone),
                        _buildInfoRow('Email', user.email),
                        _buildInfoRow('Vai trò', user.role),
                        _buildInfoRow('Trạng thái xác thực', 'Đã xác thực (Mock Session)'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: Color(0xFF059669), size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Màn hình này được mở trực tiếp từ Mini App thông qua Native Navigation Bridge!',
                          style: TextStyle(fontSize: 12, color: Color(0xFF065F46)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, {'action': 'profile_viewed'}),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Đóng màn hình Native'),
                ),
              ],
            ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}
