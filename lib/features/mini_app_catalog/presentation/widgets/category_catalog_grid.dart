import 'package:flutter/material.dart';

class CategoryItem {
  final String id;
  final String label;
  final IconData icon;
  final Color color;

  const CategoryItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
  });
}

const List<CategoryItem> kAllCategories = [
  CategoryItem(id: 'photo_video', label: 'Photo & Video', icon: Icons.videocam_rounded, color: Color(0xFFEF4444)),
  CategoryItem(id: 'utilities', label: 'Utilities', icon: Icons.build_rounded, color: Color(0xFF0EA5E9)),
  CategoryItem(id: 'entertainment', label: 'Entertainment', icon: Icons.smart_display_rounded, color: Color(0xFFF59E0B)),
  CategoryItem(id: 'social', label: 'Social Network', icon: Icons.chat_bubble_rounded, color: Color(0xFF10B981)),
  CategoryItem(id: 'books', label: 'Books', icon: Icons.menu_book_rounded, color: Color(0xFF10B981)),
  CategoryItem(id: 'shopping', label: 'Shopping', icon: Icons.shopping_bag_rounded, color: Color(0xFFF43F5E)),
  CategoryItem(id: 'lifestyle', label: 'Lifestyle', icon: Icons.coffee_rounded, color: Color(0xFFF59E0B)),
  CategoryItem(id: 'news', label: 'News', icon: Icons.article_rounded, color: Color(0xFF0284C7)),
  CategoryItem(id: 'music', label: 'Music', icon: Icons.music_note_rounded, color: Color(0xFF10B981)),
  CategoryItem(id: 'finance', label: 'Finance', icon: Icons.credit_card_rounded, color: Color(0xFFEAB308)),
  CategoryItem(id: 'education', label: 'Education', icon: Icons.school_rounded, color: Color(0xFF06B6D4)),
  CategoryItem(id: 'navigation', label: 'Navigation', icon: Icons.location_on_rounded, color: Color(0xFF10B981)),
  CategoryItem(id: 'travel', label: 'Travel', icon: Icons.flight_rounded, color: Color(0xFFF59E0B)),
  CategoryItem(id: 'business', label: 'Business', icon: Icons.work_rounded, color: Color(0xFF0284C7)),
  CategoryItem(id: 'productivity', label: 'Productivity', icon: Icons.bolt_rounded, color: Color(0xFF10B981)),
  CategoryItem(id: 'food_drink', label: 'Food & Drink', icon: Icons.restaurant_rounded, color: Color(0xFFF59E0B)),
  CategoryItem(id: 'health', label: 'Health & Fitness', icon: Icons.favorite_rounded, color: Color(0xFFEF4444)),
  CategoryItem(id: 'weather', label: 'Weather', icon: Icons.wb_sunny_rounded, color: Color(0xFFF59E0B)),
  CategoryItem(id: 'sports', label: 'Sports', icon: Icons.sports_tennis_rounded, color: Color(0xFFEF4444)),
  CategoryItem(id: 'reference', label: 'Reference', icon: Icons.auto_stories_rounded, color: Color(0xFF06B6D4)),
  CategoryItem(id: 'medical', label: 'Medical', icon: Icons.local_hospital_rounded, color: Color(0xFFEF4444)),
  CategoryItem(id: 'other', label: 'Other', icon: Icons.more_horiz_rounded, color: Color(0xFF10B981)),
];

class CategoryCatalogGrid extends StatelessWidget {
  final Function(CategoryItem category)? onCategorySelected;

  const CategoryCatalogGrid({
    super.key,
    this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 18,
        crossAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: kAllCategories.length,
      itemBuilder: (context, index) {
        final cat = kAllCategories[index];
        return InkWell(
          onTap: () => onCategorySelected?.call(cat),
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cat.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  cat.icon,
                  color: cat.color,
                  size: 24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                cat.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF334155),
                  height: 1.15,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }
}
