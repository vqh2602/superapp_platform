import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../core/config/app_config.dart';
import '../domain/mini_app_manifest.dart';

class MiniAppRepository {
  final http.Client? _httpClient;
  final String _catalogUrl;

  MiniAppRepository({
    http.Client? httpClient,
    String? catalogUrl,
  })  : _httpClient = httpClient,
        _catalogUrl = catalogUrl ?? AppConfig.catalogApiUrl;

  /// Seed / Static fallback apps for offline resilience and backward compatibility
  static const List<MiniAppManifest> _seedApps = [
    MiniAppManifest(
      id: 'sdk_playground',
      name: 'SDK Playground',
      description: 'React + TypeScript Mini App test bed with interactive SDK runner',
      version: '1.0.0',
      icon: 'code',
      category: 'Developer Tools',
      appRuntimeType: 'web',
      entryUrl: 'assets/mini_apps/sdk_playground/index.html',
      isAsset: true,
      status: 'PUBLISHED',
      capabilities: [
        'auth.requestCode',
        'user.getProfile',
        'user.getBasicInfo',
        'navigation.openNativePage',
        'navigation.close',
        'navigation.openMiniApp',
        'device.scanQRCode',
        'device.getLocation',
        'device.pickImage',
        'payment.createOrder',
        'payment.openCheckout',
        'permission.request',
        'debug.echo',
        'debug.simulateFailure',
      ],
    ),
    MiniAppManifest(
      id: 'sample_store',
      name: 'Sample Mini App 2 (Store)',
      description: 'Secondary Mini App to demonstrate cross-mini-app native switching',
      version: '1.0.0',
      icon: 'storefront',
      category: 'Food & Beverage',
      appRuntimeType: 'web',
      entryUrl: 'assets/mini_apps/sample_store/index.html',
      isAsset: true,
      status: 'PUBLISHED',
      capabilities: [
        'user.getBasicInfo',
        'navigation.close',
        'payment.createOrder',
        'payment.openCheckout',
      ],
    ),
  ];

  // In-memory dynamic apps cache
  final List<MiniAppManifest> _dynamicApps = [];
  bool _hasFetched = false;

  /// Returns all available apps (dynamic if fetched, otherwise seed apps)
  List<MiniAppManifest> getAllApps() {
    if (_dynamicApps.isNotEmpty) {
      return List.unmodifiable(_dynamicApps);
    }
    return List.unmodifiable(_seedApps);
  }

  /// Get app manifest by ID (checks dynamic cache first, then seed fallback)
  MiniAppManifest? getAppById(String id) {
    try {
      final foundDynamic = _dynamicApps.firstWhere((app) => app.id == id);
      return foundDynamic;
    } catch (_) {
      try {
        return _seedApps.firstWhere((app) => app.id == id);
      } catch (_) {
        return null;
      }
    }
  }

  /// Fetch single app details & schema from remote catalog API
  Future<MiniAppManifest?> fetchRemoteManifest(String id) async {
    try {
      final client = _httpClient ?? http.Client();
      final uri = Uri.parse('$_catalogUrl/apps/$id');
      final res = await client.get(uri).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final manifest = MiniAppManifest.fromJson(data);
        // Cache or update in dynamic list
        _dynamicApps.removeWhere((a) => a.id == id);
        _dynamicApps.add(manifest);
        return manifest;
      }
    } catch (e) {
      debugPrint('[MiniAppRepository] Remote fetch for $id failed: $e');
    }

    return getAppById(id);
  }

  /// Fetch published apps from Dynamic Catalog API with offline fallback
  Future<List<MiniAppManifest>> getPublishedMiniApps({
    String? category,
    String? search,
    bool forceRefresh = false,
  }) async {
    if (!_hasFetched || forceRefresh) {
      await _fetchFromApi();
    }

    Iterable<MiniAppManifest> source = _dynamicApps.isNotEmpty ? _dynamicApps : _seedApps;

    if (category != null && category.isNotEmpty && category != 'All') {
      source = source.where((a) => a.category.toLowerCase() == category.toLowerCase());
    }

    if (search != null && search.trim().isNotEmpty) {
      final q = search.trim().toLowerCase();
      source = source.where((a) =>
          a.name.toLowerCase().contains(q) || a.description.toLowerCase().contains(q));
    }

    return List.unmodifiable(source.toList());
  }

  /// Query distinct categories
  Future<List<String>> getCategories() async {
    try {
      final client = _httpClient ?? http.Client();
      final uri = Uri.parse('$_catalogUrl/categories');
      final res = await client.get(uri).timeout(const Duration(seconds: 3));

      if (res.statusCode == 200) {
        final list = (jsonDecode(res.body) as List<dynamic>).map((e) => e.toString()).toList();
        return list;
      }
    } catch (_) {}

    // Fallback to local categories
    final set = <String>{'All'};
    final list = _dynamicApps.isNotEmpty ? _dynamicApps : _seedApps;
    for (final app in list) {
      set.add(app.category);
    }
    return set.toList();
  }

  Future<void> _fetchFromApi() async {
    try {
      final client = _httpClient ?? http.Client();
      final uri = Uri.parse('$_catalogUrl/apps');
      final res = await client.get(uri).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final items = (data['items'] as List<dynamic>?) ?? [];
        _dynamicApps.clear();

        for (final item in items) {
          _dynamicApps.add(MiniAppManifest.fromJson(item as Map<String, dynamic>));
        }
        _hasFetched = true;
      }
    } catch (e) {
      debugPrint('[MiniAppRepository] API fetch failed, using offline seed apps: $e');
      if (_dynamicApps.isEmpty) {
        _dynamicApps.addAll(_seedApps);
      }
      _hasFetched = true;
    }
  }

  void reset() {
    _dynamicApps.clear();
    _hasFetched = false;
  }
}

/// Core singleton provider for MiniAppRepository
final miniAppRepositoryProvider = Provider<MiniAppRepository>((ref) {
  return MiniAppRepository();
});

/// Selected category filter state
final selectedCategoryProvider = StateProvider<String>((ref) => 'All');

/// Search query filter state
final catalogSearchQueryProvider = StateProvider<String>((ref) => '');

/// Dynamic catalog query provider (FutureProvider for automatic async state & refresh)
final dynamicCatalogProvider = FutureProvider.autoDispose<List<MiniAppManifest>>((ref) async {
  final repo = ref.watch(miniAppRepositoryProvider);
  final category = ref.watch(selectedCategoryProvider);
  final search = ref.watch(catalogSearchQueryProvider);

  return repo.getPublishedMiniApps(
    category: category,
    search: search,
  );
});

/// Categories list provider
final catalogCategoriesProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final repo = ref.watch(miniAppRepositoryProvider);
  return repo.getCategories();
});
