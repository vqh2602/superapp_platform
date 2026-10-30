import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../../core/config/app_config.dart';
import '../../../../core/config/endpoint_config.dart';
import '../domain/mini_app_manifest.dart';

class MiniAppRepository {
  final http.Client? httpClient;
  final String _catalogUrl;

  final List<MiniAppManifest> _dynamicApps = [];
  bool _hasFetched = false;

  MiniAppRepository({
    this.httpClient,
    String? catalogUrl,
  }) : _catalogUrl = catalogUrl ?? AppConfig.catalogApiUrl;

  List<MiniAppManifest> getAllApps() {
    return List.unmodifiable(_dynamicApps);
  }

  MiniAppManifest? getAppById(String id) {
    try {
      return _dynamicApps.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  MiniAppManifest _manifestFromApi(Map<String, dynamic> data) {
    final json = Map<String, dynamic>.from(data);
    final api = Uri.parse(_catalogUrl);

    // Safeguard: If backend returned legacy assets/ path, transform to remote backend URL
    final rawEntry = json['entryUrl'];
    if (rawEntry is String && rawEntry.startsWith('assets/mini_apps/')) {
      final appId = json['id'] as String? ?? '';
      final ver = json['version'] as String? ?? '1.0.0';
      final isWeb = json['runtimeType'] == 'web';
      final targetApp = isWeb ? appId : 'schema_runtime';
      json['entryUrl'] = api.resolve('/api/v1/miniapps/$targetApp/$ver/dist/index.html').toString();
      json['isAsset'] = false;
    }

    for (final key in ['entryUrl', 'icon']) {
      final value = json[key];
      if (value is String && value.startsWith('/')) {
        json[key] = api.resolve(value).toString();
      }
    }
    return MiniAppManifest.fromJson(json);
  }

  /// Fetch single app details & schema from remote catalog API
  Future<MiniAppManifest?> fetchRemoteManifest(String id) async {
    try {
      final client = httpClient ?? http.Client();
      final uri = Uri.parse('$_catalogUrl/apps/$id');
      final res = await client.get(uri).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final manifest = _manifestFromApi(data);
        // Cache or update in dynamic list
        _dynamicApps.removeWhere((a) => a.id == id);
        _dynamicApps.add(manifest);
        return manifest;
      }
      if (res.statusCode == 403 || res.statusCode == 404) {
        _dynamicApps.removeWhere((app) => app.id == id);
        return null;
      }
    } catch (e) {
      debugPrint('[MiniAppRepository] Remote fetch for $id failed: $e');
    }

    return getAppById(id);
  }

  /// Fetch published apps from Backend Catalog API (No local assets fallback)
  Future<List<MiniAppManifest>> getPublishedMiniApps({
    String? category,
    String? search,
    bool forceRefresh = false,
  }) async {
    if (!_hasFetched || forceRefresh) {
      await _fetchFromApi();
    }

    Iterable<MiniAppManifest> source = _dynamicApps;

    if (category != null && category.isNotEmpty && category != 'All') {
      source = source.where(
          (a) => a.category.toLowerCase() == category.toLowerCase());
    }

    if (search != null && search.trim().isNotEmpty) {
      final q = search.trim().toLowerCase();
      source = source.where((a) =>
          a.name.toLowerCase().contains(q) ||
          a.description.toLowerCase().contains(q));
    }

    return List.unmodifiable(source.toList());
  }

  /// Query distinct categories from Backend Catalog API
  Future<List<String>> getCategories() async {
    try {
      final client = httpClient ?? http.Client();
      final uri = Uri.parse('$_catalogUrl/categories');
      final res = await client.get(uri).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final list = (jsonDecode(res.body) as List<dynamic>)
            .map((e) => e.toString())
            .toList();
        return list;
      }
    } catch (e) {
      debugPrint('[MiniAppRepository] Fetch categories failed: $e');
    }

    // Fallback to categories from currently loaded backend apps
    final set = <String>{'All'};
    for (final app in _dynamicApps) {
      if (app.category.isNotEmpty) {
        set.add(app.category);
      }
    }
    return set.toList();
  }

  Future<void> _fetchFromApi() async {
    try {
      final client = httpClient ?? http.Client();
      final uri = Uri.parse('$_catalogUrl/apps');
      final res = await client.get(uri).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final items = (data['items'] as List<dynamic>?) ?? [];
        _dynamicApps.clear();

        for (final item in items) {
          _dynamicApps.add(_manifestFromApi(item as Map<String, dynamic>));
        }
        _hasFetched = true;
      } else {
        throw StateError('Catalog API returned status ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('[MiniAppRepository] Backend Catalog API fetch failed: $e');
      _dynamicApps.clear();
      _hasFetched = true;
      rethrow;
    }
  }

  void reset() {
    _dynamicApps.clear();
    _hasFetched = false;
  }
}

/// Core singleton provider for MiniAppRepository bound to backendEndpointProvider
final miniAppRepositoryProvider = Provider<MiniAppRepository>((ref) {
  final endpoint = ref.watch(backendEndpointProvider);
  return MiniAppRepository(catalogUrl: endpoint.catalogUrl);
});

/// Selected category filter state
class SelectedCategoryNotifier extends Notifier<String> {
  @override
  String build() => 'All';

  @override
  set state(String value) => super.state = value;
}

final selectedCategoryProvider =
    NotifierProvider<SelectedCategoryNotifier, String>(
  SelectedCategoryNotifier.new,
);

/// Search query filter state
class CatalogSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  @override
  set state(String value) => super.state = value;
}

final catalogSearchQueryProvider =
    NotifierProvider<CatalogSearchQueryNotifier, String>(
  CatalogSearchQueryNotifier.new,
);

/// Dynamic catalog query provider (FutureProvider for automatic async state & refresh)
final dynamicCatalogProvider =
    FutureProvider.autoDispose<List<MiniAppManifest>>((ref) async {
  final repo = ref.watch(miniAppRepositoryProvider);
  final category = ref.watch(selectedCategoryProvider);
  final search = ref.watch(catalogSearchQueryProvider);

  return repo.getPublishedMiniApps(
    category: category,
    search: search,
  );
});

/// Categories list provider
final catalogCategoriesProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  final repo = ref.watch(miniAppRepositoryProvider);
  return repo.getCategories();
});
