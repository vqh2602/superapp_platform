import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Quản lý lưu trữ bảo mật cục bộ (Keychain trên iOS / Keystore EncryptedSharedPreferences trên Android).
///
/// Kiến trúc Namespace & Khóa v2:
/// superapp:v2:<userHash>:<appHash>:<domainHash>:<keyHash>
///
/// Bảo đảm:
/// 1. Cách ly nghiêm ngặt theo tài khoản người dùng (`userHash`), chống đọc trộm dữ liệu giữa các user trên cùng thiết bị.
/// 2. Băm SHA-256 từng thành phần loại bỏ hoàn toàn rủi ro va chạm khóa (Key Collision) khi nối chuỗi.
/// 3. Phân định rõ ràng chính sách vòng đời: `clearUserData` khi logout và `clearAppData` khi gỡ app.
/// 4. Hạn chế API `getAll` tránh rò rỉ hàng loạt dữ liệu bí mật / credentials.
class SecureStorageRepositoryImpl {
  final FlutterSecureStorage _secureStorage;

  SecureStorageRepositoryImpl({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  static const String prefixV2 = 'superapp:v2';
  static const int defaultMaxBulkLimit = 50;

  /// Băm SHA-256 rút gọn 32 ký tự hex (128-bit entropy) chống va chạm khóa
  static String _hashComponent(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 32);
  }

  String _userHash(String? userId) {
    final effectiveUser =
        (userId != null && userId.isNotEmpty) ? userId : '__guest__';
    return _hashComponent('user:$effectiveUser');
  }

  String _appHash(String appId) => _hashComponent('app:$appId');

  String _domainHash(String domain) => _hashComponent('domain:$domain');

  String _keyHash(String key) => _hashComponent('key:$key');

  String _v2Key({
    String? userId,
    required String appId,
    required String domain,
    required String key,
  }) {
    return '$prefixV2:${_userHash(userId)}:${_appHash(appId)}:${_domainHash(domain)}:${_keyHash(key)}';
  }

  String _v2Cred({
    String? userId,
    required String appId,
    required String domain,
  }) {
    return '$prefixV2:${_userHash(userId)}:${_appHash(appId)}:${_domainHash(domain)}:__cred__';
  }

  /// Khóa v1 legacy phục vụ backward compatibility
  String _legacyKey(String appId, String domain, String key) =>
      'sec_${appId}_${domain}_$key';

  String _legacyCred(String appId, String domain) => 'cred_${appId}_$domain';

  /// Lưu một mục bảo mật với namespace cách ly theo user và app
  Future<Map<String, dynamic>> setItem({
    required String appId,
    required String key,
    required String value,
    String domain = 'default',
    String? userId,
  }) async {
    final v2Key = _v2Key(userId: userId, appId: appId, domain: domain, key: key);
    final now = DateTime.now().toIso8601String();

    // Lưu envelope bảo tồn key gốc và metadata
    final envelope = jsonEncode({
      'k': key,
      'v': value,
      'd': domain,
      'a': appId,
      'u': userId,
      't': now,
    });

    await _secureStorage.write(key: v2Key, value: envelope);

    return {
      'key': key,
      'domain': domain,
      'appId': appId,
      'userId': userId,
      'success': true,
      'securityLevel': 'KEYCHAIN_OR_KEYSTORE',
      'namespace': prefixV2,
      'updatedAt': now,
    };
  }

  /// Đọc một mục bảo mật theo đúng user và app namespace
  Future<Map<String, dynamic>> getItem({
    required String appId,
    required String key,
    String domain = 'default',
    String? userId,
  }) async {
    final v2Key = _v2Key(userId: userId, appId: appId, domain: domain, key: key);
    var raw = await _secureStorage.read(key: v2Key);

    // Fallback migration từ legacy v1 (nếu có)
    if (raw == null) {
      final legacyKey = _legacyKey(appId, domain, key);
      final legacyVal = await _secureStorage.read(key: legacyKey);
      if (legacyVal != null) {
        await setItem(
          appId: appId,
          key: key,
          value: legacyVal,
          domain: domain,
          userId: userId,
        );
        await _secureStorage.delete(key: legacyKey);
        raw = await _secureStorage.read(key: v2Key);
      }
    }

    String? extractedValue;
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic> && decoded.containsKey('v')) {
          extractedValue = decoded['v']?.toString();
        } else {
          extractedValue = raw;
        }
      } catch (_) {
        extractedValue = raw;
      }
    }

    return {
      'key': key,
      'domain': domain,
      'appId': appId,
      'userId': userId,
      'value': extractedValue,
      'exists': extractedValue != null,
      'securityLevel': 'KEYCHAIN_OR_KEYSTORE',
    };
  }

  /// Xóa một mục bảo mật
  Future<Map<String, dynamic>> removeItem({
    required String appId,
    required String key,
    String domain = 'default',
    String? userId,
  }) async {
    final v2Key = _v2Key(userId: userId, appId: appId, domain: domain, key: key);
    final existsV2 = await _secureStorage.containsKey(key: v2Key);
    await _secureStorage.delete(key: v2Key);

    final legacyKey = _legacyKey(appId, domain, key);
    final existsLegacy = await _secureStorage.containsKey(key: legacyKey);
    await _secureStorage.delete(key: legacyKey);

    return {
      'key': key,
      'domain': domain,
      'appId': appId,
      'userId': userId,
      'removed': existsV2 || existsLegacy,
    };
  }

  /// Xóa dữ liệu của Mini App trong một domain (hoặc toàn bộ domain) cho user này
  Future<Map<String, dynamic>> clear({
    required String appId,
    String? domain,
    String? userId,
  }) async {
    final userHash = _userHash(userId);
    final appHash = _appHash(appId);
    final prefix = domain == null
        ? '$prefixV2:$userHash:$appHash:'
        : '$prefixV2:$userHash:$appHash:${_domainHash(domain)}:';

    final all = await _secureStorage.readAll();
    final keys = all.keys.where((k) => k.startsWith(prefix)).toList();
    for (final k in keys) {
      await _secureStorage.delete(key: k);
    }

    // Dọn dẹp cả legacy v1
    final legacyPrefix =
        domain == null ? 'sec_${appId}_' : 'sec_${appId}_${domain}_';
    final legacyKeys =
        all.keys.where((k) => k.startsWith(legacyPrefix)).toList();
    for (final k in legacyKeys) {
      await _secureStorage.delete(key: k);
    }

    return {'cleared': true, 'count': keys.length + legacyKeys.length};
  }

  /// Lấy danh sách key-value (Có giới hạn maxLimit để tránh dump dữ liệu hàng loạt)
  /// Credentials (__cred__) tuyệt đối không trả về qua hàm này.
  Future<Map<String, String>> getAll({
    required String appId,
    String domain = 'default',
    String? userId,
    int maxLimit = defaultMaxBulkLimit,
  }) async {
    final userHash = _userHash(userId);
    final appHash = _appHash(appId);
    final domainHash = _domainHash(domain);
    final prefix = '$prefixV2:$userHash:$appHash:$domainHash:';

    final all = await _secureStorage.readAll();
    final result = <String, String>{};

    for (final e in all.entries) {
      if (result.length >= maxLimit) break;
      if (e.key.startsWith(prefix)) {
        // Hạn chế rò rỉ: Tuyệt đối không trả về credentials trong getAll
        if (e.key.endsWith(':__cred__')) continue;

        try {
          final decoded = jsonDecode(e.value);
          if (decoded is Map<String, dynamic> &&
              decoded.containsKey('k') &&
              decoded.containsKey('v')) {
            result[decoded['k'].toString()] = decoded['v'].toString();
            continue;
          }
        } catch (_) {}

        final suffix = e.key.substring(prefix.length);
        result[suffix] = e.value;
      }
    }

    // Fallback legacy v1 nếu v2 chưa có
    if (result.isEmpty) {
      final legacyPrefix = 'sec_${appId}_${domain}_';
      for (final e in all.entries) {
        if (result.length >= maxLimit) break;
        if (e.key.startsWith(legacyPrefix)) {
          final k = e.key.substring(legacyPrefix.length);
          result[k] = e.value;
        }
      }
    }

    return result;
  }

  /// Lấy danh sách keys thuộc domain
  Future<List<String>> getAllKeys({
    required String appId,
    String domain = 'default',
    String? userId,
    int maxLimit = defaultMaxBulkLimit,
  }) async =>
      (await getAll(
        appId: appId,
        domain: domain,
        userId: userId,
        maxLimit: maxLimit,
      ))
          .keys
          .toList();

  /// Lưu trữ Credentials độc lập
  Future<Map<String, dynamic>> setCredentials({
    required String appId,
    required String domain,
    required String username,
    required String password,
    String? userId,
  }) async {
    final savedAt = DateTime.now().toIso8601String();
    final v2Key = _v2Cred(userId: userId, appId: appId, domain: domain);
    await _secureStorage.write(
      key: v2Key,
      value: jsonEncode({
        'type': 'credential',
        'username': username,
        'password': password,
        'domain': domain,
        'appId': appId,
        'userId': userId,
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

  /// Lấy Credentials cho một domain cụ thể
  Future<Map<String, dynamic>> getCredentials({
    required String appId,
    required String domain,
    String? userId,
  }) async {
    final v2Key = _v2Cred(userId: userId, appId: appId, domain: domain);
    var raw = await _secureStorage.read(key: v2Key);

    if (raw == null) {
      final legacyKey = _legacyCred(appId, domain);
      final legacyRaw = await _secureStorage.read(key: legacyKey);
      if (legacyRaw != null) {
        await _secureStorage.write(key: v2Key, value: legacyRaw);
        await _secureStorage.delete(key: legacyKey);
        raw = legacyRaw;
      }
    }

    return {
      'domain': domain,
      'username': null,
      'password': null,
      'exists': raw != null,
      if (raw != null) ...(jsonDecode(raw) as Map<String, dynamic>),
      'securityLevel': 'KEYCHAIN_OR_KEYSTORE',
    };
  }

  /// Xóa Credentials cho domain
  Future<Map<String, dynamic>> deleteCredentials({
    required String appId,
    required String domain,
    String? userId,
  }) async {
    final v2Key = _v2Cred(userId: userId, appId: appId, domain: domain);
    final existsV2 = await _secureStorage.containsKey(key: v2Key);
    await _secureStorage.delete(key: v2Key);

    final legacyKey = _legacyCred(appId, domain);
    final existsLegacy = await _secureStorage.containsKey(key: legacyKey);
    await _secureStorage.delete(key: legacyKey);

    return {'domain': domain, 'deleted': existsV2 || existsLegacy};
  }

  /// Chính sách xóa sạch dữ liệu của người dùng khi đăng xuất (Logout Lifecycle Policy)
  Future<Map<String, dynamic>> clearUserData(String userId) async {
    final userHash = _hashComponent('user:$userId');
    final prefix = '$prefixV2:$userHash:';
    final all = await _secureStorage.readAll();
    final keys = all.keys.where((k) => k.startsWith(prefix)).toList();
    for (final k in keys) {
      await _secureStorage.delete(key: k);
    }
    return {'cleared': true, 'userId': userId, 'count': keys.length};
  }

  /// Chính sách xóa sạch dữ liệu của Mini App khi gỡ ứng dụng (Uninstall App Lifecycle Policy)
  Future<Map<String, dynamic>> clearAppData(String appId, {String? userId}) async {
    final appHash = _appHash(appId);
    final all = await _secureStorage.readAll();

    List<String> keysToDelete;
    if (userId != null && userId.isNotEmpty) {
      final userHash = _userHash(userId);
      final prefix = '$prefixV2:$userHash:$appHash:';
      keysToDelete = all.keys.where((k) => k.startsWith(prefix)).toList();
    } else {
      // Xóa trên mọi user namespace: superapp:v2:*:<appHash>:
      keysToDelete = all.keys.where((k) {
        final parts = k.split(':');
        return parts.length >= 5 &&
            parts[0] == 'superapp' &&
            parts[1] == 'v2' &&
            parts[3] == appHash;
      }).toList();
    }

    for (final k in keysToDelete) {
      await _secureStorage.delete(key: k);
    }

    // Xóa cả legacy v1
    final legacyPrefix = 'sec_${appId}_';
    final legacyCred = 'cred_${appId}_';
    final legacyKeys = all.keys
        .where((k) => k.startsWith(legacyPrefix) || k.startsWith(legacyCred))
        .toList();
    for (final k in legacyKeys) {
      await _secureStorage.delete(key: k);
    }

    return {
      'cleared': true,
      'appId': appId,
      'userId': userId,
      'count': keysToDelete.length + legacyKeys.length,
    };
  }

  void reset() {}
}

final secureStorageRepositoryProvider =
    Provider<SecureStorageRepositoryImpl>(
      (ref) => SecureStorageRepositoryImpl(),
    );
