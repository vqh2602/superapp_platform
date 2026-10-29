import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/animations/app_motion.dart';
import '../../data/mini_app_repository.dart';
import '../../domain/mini_app_manifest.dart';
import '../widgets/app_list_item.dart';

class SearchScreen extends ConsumerStatefulWidget {
  final bool showBackButton;
  final VoidCallback? onBack;

  const SearchScreen({
    super.key,
    this.showBackButton = false,
    this.onBack,
  });

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _currentQuery = '';

  final List<String> _popularKeywords = [
    'FC Mobile VN',
    'Chiến Tuyến Hướng Dư',
    'MultiCraft',
    'Cốc Cốc: Web Browser',
    'CapCut - Photo',
    'Highland Coffee',
    'SDK Playground',
    'Shopee',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onKeywordSelected(String keyword) {
    setState(() {
      _searchController.text = keyword;
      _currentQuery = keyword;
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(dynamicCatalogProvider);
    final allApps = catalogAsync.valueOrNull ?? [];

    final filteredApps = _currentQuery.trim().isEmpty
        ? <MiniAppManifest>[]
        : allApps.where((app) {
            final q = _currentQuery.toLowerCase();
            return app.name.toLowerCase().contains(q) ||
                app.description.toLowerCase().contains(q) ||
                app.category.toLowerCase().contains(q);
          }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: widget.showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () {
                  if (widget.onBack != null) {
                    widget.onBack!();
                  } else {
                    Navigator.of(context).maybePop();
                  }
                },
              )
            : null,
        title: const Text(
          'Tìm kiếm',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Search Input Bar
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Nhập từ khóa ứng dụng hoặc trò chơi',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onChanged: (val) {
                      setState(() {
                        _currentQuery = val;
                      });
                    },
                  ),
                ),
                if (_currentQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() {
                        _currentQuery = '';
                      });
                    },
                    child: const Icon(Icons.cancel, color: Color(0xFF94A3B8), size: 18),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // If user is searching, show real-time search results
          if (_currentQuery.isNotEmpty) ...[
            Text(
              'Kết quả tìm kiếm cho "$_currentQuery" (${filteredApps.length})',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            if (filteredApps.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.search_off_rounded, size: 48, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 12),
                      Text(
                        'Không tìm thấy kết quả nào cho "$_currentQuery"',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...List.generate(filteredApps.length, (index) {
                return FadeSlideIn(
                  delay: Duration(milliseconds: 20 * index),
                  child: AppListItem(app: filteredApps[index]),
                );
              }),
            const SizedBox(height: 24),
          ],

          // Popular Searches Section
          if (_currentQuery.isEmpty) ...[
            const Text(
              'Tìm kiếm phổ biến',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _popularKeywords.map((kw) {
                return BouncingTap(
                  onTap: () => _onKeywordSelected(kw),
                  scaleFactor: 0.92,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      kw,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),

            // Horizontal Recommended Apps Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Gợi ý ứng dụng hàng đầu',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Xem tất cả',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      Icon(Icons.chevron_right, size: 16, color: Color(0xFF64748B)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: allApps.length > 6 ? 6 : allApps.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final app = allApps[index];
                  return _buildSuggestedAppCard(context, app);
                },
              ),
            ),
            const SizedBox(height: 28),

            // Discover Today Banner (Khám phá hôm nay)
            const Text(
              'Khám phá hôm nay',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 14),
            _buildDiscoverBanner(context),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildSuggestedAppCard(BuildContext context, MiniAppManifest app) {
    Color iconBg = const Color(0xFF2563EB);
    IconData icon = Icons.apps_rounded;
    if (app.id == 'tiktok') {
      iconBg = const Color(0xFF010101);
      icon = Icons.music_note_rounded;
    } else if (app.id == 'youtube') {
      iconBg = const Color(0xFFFF0000);
      icon = Icons.play_arrow_rounded;
    } else if (app.id == 'facebook') {
      iconBg = const Color(0xFF1877F2);
      icon = Icons.facebook_rounded;
    } else if (app.id == 'messenger') {
      iconBg = const Color(0xFF0084FF);
      icon = Icons.chat_bubble_rounded;
    } else if (app.id == 'sample_store') {
      iconBg = const Color(0xFF8B4513);
      icon = Icons.coffee_rounded;
    }

    return SizedBox(
      width: 76,
      child: Column(
        children: [
          InkWell(
            onTap: () => context.push('/miniapp/${app.id}'),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: iconBg.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: app.icon.startsWith('http://') || app.icon.startsWith('https://')
                    ? Image.network(app.icon, fit: BoxFit.cover,
                        errorBuilder: (_, error, stackTrace) => Icon(icon, color: Colors.white, size: 28))
                    : Icon(icon, color: Colors.white, size: 28),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            app.name,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 26,
            child: ElevatedButton(
              onPressed: () => context.push('/miniapp/${app.id}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BA52),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
                textStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: const Text('Mở'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoverBanner(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/miniapp/youtube'),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 190,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF581C87), Color(0xFF3B82F6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 12),
                const Text(
                  'YouTube Mini App',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YouTube: Truyền tải bản thân',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Kết nối video, âm nhạc và nội dung trực tuyến mượt mà.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            ElevatedButton(
              onPressed: () => context.push('/miniapp/youtube'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF581C87),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: const Text('Mở ngay'),
            ),
          ],
        ),
      ),
    );
  }
}
