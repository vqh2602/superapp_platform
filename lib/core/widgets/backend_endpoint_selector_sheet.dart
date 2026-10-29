import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/endpoint_config.dart';
import '../../features/mini_app_catalog/data/mini_app_repository.dart';

/// Shows a bottom sheet allowing users to quickly pick between Localhost,
/// Alwaysdata Cloud, or type a custom Backend Endpoint URL.
Future<void> showBackendEndpointSelectorSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  final current = ref.read(backendEndpointProvider);
  final controller = TextEditingController(text: current.baseUrl);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setState) {
          final text = controller.text.trim();
          final isLocal = text == EndpointConfig.localhostEndpoint ||
              EndpointConfig.normalize(text) == EndpointConfig.localhostEndpoint;
          final isAlwaysdata = text == EndpointConfig.alwaysdataEndpoint ||
              EndpointConfig.normalize(text) == EndpointConfig.alwaysdataEndpoint;

          void apply(String url) async {
            final normalized = EndpointConfig.normalize(url);
            await ref.read(backendEndpointProvider.notifier).setEndpoint(normalized);
            ref.invalidate(dynamicCatalogProvider);
            ref.invalidate(catalogCategoriesProvider);
            if (ctx.mounted) {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Đã chuyển Backend Endpoint sang:\n$normalized'),
                  backgroundColor: const Color(0xFF0F172A),
                  duration: const Duration(seconds: 3),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Close
                  Row(
                    children: [
                      const Icon(Icons.dns_rounded, color: Color(0xFF0284C7), size: 24),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Cấu hình Backend Endpoint',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Chọn máy chủ Backend SuperApp nhanh hoặc nhập URL endpoint riêng:',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),

                  // Quick presets
                  const Text(
                    'CHỌN NHANH MÁY CHỦ',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 1. Alwaysdata Cloud
                  InkWell(
                    onTap: () {
                      controller.text = EndpointConfig.alwaysdataEndpoint;
                      setState(() {});
                      apply(EndpointConfig.alwaysdataEndpoint);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isAlwaysdata
                            ? const Color(0xFFF0FDF4)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isAlwaysdata
                              ? const Color(0xFF22C55E)
                              : const Color(0xFFE2E8F0),
                          width: isAlwaysdata ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isAlwaysdata
                                  ? const Color(0xFFDCFCE7)
                                  : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.cloud_rounded,
                                color: Color(0xFF16A34A), size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Alwaysdata Cloud (Production)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  EndpointConfig.alwaysdataEndpoint,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isAlwaysdata)
                            const Icon(Icons.check_circle_rounded,
                                color: Color(0xFF16A34A), size: 20),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // 2. Localhost
                  InkWell(
                    onTap: () {
                      controller.text = EndpointConfig.localhostEndpoint;
                      setState(() {});
                      apply(EndpointConfig.localhostEndpoint);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isLocal
                            ? const Color(0xFFF0FDF4)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isLocal
                              ? const Color(0xFF22C55E)
                              : const Color(0xFFE2E8F0),
                          width: isLocal ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isLocal
                                  ? const Color(0xFFDCFCE7)
                                  : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.computer_rounded,
                                color: Color(0xFF0284C7), size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Localhost (Máy phát triển cục bộ)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  EndpointConfig.localhostEndpoint,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isLocal)
                            const Icon(Icons.check_circle_rounded,
                                color: Color(0xFF16A34A), size: 20),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Custom endpoint input
                  const Text(
                    'HOẶC NHẬP ENDPOINT RIÊNG',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 8),

                  TextFormField(
                    controller: controller,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Backend Endpoint URL tùy chỉnh',
                      hintText: 'https://your-api.domain.com',
                      prefixIcon: const Icon(Icons.link_rounded, size: 20),
                      suffixIcon: text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                controller.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: text.isEmpty ? null : () => apply(text),
                      icon: const Icon(Icons.save_rounded, size: 18),
                      label: const Text(
                        'Lưu & Kết nối',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

