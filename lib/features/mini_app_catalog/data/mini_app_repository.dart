import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../../core/config/app_config.dart';
import '../../../../core/config/endpoint_config.dart';
import '../../../../core/network/app_http_client.dart';
import '../domain/mini_app_execution_authorization.dart';
import '../domain/mini_app_manifest.dart';

/// Quản lý dữ liệu Mini App Catalog và Cấp phép thực thi (Execution Authorization).
///
/// Phân định rạch ròi 2 cơ chế:
/// 1. Catalog Cache: Lưu tạm thông tin các Mini App đã tải (_dynamicApps) nhằm phục vụ
///    hiển thị danh mục, tìm kiếm và chi tiết giao diện mượt mà (getAppById, getAllApps).
/// 2. Execution Authorization: Cơ chế cấp phép thực thi có thời hạn (_executionAuthorizations)
///    bắt buộc phải được Backend xác thực trước khi một Mini App được phép mở trong WebView runtime.
///    Nếu một Mini App bị thu hồi (unpublish/403/404) hoặc giấy phép hết hạn và không thể revalidate,
///    hệ thống TUYỆT ĐỐI KHÔNG mở app chỉ dựa vào catalog cache.
class MiniAppRepository {
  final http.Client? httpClient;
  final String _catalogUrl;

  /// 1. Catalog Cache: Dành cho hiển thị UI
  final List<MiniAppManifest> _dynamicApps = [];
  bool _hasFetched = false;

  /// 2. Execution Authorization Table: Dành riêng cho quyền thực thi runtime
  final Map<String, MiniAppExecutionAuthorization> _executionAuthorizations = {};

  /// Thời hạn hiệu lực mặc định của giấy phép thực thi (15 phút)
  static const Duration defaultExecutionTtl = Duration(minutes: 15);

  MiniAppRepository({
    this.httpClient,
    String? catalogUrl,
  }) : _catalogUrl = catalogUrl ?? AppConfig.catalogApiUrl;

  /// Lấy toàn bộ danh sách Mini App từ Catalog Cache (chỉ phục vụ hiển thị)
  List<MiniAppManifest> getAllApps() {
    return List.unmodifiable(_dynamicApps);
  }

  /// Lấy manifest từ Catalog Cache theo ID (chỉ phục vụ hiển thị UI, KHÔNG dùng làm bằng chứng cấp phép chạy)
  MiniAppManifest? getAppById(String id) {
    try {
      return _dynamicApps.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Lấy giấy phép thực thi hiện tại đang còn hiệu lực (nếu có)
  MiniAppExecutionAuthorization? getActiveAuthorization(String id) {
    final auth = _executionAuthorizations[id];
    if (auth != null && auth.isValid) {
      return auth;
    }
    return null;
  }

  /// Thu hồi quyền thực thi của Mini App ngay lập tức
  void revokeExecutionAuthorization(String id) {
    _executionAuthorizations.remove(id);
    _dynamicApps.removeWhere((a) => a.id == id);
    debugPrint('[MiniAppRepository] Đã thu hồi toàn bộ quyền thực thi và xóa cache cho: $id');
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

  /// Cấp phép và xác thực quyền thực thi Mini App với Backend (Execution Authorization)
  ///
  /// Bắt buộc được gọi trước khi mở WebView runtime.
  /// - Nếu Backend phản hồi 200: Cấp giấy phép thực thi mới có thời hạn (TTL).
  /// - Nếu Backend phản hồi 403 / 404 hoặc bị thu hồi: Hủy giấy phép ngay lập tức và từ chối mở app.
  /// - Nếu xảy ra lỗi mạng / server 500:
  ///   + Nếu đã có giấy phép thực thi trước đó CÒN HẠN: Cho phép tiếp tục chạy trong thời hạn.
  ///   + Nếu CHƯA CÓ giấy phép hoặc giấy phép ĐÃ HẾT HẠN: TUYỆT ĐỐI TỪ CHỐI, không dùng catalog cache cũ!
  Future<MiniAppExecutionAuthorization?> authorizeExecution(
    String id, {
    Duration? ttl,
    bool forceRevalidate = false,
  }) async {
    final cachedAuth = _executionAuthorizations[id];

    // Nếu không bắt buộc revalidate và giấy phép hiện tại vẫn còn hiệu lực
    if (!forceRevalidate && cachedAuth != null && cachedAuth.isValid) {
      return cachedAuth;
    }

    try {
      final client = httpClient ?? http.Client();
      final uri = Uri.parse('$_catalogUrl/apps/$id');
      final res = await client.get(uri).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;

        // Kiểm tra xem ứng dụng có bị vô hiệu hóa hoặc chưa publish không
        final isPublished = data['isPublished'] ?? data['published'] ?? true;
        final status = data['status']?.toString().toLowerCase();
        if (isPublished == false || status == 'revoked' || status == 'unpublished') {
          revokeExecutionAuthorization(id);
          return null;
        }

        final manifest = _manifestFromApi(data);
        final now = DateTime.now();
        final effectiveTtl = ttl ?? defaultExecutionTtl;

        final newAuth = MiniAppExecutionAuthorization(
          appId: manifest.id,
          version: manifest.version,
          manifest: manifest,
          authorizedAt: now,
          expiresAt: now.add(effectiveTtl),
          authorizationToken: data['authorizationToken']?.toString(),
          isBackendVerified: true,
        );

        _executionAuthorizations[id] = newAuth;

        // Đồng thời cập nhật catalog cache
        _dynamicApps.removeWhere((a) => a.id == id);
        _dynamicApps.add(manifest);

        return newAuth;
      }

      if (res.statusCode == 403 || res.statusCode == 404) {
        // App đã bị thu hồi hoặc xóa bỏ trên backend -> Hủy giấy phép ngay lập tức
        revokeExecutionAuthorization(id);
        return null;
      }

      debugPrint('[MiniAppRepository] Backend returned status ${res.statusCode} for app authorization: $id');
    } catch (e) {
      debugPrint('[MiniAppRepository] Revalidation for $id failed with error: $e');
    }

    // Khi backend không truy cập được (mạng lỗi, server 500, timeout):
    // Chỉ cho phép chạy NẾU giấy phép thực thi đã cấp trước đó VẪN CÒN HIỆU LỰC.
    if (cachedAuth != null && cachedAuth.isValid) {
      debugPrint('[MiniAppRepository] Sử dụng giấy phép thực thi offline còn hiệu lực cho: $id (còn ${cachedAuth.remainingTime.inSeconds}s)');
      return cachedAuth;
    }

    // TUYỆT ĐỐI KHÔNG mở app chỉ dựa vào catalog cache cũ khi chưa có giấy phép hợp lệ!
    debugPrint('[MiniAppRepository] TỪ CHỐI THỰC THI: Không có giấy phép hợp lệ từ máy chủ cho Mini App: $id');
    return null;
  }

  /// Fetch single app details & schema from remote catalog API.
  ///
  /// Bây giờ được ủy quyền qua [authorizeExecution] để đảm bảo không trả về manifest
  /// nếu không có giấy phép thực thi hợp lệ.
  Future<MiniAppManifest?> fetchRemoteManifest(String id) async {
    final auth = await authorizeExecution(id);
    return auth?.manifest;
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
    _executionAuthorizations.clear();
    _hasFetched = false;
  }
}

/// Core singleton provider for MiniAppRepository bound to backendEndpointProvider
final miniAppRepositoryProvider = Provider<MiniAppRepository>((ref) {
  final endpoint = ref.watch(backendEndpointProvider);
  final httpClient = ref.watch(appHttpClientProvider);
  return MiniAppRepository(
    catalogUrl: endpoint.catalogUrl,
    httpClient: httpClient,
  );
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
