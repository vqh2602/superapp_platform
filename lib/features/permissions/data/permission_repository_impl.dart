// Quản lý dữ liệu phân quyền Mini App (Permission Repository Implementation).
//
// Lưu trữ trạng thái cấp/từ chối quyền của người dùng đối với từng Mini App,
// hỗ trợ đồng bộ nguyên tử (atomic sync) với máy chủ Backend và tự động rollback nếu gặp sự cố.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../../core/config/endpoint_config.dart';
import '../../../../core/errors/bridge_error.dart';
import '../../../../core/network/app_http_client.dart';
import '../../authentication/data/auth_repository_impl.dart';
import '../../authentication/presentation/controllers/auth_controller.dart';

/// Lớp lưu trữ và đồng bộ hóa quyền hạn Mini App
class PermissionRepositoryImpl {
  final http.Client? httpClient;
  final String? usersUrl;
  final AuthRepositoryImpl? authRepo;

  // Map of appId -> Map of capabilityKey -> isGranted
  final Map<String, Map<String, bool>> _storage = {};

  final Set<String> _loadedApps = {};
  final Map<String, Future<Map<String, bool>>> _loadingApps = {};
  final Map<String, int> _revisions = {};
  StreamSubscription<dynamic>? _sessionSubscription;
  String? _userId;
  int _generation = 0;

  PermissionRepositoryImpl({this.httpClient, this.usersUrl, this.authRepo}) {
    _userId = authRepo?.currentUser?.id;
    _sessionSubscription = authRepo?.sessionStream.listen((session) {
      _useUser(session?.user.id);
    });
  }

  void _useUser(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    reset();
  }

  void _checkUser() => _useUser(authRepo?.currentUser?.id);

  void dispose() {
    _sessionSubscription?.cancel();
  }

  /// Load before any permission check; concurrent startup calls share a request.
  Future<Map<String, bool>> ensurePermissionsLoaded(String appId) {
    _checkUser();
    if (_loadedApps.contains(appId)) {
      return Future.value(getPermissionsForApp(appId));
    }
    return _loadingApps[appId] ??= fetchPermissionsFromBackend(appId);
  }

  bool isGranted(String appId, String capability) {
    _checkUser();
    return _storage[appId]?[capability] ?? false;
  }

  bool isExplicitlyDenied(String appId, String capability) {
    _checkUser();
    final granted = _storage[appId]?[capability];
    return granted == false;
  }

  /// Cập nhật quyền và đồng bộ nguyên tử (atomic) lên Backend nếu người dùng đã đăng nhập.
  /// Nếu đồng bộ thất bại, tự động rollback lại trạng thái trước đó và ném lỗi.
  Future<void> updatePermission(String appId, String capability, bool granted) async {
    _checkUser();
    final previous = _storage[appId]?[capability];
    _revisions[appId] = (_revisions[appId] ?? 0) + 1;
    _storage.putIfAbsent(appId, () => {})[capability] = granted;

    final session = authRepo?.currentSession;
    if (usersUrl != null &&
        session != null &&
        session.accessToken.isNotEmpty) {
      try {
        final client = httpClient ?? http.Client();
        final url = Uri.parse('$usersUrl/me/apps/$appId/permissions');
        final response = await client
            .put(
              url,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ${session.accessToken}',
              },
              body: jsonEncode({
                'permissions': [capability],
                'granted': granted,
              }),
            )
            .timeout(const Duration(seconds: 4));

        if (response.statusCode != 200 && response.statusCode != 204) {
          _rollbackPermission(appId, capability, previous);
          throw BridgeError.internal(
            'Đồng bộ quyền lên máy chủ thất bại (HTTP ${response.statusCode})',
          );
        }
      } catch (e) {
        _rollbackPermission(appId, capability, previous);
        if (e is BridgeError) rethrow;
        throw BridgeError.internal(
          'Không thể kết nối đến máy chủ để lưu quyền: $e',
        );
      }
    }
  }

  void _rollbackPermission(String appId, String capability, bool? previous) {
    if (previous == null) {
      _storage[appId]?.remove(capability);
    } else {
      _storage.putIfAbsent(appId, () => {})[capability] = previous;
    }
  }

  /// ĐÃ LỖI THỜI: Vui lòng sử dụng [updatePermission] hoặc thông qua [PermissionService].
  ///
  /// Phương thức này được định tuyến trực tiếp vào [updatePermission] để đảm bảo mọi cập nhật quyền
  /// đều tuân thủ cơ chế đồng bộ nguyên tử (atomic sync) và rollback trạng thái bộ nhớ nếu backend thất bại,
  /// chấm dứt hoàn toàn nguy cơ trạng thái client khác backend do đồng bộ fire-and-forget cũ.
  @Deprecated('Sử dụng PermissionService.updatePermission() hoặc updatePermission()')
  void setPermission(String appId, String capability, bool granted) {
    unawaited(updatePermission(appId, capability, granted).catchError((e) {
      debugPrint('[PermissionRepositoryImpl] Deprecated setPermission sync error (rolled back): $e');
    }));
  }

  /// Cấp quyền hàng loạt và đồng bộ lên Backend
  Future<void> grantAll(String appId, List<String> capabilities) async {
    for (final cap in capabilities) {
      await updatePermission(appId, cap, true);
    }
  }

  /// Thu hồi toàn bộ quyền của Mini App và đồng bộ nguyên tử lên Backend.
  /// Nếu đồng bộ máy chủ thất bại, tự động rollback khôi phục lại các quyền trước đó.
  Future<void> revokeAll(String appId) async {
    _checkUser();
    final previous = _storage[appId] != null
        ? Map<String, bool>.from(_storage[appId]!)
        : null;
    _revisions[appId] = (_revisions[appId] ?? 0) + 1;
    _storage.remove(appId);

    final session = authRepo?.currentSession;
    if (usersUrl != null &&
        session != null &&
        session.accessToken.isNotEmpty) {
      try {
        final client = httpClient ?? http.Client();
        final url = Uri.parse('$usersUrl/me/apps/$appId/permissions');
        final response = await client
            .delete(url, headers: {'Authorization': 'Bearer ${session.accessToken}'})
            .timeout(const Duration(seconds: 4));

        if (response.statusCode != 200 && response.statusCode != 204) {
          if (previous != null) {
            _storage[appId] = previous;
          }
          throw BridgeError.internal(
            'Thu hồi quyền trên máy chủ thất bại (HTTP ${response.statusCode})',
          );
        }
      } catch (e) {
        if (previous != null) {
          _storage[appId] = previous;
        }
        if (e is BridgeError) rethrow;
        throw BridgeError.internal(
          'Không thể kết nối đến máy chủ để thu hồi quyền: $e',
        );
      }
    }
  }

  /// Fetch remote permissions & effective grants for a mini app from Backend
  Future<Map<String, bool>> fetchPermissionsFromBackend(String appId) async {
    _checkUser();
    final generation = _generation;
    final revision = _revisions[appId] ?? 0;
    final session = authRepo?.currentSession;
    try {
      if (usersUrl != null &&
          session != null &&
          session.accessToken.isNotEmpty) {
        final client = httpClient ?? http.Client();
        final response = await client
            .get(
              Uri.parse('$usersUrl/me/apps/$appId/permissions'),
              headers: {'Authorization': 'Bearer ${session.accessToken}'},
            )
            .timeout(const Duration(seconds: 10));
        _checkUser();
        if (_generation != generation) return getPermissionsForApp(appId);
        if (response.statusCode == 401) throw BridgeError.authRequired();
        if (response.statusCode != 200) {
          throw BridgeError.internal(
            'Không thể tải quyền Mini App đã lưu. Vui lòng thử lại.',
          );
        }
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final effective =
              (data['effectivePermissions'] as List<dynamic>?)
                  ?.cast<String>() ??
              [];
          final appMap = <String, bool>{};
          for (final decision in (data['decisions'] as List<dynamic>?) ?? []) {
            final capability = decision['capability'];
            if (capability is String && decision['granted'] is bool) {
              appMap[capability] =
                  decision['granted'] == true && effective.contains(capability);
            }
          }
          for (final capability in effective) {
            appMap[capability] = true;
          }
          if ((_revisions[appId] ?? 0) == revision) _storage[appId] = appMap;
          _loadedApps.add(appId);
        }
      }
    } catch (e) {
      debugPrint(
        '[PermissionRepositoryImpl] fetchPermissionsFromBackend failed: $e',
      );
      rethrow;
    } finally {
      if (_generation == generation) _loadingApps.remove(appId);
    }
    return getPermissionsForApp(appId);
  }

  /// List all apps user has consented or interacted with from Backend
  Future<List<Map<String, dynamic>>> fetchUserAppsFromBackend() async {
    final session = authRepo?.currentSession;
    if (usersUrl != null &&
        session != null &&
        session.accessToken.isNotEmpty) {
      try {
        final client = httpClient ?? http.Client();
        final url = Uri.parse('$usersUrl/me/apps');
        final response = await client
            .get(
              url,
              headers: {'Authorization': 'Bearer ${session.accessToken}'},
            )
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final list = jsonDecode(response.body) as List<dynamic>;
          return list.cast<Map<String, dynamic>>();
        }
      } catch (e) {
        debugPrint(
          '[PermissionRepositoryImpl] fetchUserAppsFromBackend failed: $e',
        );
      }
    }

    return [];
  }

  void reset() {
    _generation++;
    _storage.clear();
    _loadedApps.clear();
    _loadingApps.clear();
    _revisions.clear();
  }

  Map<String, bool> getPermissionsForApp(String appId) {
    _checkUser();
    return Map.unmodifiable(_storage[appId] ?? {});
  }
}

final permissionRepositoryProvider = Provider<PermissionRepositoryImpl>((ref) {
  final endpoint = ref.watch(backendEndpointProvider);
  final authRepo = ref.watch(authRepositoryProvider);
  final httpClient = ref.watch(appHttpClientProvider);
  final repository = PermissionRepositoryImpl(
    usersUrl: endpoint.usersUrl,
    authRepo: authRepo,
    httpClient: httpClient,
  );
  ref.onDispose(repository.dispose);
  return repository;
});
