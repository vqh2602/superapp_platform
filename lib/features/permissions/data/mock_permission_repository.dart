import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../../core/config/endpoint_config.dart';
import '../../authentication/data/mock_auth_repository.dart';
import '../../authentication/presentation/controllers/auth_controller.dart';

class MockPermissionRepository {
  final http.Client? httpClient;
  final String? usersUrl;
  final MockAuthRepository? authRepo;

  // Map of appId -> Map of capabilityKey -> isGranted
  final Map<String, Map<String, bool>> _storage = {};

  MockPermissionRepository({
    this.httpClient,
    this.usersUrl,
    this.authRepo,
  });

  bool isGranted(String appId, String capability) {
    return _storage[appId]?[capability] ?? false;
  }

  bool isExplicitlyDenied(String appId, String capability) {
    final granted = _storage[appId]?[capability];
    return granted == false;
  }

  void setPermission(String appId, String capability, bool granted) {
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
          .timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('[MockPermissionRepository] Sync permission to BE failed: $e');
    }
  }

  void grantAll(String appId, List<String> capabilities) {
    for (final cap in capabilities) {
      setPermission(appId, cap, true);
    }
  }

  void revokeAll(String appId) {
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
          .delete(
            url,
            headers: {
              'Authorization': 'Bearer $accessToken',
            },
          )
          .timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('[MockPermissionRepository] Revoke permissions on BE failed: $e');
    }
  }

  /// Fetch remote permissions & effective grants for a mini app from Backend
  Future<Map<String, bool>> fetchPermissionsFromBackend(String appId) async {
    final session = authRepo?.currentSession;
    if (usersUrl != null &&
        session != null &&
        session.accessToken.isNotEmpty &&
        !session.accessToken.startsWith('master_mock_')) {
      try {
        final client = httpClient ?? http.Client();
        final url = Uri.parse('$usersUrl/me/apps/$appId/permissions');
        final response = await client
            .get(
              url,
              headers: {
                'Authorization': 'Bearer ${session.accessToken}',
              },
            )
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final effective = (data['effectivePermissions'] as List<dynamic>?)?.cast<String>() ?? [];
          final decisions = (data['userDecisions'] as Map<String, dynamic>?) ?? {};

          final appMap = _storage.putIfAbsent(appId, () => {});
          decisions.forEach((k, v) {
            if (v is bool) appMap[k] = v;
          });
          for (final cap in effective) {
            appMap[cap] = true;
          }
          return Map.unmodifiable(appMap);
        }
      } catch (e) {
        debugPrint('[MockPermissionRepository] fetchPermissionsFromBackend failed: $e');
      }
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
              headers: {
                'Authorization': 'Bearer ${session.accessToken}',
              },
            )
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final list = jsonDecode(response.body) as List<dynamic>;
          return list.cast<Map<String, dynamic>>();
        }
      } catch (e) {
        debugPrint('[MockPermissionRepository] fetchUserAppsFromBackend failed: $e');
      }
    }

    return [];
  }

  void reset() {
    _storage.clear();
  }

  Map<String, bool> getPermissionsForApp(String appId) {
    return Map.unmodifiable(_storage[appId] ?? {});
  }
}

final mockPermissionRepositoryProvider = Provider<MockPermissionRepository>((ref) {
  final endpoint = ref.watch(backendEndpointProvider);
  final authRepo = ref.watch(mockAuthRepositoryProvider);
  return MockPermissionRepository(
    usersUrl: endpoint.usersUrl,
    authRepo: authRepo,
  );
});
