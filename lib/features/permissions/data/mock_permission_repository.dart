import 'package:flutter_riverpod/flutter_riverpod.dart';

class MockPermissionRepository {
  // Map of appId -> Map of capabilityKey -> isGranted
  final Map<String, Map<String, bool>> _storage = {};

  bool isGranted(String appId, String capability) {
    return _storage[appId]?[capability] ?? false;
  }

  bool isExplicitlyDenied(String appId, String capability) {
    final granted = _storage[appId]?[capability];
    return granted == false;
  }

  void setPermission(String appId, String capability, bool granted) {
    _storage.putIfAbsent(appId, () => {})[capability] = granted;
  }

  void grantAll(String appId, List<String> capabilities) {
    for (final cap in capabilities) {
      setPermission(appId, cap, true);
    }
  }

  void revokeAll(String appId) {
    _storage.remove(appId);
  }

  void reset() {
    _storage.clear();
  }

  Map<String, bool> getPermissionsForApp(String appId) {
    return Map.unmodifiable(_storage[appId] ?? {});
  }
}

final mockPermissionRepositoryProvider = Provider<MockPermissionRepository>((ref) {
  return MockPermissionRepository();
});
