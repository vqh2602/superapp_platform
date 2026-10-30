import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageRepositoryImpl {
  final FlutterSecureStorage _secureStorage;
  SecureStorageRepositoryImpl({FlutterSecureStorage? secureStorage})
    : _secureStorage =
          secureStorage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );
  String _key(String appId, String domain, String key) =>
      'sec_${appId}_${domain}_$key';
  String _cred(String appId, String domain) => 'cred_${appId}_$domain';
  Future<Map<String, dynamic>> setItem({
    required String appId,
    required String key,
    required String value,
    String domain = 'default',
  }) async {
    await _secureStorage.write(key: _key(appId, domain, key), value: value);
    return {
      'key': key,
      'domain': domain,
      'appId': appId,
      'success': true,
      'securityLevel': 'KEYCHAIN_OR_KEYSTORE',
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> getItem({
    required String appId,
    required String key,
    String domain = 'default',
  }) async {
    final value = await _secureStorage.read(key: _key(appId, domain, key));
    return {
      'key': key,
      'domain': domain,
      'value': value,
      'exists': value != null,
      'securityLevel': 'KEYCHAIN_OR_KEYSTORE',
    };
  }

  Future<Map<String, dynamic>> removeItem({
    required String appId,
    required String key,
    String domain = 'default',
  }) async {
    final exists = await _secureStorage.containsKey(
      key: _key(appId, domain, key),
    );
    await _secureStorage.delete(key: _key(appId, domain, key));
    return {'key': key, 'domain': domain, 'removed': exists};
  }

  Future<Map<String, dynamic>> clear({
    required String appId,
    String? domain,
  }) async {
    final all = await _secureStorage.readAll();
    final prefix = domain == null ? 'sec_${appId}_' : 'sec_${appId}_${domain}_';
    final keys = all.keys.where((key) => key.startsWith(prefix)).toList();
    for (final key in keys) {
      await _secureStorage.delete(key: key);
    }
    return {'cleared': true, 'count': keys.length};
  }

  Future<Map<String, String>> getAll({
    required String appId,
    String domain = 'default',
  }) async {
    final all = await _secureStorage.readAll();
    final prefix = 'sec_${appId}_${domain}_';
    return {
      for (final e in all.entries)
        if (e.key.startsWith(prefix)) e.key.substring(prefix.length): e.value,
    };
  }

  Future<List<String>> getAllKeys({
    required String appId,
    String domain = 'default',
  }) async => (await getAll(appId: appId, domain: domain)).keys.toList();
  Future<Map<String, dynamic>> setCredentials({
    required String appId,
    required String domain,
    required String username,
    required String password,
  }) async {
    final savedAt = DateTime.now().toIso8601String();
    await _secureStorage.write(
      key: _cred(appId, domain),
      value: jsonEncode({
        'username': username,
        'password': password,
        'savedAt': savedAt,
      }),
    );
    return {
      'domain': domain,
      'username': username,
      'success': true,
      'securityLevel': 'KEYCHAIN_OR_KEYSTORE',
      'savedAt': savedAt,
    };
  }

  Future<Map<String, dynamic>> getCredentials({
    required String appId,
    required String domain,
  }) async {
    final raw = await _secureStorage.read(key: _cred(appId, domain));
    return {
      'domain': domain,
      'username': null,
      'password': null,
      'exists': raw != null,
      if (raw != null) ...(jsonDecode(raw) as Map<String, dynamic>),
      'securityLevel': 'KEYCHAIN_OR_KEYSTORE',
    };
  }

  Future<Map<String, dynamic>> deleteCredentials({
    required String appId,
    required String domain,
  }) async {
    final exists = await _secureStorage.containsKey(key: _cred(appId, domain));
    await _secureStorage.delete(key: _cred(appId, domain));
    return {'domain': domain, 'deleted': exists};
  }

  void reset() {}
}

final secureStorageRepositoryProvider =
    Provider<SecureStorageRepositoryImpl>(
      (ref) => SecureStorageRepositoryImpl(),
    );
