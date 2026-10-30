import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../../core/config/endpoint_config.dart';
import '../../../../core/errors/bridge_error.dart';
import '../../authentication/data/mock_auth_repository.dart';
import '../../authentication/presentation/controllers/auth_controller.dart';

class PermissionRepositoryImpl {
  final http.Client? httpClient;
  final String? usersUrl;
  final MockAuthRepository? authRepo;

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

  void setPermission(String appId, String capability, bool granted) {
    _checkUser();
    _revisions[appId] = (_revisions[appId] ?? 0) + 1;
    _storage.putIfAbsent(appId, () => {})[capability] = granted;

    // Asynchronously sync decision to Backend PostgreSQL if authenticated
    final session = authRepo?.currentSession;
    if (usersUrl != null &&
        session != null &&
        session.accessToken.isNotEmpty &&
        !session.accessToken.startsWith('master_mock_')) {
      _syncDecisionToBackend(appId, capability, granted, session.accessToken);
    }
  }

  Future<void> _syncDecisionToBackend(
    String appId,
    String capability,
    bool granted,
    String accessToken,
  ) async {
    try {
      final client = httpClient ?? http.Client();
      final url = Uri.parse('$usersUrl/me/apps/$appId/permissions');
      await client
          .put(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
            body: jsonEncode({
              'permissions': [capability],
              'granted': granted,
            }),
          )
          .timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint(
        '[MockPermissionRepository] Sync permission to BE skipped/offline: $e',
      );
    }
  }

  void grantAll(String appId, List<String> capabilities) {
    for (final cap in capabilities) {
      setPermission(appId, cap, true);
    }
  }

  void revokeAll(String appId) {
    _checkUser();
    _revisions[appId] = (_revisions[appId] ?? 0) + 1;
    _storage.remove(appId);

    final session = authRepo?.currentSession;
    if (usersUrl != null &&
        session != null &&
        session.accessToken.isNotEmpty &&
        !session.accessToken.startsWith('master_mock_')) {
      _revokeAllOnBackend(appId, session.accessToken);
    }
  }

  Future<void> _revokeAllOnBackend(String appId, String accessToken) async {
    try {
      final client = httpClient ?? http.Client();
      final url = Uri.parse('$usersUrl/me/apps/$appId/permissions');
      await client
          .delete(url, headers: {'Authorization': 'Bearer $accessToken'})
          .timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint(
        '[MockPermissionRepository] Revoke permissions on BE skipped/offline: $e',
      );
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
          session.accessToken.isNotEmpty &&
          !session.accessToken.startsWith('master_mock_')) {
        final client = httpClient ?? http.Client();
        final response = await client
            .get(
              Uri.parse('$usersUrl/me/apps/$appId/permissions'),
              headers: {'Authorization': 'Bearer ${session.accessToken}'},
            )
            .timeout(const Duration(seconds: 10));
        _checkUser();
        // Never apply a previous account's response or overwrite a newer choice.
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
              // A saved grant still needs platform/manifest approval.
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
        '[MockPermissionRepository] fetchPermissionsFromBackend failed: $e',
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
        session.accessToken.isNotEmpty &&
        !session.accessToken.startsWith('master_mock_')) {
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
          '[MockPermissionRepository] fetchUserAppsFromBackend failed: $e',
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

final mockPermissionRepositoryProvider = Provider<PermissionRepositoryImpl>((
  ref,
) {
  final endpoint = ref.watch(backendEndpointProvider);
  final authRepo = ref.watch(mockAuthRepositoryProvider);
  final repository = PermissionRepositoryImpl(
    usersUrl: endpoint.usersUrl,
    authRepo: authRepo,
  );
  ref.onDispose(repository.dispose);
  return repository;
});

typedef MockPermissionRepository = PermissionRepositoryImpl;
