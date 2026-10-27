import 'package:flutter_riverpod/flutter_riverpod.dart';

final favoriteAppsProvider =
    StateNotifierProvider<FavoriteAppsNotifier, Set<String>>((ref) {
  return FavoriteAppsNotifier();
});

class FavoriteAppsNotifier extends StateNotifier<Set<String>> {
  FavoriteAppsNotifier() : super({'shopee', 'coffee_shop'});

  bool isFavorite(String appId) => state.contains(appId);

  void toggleFavorite(String appId) {
    if (state.contains(appId)) {
      state = {...state}..remove(appId);
    } else {
      state = {...state, appId};
    }
  }

  void addFavorite(String appId) {
    if (!state.contains(appId)) {
      state = {...state, appId};
    }
  }

  void removeFavorite(String appId) {
    if (state.contains(appId)) {
      state = {...state}..remove(appId);
    }
  }
}
