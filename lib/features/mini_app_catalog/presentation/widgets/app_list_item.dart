import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../domain/mini_app_manifest.dart';

class AppListItem extends StatelessWidget {
  final MiniAppManifest app;
  final VoidCallback? onOpen;

  const AppListItem({
    super.key,
    required this.app,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (onOpen != null) {
          onOpen!();
        } else {
          context.push('/miniapp/${app.id}');
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // App Icon
            _buildAppIcon(app),
            const SizedBox(width: 14),

            // Name + Description (no download count, no file size)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    app.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    app.description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      height: 1.25,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Open Action Button: Green Pill "Mở"
            ElevatedButton(
              onPressed: () {
                if (onOpen != null) {
                  onOpen!();
                } else {
                  context.push('/miniapp/${app.id}');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BA52),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                minimumSize: const Size(64, 34),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: const Text('Mở'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppIcon(MiniAppManifest app) {
    Color bgColor;
    IconData iconData;

    switch (app.id) {
      case 'tiktok':
        bgColor = const Color(0xFF010101);
        iconData = Icons.music_note_rounded;
        break;
      case 'youtube':
        bgColor = const Color(0xFFFF0000);
        iconData = Icons.play_arrow_rounded;
        break;
      case 'messenger':
        bgColor = const Color(0xFF0084FF);
        iconData = Icons.chat_bubble_rounded;
        break;
      case 'facebook':
        bgColor = const Color(0xFF1877F2);
        iconData = Icons.facebook_rounded;
        break;
      case 'zalo':
        bgColor = const Color(0xFF0068FF);
        iconData = Icons.message_rounded;
        break;
      case 'shopee':
        bgColor = const Color(0xFFEE4D2D);
        iconData = Icons.shopping_bag_rounded;
        break;
      case 'sample_store':
        bgColor = const Color(0xFF8B4513);
        iconData = Icons.coffee_rounded;
        break;
      case 'sdk_playground':
        bgColor = const Color(0xFF2563EB);
        iconData = Icons.terminal_rounded;
        break;
      case 'free_fire':
        bgColor = const Color(0xFFF59E0B);
        iconData = Icons.sports_esports_rounded;
        break;
      case 'fc_mobile':
        bgColor = const Color(0xFF10B981);
        iconData = Icons.sports_soccer_rounded;
        break;
      case 'capcut':
        bgColor = const Color(0xFF1E293B);
        iconData = Icons.movie_filter_rounded;
        break;
      default:
        bgColor = const Color(0xFF3B82F6);
        iconData = Icons.apps_rounded;
    }

    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: bgColor.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          iconData,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}
