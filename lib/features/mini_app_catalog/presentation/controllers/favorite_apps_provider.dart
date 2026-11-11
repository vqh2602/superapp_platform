// Quản lý danh sách Mini App yêu thích (Favorite Apps Provider).
//
// Duy trì tập hợp các mã appId được người dùng đánh dấu sao yêu thích để hiển thị
// trong mục "Ứng dụng yêu thích" tại trang chủ.
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notifier quản lý danh sách appId yêu thích
class FavoriteAppsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {'shopee', 'coffee_shop'};

  /// Kiểm tra appId đã được thêm vào yêu thích hay chưa
  bool isFavorite(String appId) => state.contains(appId);

  /// Bật/tắt trạng thái yêu thích của Mini App
  void toggleFavorite(String appId) {
    if (state.contains(appId)) {
      state = {...state}..remove(appId);
    } else {
      state = {...state, appId};
    }
  }

  /// Thêm Mini App vào danh sách yêu thích
  void addFavorite(String appId) {
    if (!state.contains(appId)) {
      state = {...state, appId};
    }
  }

  /// Xóa Mini App khỏi danh sách yêu thích
  void removeFavorite(String appId) {
    if (state.contains(appId)) {
      state = {...state}..remove(appId);
    }
  }
}

/// Provider cung cấp tập hợp các appId yêu thích
final favoriteAppsProvider =
    NotifierProvider<FavoriteAppsNotifier, Set<String>>(
  FavoriteAppsNotifier.new,
);
