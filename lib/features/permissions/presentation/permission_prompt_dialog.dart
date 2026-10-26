import 'package:flutter/material.dart';
import '../../../../core/config/app_theme.dart';
import '../domain/app_capability.dart';

class PermissionPromptDialog extends StatelessWidget {
  final String appName;
  final String capabilityKey;

  const PermissionPromptDialog({
    super.key,
    required this.appName,
    required this.capabilityKey,
  });

  static Future<bool> show(
    BuildContext context, {
    required String appName,
    required String capabilityKey,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PermissionPromptDialog(
        appName: appName,
        capabilityKey: capabilityKey,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final cap = AppCapability.fromKey(capabilityKey);
    final title = cap?.title ?? capabilityKey;
    final description = cap?.description ?? 'Yêu cầu quyền truy cập tính năng hệ thống';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.security_rounded, color: AppTheme.primary, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Yêu cầu quyền',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 14, color: Color(0xFF334155), height: 1.4),
              children: [
                const TextSpan(text: 'Ứng dụng '),
                TextSpan(
                  text: appName,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const TextSpan(text: ' đang yêu cầu quyền:'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 6),
                Text(
                  'Capability: $capabilityKey',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF64748B),
          ),
          child: const Text('Từ chối (Deny)'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Cho phép (Allow)'),
        ),
      ],
    );
  }
}
