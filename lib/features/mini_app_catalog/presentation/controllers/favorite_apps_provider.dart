import 'package:flutter_riverpod/flutter_riverpod.dart';

class FavoriteAppsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {'shopee', 'coffee_shop'};

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

final favoriteAppsProvider =
    NotifierProvider<FavoriteAppsNotifier, Set<String>>(
  FavoriteAppsNotifier.new,
);
