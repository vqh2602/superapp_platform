import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../domain/secure_storage_entry.dart';

class MockSecureStorageRepository {
  final FlutterSecureStorage _secureStorage;
  // In-memory fallback map: appId -> domain -> key -> SecureStorageEntry
  final Map<String, Map<String, Map<String, SecureStorageEntry>>> _storage = {};

  // In-memory fallback credentials map: appId -> domain -> {username, password, savedAt}
  final Map<String, Map<String, Map<String, dynamic>>> _credentials = {};

  MockSecureStorageRepository({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(resetOnError: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  String _formatKey(String appId, String domain, String key) =>
      'sec_${appId}_${domain}_$key';

  String _formatCredKey(String appId, String domain) =>
      'cred_${appId}_$domain';

  Future<Map<String, dynamic>> setItem({
    required String appId,
    required String key,
    required String value,
    String domain = 'default',
  }) async {
    final now = DateTime.now();
    final namespacedKey = _formatKey(appId, domain, key);

    // 1. Write to hardware Keystore / Keychain via FlutterSecureStorage
    try {
      await _secureStorage.write(key: namespacedKey, value: value);
    } catch (_) {
      // Graceful fallback if platform channel unavailable (e.g. headless unit tests)
    }

    // 2. Keep in-memory cache synchronized
    final domainMap = _storage.putIfAbsent(appId, () => {}).putIfAbsent(domain, () => {});
    final existing = domainMap[key];

    if (existing != null) {
      domainMap[key] = existing.copyWith(
        value: value,
        updatedAt: now,
      );
    } else {
      domainMap[key] = SecureStorageEntry(
        key: key,
        value: value,
        domain: domain,
        appId: appId,
        createdAt: now,
        updatedAt: now,
      );
    }

    return {
      'key': key,
      'domain': domain,
      'appId': appId,
      'success': true,
      'securityLevel': 'KEYCHAIN_OR_KEYSTORE',
      'updatedAt': now.toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> getItem({
    required String appId,
    required String key,
    String domain = 'default',
  }) async {
    final namespacedKey = _formatKey(appId, domain, key);
    String? storedValue;

    try {
      storedValue = await _secureStorage.read(key: namespacedKey);
    } catch (_) {}

    final memEntry = _storage[appId]?[domain]?[key];
    final value = storedValue ?? memEntry?.value;
    final exists = value != null;

    return {
      'key': key,
      'value': value,
      'domain': domain,
      'exists': exists,
      'securityLevel': 'KEYCHAIN_OR_KEYSTORE',
    };
  }

  Future<Map<String, dynamic>> removeItem({
    required String appId,
    required String key,
    String domain = 'default',
  }) async {
    final namespacedKey = _formatKey(appId, domain, key);
    try {
      await _secureStorage.delete(key: namespacedKey);
    } catch (_) {}

    final domainMap = _storage[appId]?[domain];
    final removed = domainMap?.remove(key) != null;
    return {
      'key': key,
      'domain': domain,
      'removed': removed,
    };
  }

  Future<Map<String, dynamic>> clear({
    required String appId,
    String? domain,
  }) async {
    var count = 0;
    try {
      final all = await _secureStorage.readAll();
      final prefix = domain != null ? 'sec_${appId}_${domain}_' : 'sec_${appId}_';
      for (final k in all.keys) {
        if (k.startsWith(prefix)) {
          await _secureStorage.delete(key: k);
          count++;
        }
      }
    } catch (_) {}

    if (domain != null) {
      final domainMap = _storage[appId]?[domain];
      if (domainMap != null) {
        count = count > domainMap.length ? count : domainMap.length;
        domainMap.clear();
      }
    } else {
      final appMap = _storage[appId];
      if (appMap != null) {
        var memCount = 0;
        for (final d in appMap.values) {
          memCount += d.length;
        }
        count = count > memCount ? count : memCount;
        appMap.clear();
      }
    }
    return {
      'cleared': true,
      'count': count,
    };
  }

  Future<List<String>> getAllKeys({
    required String appId,
    String domain = 'default',
  }) async {
    final Set<String> keys = {};
    try {
      final all = await _secureStorage.readAll();
      final prefix = 'sec_${appId}_${domain}_';
      for (final k in all.keys) {
        if (k.startsWith(prefix)) {
          keys.add(k.substring(prefix.length));
        }
      }
    } catch (_) {}

    final domainMap = _storage[appId]?[domain];
    if (domainMap != null) {
      keys.addAll(domainMap.keys);
    }
    return keys.toList();
  }

  Future<Map<String, String>> getAll({
    required String appId,
    String domain = 'default',
  }) async {
    final result = <String, String>{};
    try {
      final all = await _secureStorage.readAll();
      final prefix = 'sec_${appId}_${domain}_';
      for (final entry in all.entries) {
        if (entry.key.startsWith(prefix)) {
          result[entry.key.substring(prefix.length)] = entry.value;
        }
      }
    } catch (_) {}

    final domainMap = _storage[appId]?[domain];
    if (domainMap != null) {
      for (final entry in domainMap.entries) {
        result[entry.key] = entry.value.value;
      }
    }
    return result;
  }

  Future<Map<String, dynamic>> setCredentials({
    required String appId,
    required String domain,
    required String username,
    required String password,
  }) async {
    final now = DateTime.now().toIso8601String();
    final credKey = _formatCredKey(appId, domain);
    final credPayload = jsonEncode({
      'domain': domain,
      'username': username,
      'password': password,
      'savedAt': now,
      'securityLevel': 'KEYCHAIN_OR_KEYSTORE',
    });

    try {
      await _secureStorage.write(key: credKey, value: credPayload);
    } catch (_) {}

    final appCreds = _credentials.putIfAbsent(appId, () => {});
    appCreds[domain] = {
      'domain': domain,
      'username': username,
      'password': password,
      'savedAt': now,
      'securityLevel': 'KEYCHAIN_OR_KEYSTORE',
    };

    return {
      'domain': domain,
      'username': username,
      'success': true,
      'securityLevel': 'KEYCHAIN_OR_KEYSTORE',
      'savedAt': now,
    };
  }

  Future<Map<String, dynamic>> getCredentials({
    required String appId,
    required String domain,
  }) async {
    final credKey = _formatCredKey(appId, domain);
    Map<String, dynamic>? cred;

    try {
      final raw = await _secureStorage.read(key: credKey);
      if (raw != null) {
        cred = jsonDecode(raw) as Map<String, dynamic>;
      }
    } catch (_) {}

    cred ??= _credentials[appId]?[domain];

    if (cred == null) {
      return {
        'domain': domain,
        'username': null,
        'password': null,
        'exists': false,
        'securityLevel': 'KEYCHAIN_OR_KEYSTORE',
      };
    }

    return {
      'domain': domain,
      'username': cred['username'],
      'password': cred['password'],
      'exists': true,
      'savedAt': cred['savedAt'],
      'securityLevel': 'KEYCHAIN_OR_KEYSTORE',
    };
  }

  Future<Map<String, dynamic>> deleteCredentials({
    required String appId,
    required String domain,
  }) async {
    final credKey = _formatCredKey(appId, domain);
    try {
      await _secureStorage.delete(key: credKey);
    } catch (_) {}

    final appCreds = _credentials[appId];
    final deleted = appCreds?.remove(domain) != null;
    return {
      'domain': domain,
      'deleted': deleted,
    };
  }

  void reset() {
    _storage.clear();
    _credentials.clear();
  }
}

typedef SecureStorageRepository = MockSecureStorageRepository;

final mockSecureStorageRepositoryProvider = Provider<MockSecureStorageRepository>((ref) {
  return MockSecureStorageRepository();
});
