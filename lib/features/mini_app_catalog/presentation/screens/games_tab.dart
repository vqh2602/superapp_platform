import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/animations/app_motion.dart';
import '../../data/mini_app_repository.dart';
import '../widgets/app_list_item.dart';

class GamesTab extends ConsumerWidget {
  final VoidCallback? onNavigateToSearch;

  const GamesTab({
    super.key,
    this.onNavigateToSearch,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(dynamicCatalogProvider);
    final allApps = catalogAsync.valueOrNull ?? [];
    final gameApps = allApps
        .where((a) =>
            a.category.toLowerCase().contains('game') ||
            a.id == 'free_fire' ||
            a.id == 'fc_mobile')
        .toList();

    final displayGames = gameApps.isNotEmpty ? gameApps : allApps;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Trò chơi',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Tìm kiếm trò chơi',
            icon: const Icon(Icons.search_rounded, size: 26, color: Color(0xFF0F172A)),
            onPressed: onNavigateToSearch,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          // Game Hero Banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FadeSlideIn(
              delay: const Duration(milliseconds: 60),
              child: Container(
                height: 150,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEA580C), Color(0xFFF59E0B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEA580C).withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: const Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '🎮 THẾ GIỚI GAME MINI',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Chiến game tức thì',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Không cần tải bộ cài nặng. Chơi mượt trên đám mây.',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    PulseEffect(
                      minScale: 0.95,
                      maxScale: 1.05,
                      child: Icon(Icons.sports_esports_rounded, color: Colors.white, size: 54),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const Text(
              'Trò chơi được yêu thích nhất',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ),

          ...List.generate(displayGames.length, (index) {
            return FadeSlideIn(
              delay: Duration(milliseconds: 30 * index),
              child: AppListItem(app: displayGames[index]),
            );
          }),
        ],
      ),
    );
  }
}
