// Triển khai kho lưu trữ bảo mật phần cứng (Secure Storage Repository Implementation).
//
// Quản lý việc lưu, đọc, xóa dữ liệu nhạy cảm và thông tin xác thực (Credentials)
// trong Keychain (iOS/macOS) và EncryptedSharedPreferences (Android) với cấu trúc namespace v2.
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Chính sách xử lý dữ liệu legacy khi không xác định được chủ sở hữu (Unverified Legacy Data Policy).
enum LegacyUnverifiedDataPolicy {
  /// Cách ly dữ liệu cũ vào namespace riêng biệt (`superapp:quarantine:legacy:...`)
  /// Ngăn chặn rò rỉ nhưng vẫn bảo lưu dữ liệu phục vụ đối soát, kiểm toán an ninh.
  quarantine,

  /// Xóa vĩnh viễn dữ liệu cũ không xác định được chủ sở hữu khỏi thiết bị.
  delete,
}

/// Quản lý lưu trữ bảo mật cục bộ (Keychain trên iOS / Keystore EncryptedSharedPreferences trên Android).
///
/// Kiến trúc Namespace & Khóa v2:
/// `superapp:v2:<userHash>:<appHash>:<domainHash>:<keyHash>`
///
/// Bảo đảm:
/// 1. Cách ly nghiêm ngặt theo tài khoản người dùng (`userHash`), chống đọc trộm dữ liệu giữa các user trên cùng thiết bị.
/// 2. Băm SHA-256 từng thành phần loại bỏ hoàn toàn rủi ro va chạm khóa (Key Collision) khi nối chuỗi.
/// 3. Phân định rõ ràng chính sách vòng đời: `clearUserData` khi logout và `clearAppData` khi gỡ app.
/// 4. Hạn chế API `getAll` tránh rò rỉ hàng loạt dữ liệu bí mật / credentials.
/// 5. Chống rò rỉ dữ liệu khi nâng cấp từ v1 (P0): Chỉ migrate dữ liệu legacy khi xác minh đúng chủ sở hữu,
///    tuyệt đối không chuyển giao dữ liệu không rõ chủ sở hữu sang tài khoản đang đăng nhập.
class SecureStorageRepositoryImpl {
  final FlutterSecureStorage _secureStorage;
  final LegacyUnverifiedDataPolicy legacyPolicy;

  SecureStorageRepositoryImpl({
    FlutterSecureStorage? secureStorage,
    this.legacyPolicy = LegacyUnverifiedDataPolicy.quarantine,
  })  : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  static const String prefixV2 = 'superapp:v2';
  static const String prefixQuarantine = 'superapp:quarantine:legacy';
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

  /// Trích xuất định danh chủ sở hữu (userId) từ chuỗi dữ liệu legacy (nếu có)
  static String? _extractLegacyOwner(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final owner = decoded['u'] ??
            decoded['userId'] ??
            decoded['owner'] ??
            decoded['user_id'];
        if (owner != null) {
          final s = owner.toString().trim();
          if (s.isNotEmpty) return s;
        }
      }
    } catch (_) {
      // Dữ liệu là chuỗi thô, không phải JSON -> Không xác định được chủ sở hữu
    }
    return null;
  }

  /// Trích xuất giá trị thực từ envelope hoặc trả về chuỗi thô
  static String _extractPayloadValue(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic> && decoded.containsKey('v')) {
        return decoded['v']?.toString() ?? raw;
      }
    } catch (_) {}
    return raw;
  }

  /// Xử lý dữ liệu legacy không xác định được chủ sở hữu theo chính sách bảo mật
  Future<void> _handleUnverifiedLegacyData({
    required String legacyKey,
    required String rawContent,
    required String appId,
    required String domain,
  }) async {
    if (legacyPolicy == LegacyUnverifiedDataPolicy.quarantine) {
      final quarantineKey = '$prefixQuarantine:$legacyKey';
      final quarantineEntry = jsonEncode({
        'originalKey': legacyKey,
        'appId': appId,
        'domain': domain,
        'quarantinedAt': DateTime.now().toIso8601String(),
        'reason': 'unverified_legacy_owner',
        'raw': rawContent,
      });
      await _secureStorage.write(key: quarantineKey, value: quarantineEntry);
    }
    // Luôn xóa khóa legacy không an toàn khỏi không gian hoạt động
    await _secureStorage.delete(key: legacyKey);
  }

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

  /// Đọc một mục bảo mật theo đúng user và app namespace.
  ///
  /// Bảo mật P0: Chỉ migrate khi xác minh được tài khoản sở hữu dữ liệu cũ.
  /// Tuyệt đối không gán dữ liệu không rõ chủ sở hữu sang tài khoản đang đăng nhập.
  Future<Map<String, dynamic>> getItem({
    required String appId,
    required String key,
    String domain = 'default',
    String? userId,
  }) async {
    final v2Key = _v2Key(userId: userId, appId: appId, domain: domain, key: key);
    var raw = await _secureStorage.read(key: v2Key);

    // Xử lý migration an toàn từ legacy v1 (nếu v2 chưa có)
    if (raw == null) {
      final legacyKey = _legacyKey(appId, domain, key);
      final legacyVal = await _secureStorage.read(key: legacyKey);
      if (legacyVal != null) {
        final legacyOwner = _extractLegacyOwner(legacyVal);
        final valToMigrate = _extractPayloadValue(legacyVal);

        if (userId != null && userId.isNotEmpty && legacyOwner == userId) {
          // Xác minh đúng chủ sở hữu: Cho phép migrate sang v2 cho user này
          await setItem(
            appId: appId,
            key: key,
            value: valToMigrate,
            domain: domain,
            userId: userId,
          );
          await _secureStorage.delete(key: legacyKey);
          raw = await _secureStorage.read(key: v2Key);
        } else if (legacyOwner != null && legacyOwner.isNotEmpty) {
          // Thuộc người dùng khác: Chuyển về namespace của người đó, không gán cho user hiện tại
          await setItem(
            appId: appId,
            key: key,
            value: valToMigrate,
            domain: domain,
            userId: legacyOwner,
          );
          await _secureStorage.delete(key: legacyKey);
          raw = null;
        } else {
          // Không xác định được chủ sở hữu: Cách ly hoặc xóa, tuyệt đối không gán cho user hiện tại
          await _handleUnverifiedLegacyData(
            legacyKey: legacyKey,
            rawContent: legacyVal,
            appId: appId,
            domain: domain,
          );
          raw = null;
        }
      }
    }

    String? extractedValue;
    if (raw != null) {
      extractedValue = _extractPayloadValue(raw);
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
    var removedLegacy = false;
    final legacyVal = await _secureStorage.read(key: legacyKey);
    if (legacyVal != null) {
      final legacyOwner = _extractLegacyOwner(legacyVal);
      if (userId != null && userId.isNotEmpty && legacyOwner == userId) {
        await _secureStorage.delete(key: legacyKey);
        removedLegacy = true;
      } else if (legacyOwner == null) {
        await _handleUnverifiedLegacyData(
          legacyKey: legacyKey,
          rawContent: legacyVal,
          appId: appId,
          domain: domain,
        );
        removedLegacy = true;
      }
      // Dữ liệu thuộc user khác -> Không xóa dữ liệu của họ
    }

    return {
      'key': key,
      'domain': domain,
      'appId': appId,
      'userId': userId,
      'removed': existsV2 || removedLegacy,
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

    // Dọn dẹp an toàn legacy v1: Chỉ xóa khóa thuộc về user này hoặc không rõ chủ sở hữu
    final legacyPrefix =
        domain == null ? 'sec_${appId}_' : 'sec_${appId}_${domain}_';
    final legacyKeys =
        all.keys.where((k) => k.startsWith(legacyPrefix)).toList();
    var clearedLegacyCount = 0;
    for (final k in legacyKeys) {
      final raw = all[k];
      if (raw != null) {
        final legacyOwner = _extractLegacyOwner(raw);
        if (userId != null && userId.isNotEmpty && legacyOwner == userId) {
          await _secureStorage.delete(key: k);
          clearedLegacyCount++;
        } else if (legacyOwner == null) {
          await _handleUnverifiedLegacyData(
            legacyKey: k,
            rawContent: raw,
            appId: appId,
            domain: domain ?? 'default',
          );
          clearedLegacyCount++;
        }
      }
    }

    return {'cleared': true, 'count': keys.length + clearedLegacyCount};
  }

  /// Lấy danh sách key-value (Có giới hạn maxLimit để tránh dump dữ liệu hàng loạt).
  /// Credentials (__cred__) tuyệt đối không trả về qua hàm này.
  ///
  /// Bảo mật P0: Không tự động chuyển giao dữ liệu legacy không rõ chủ sở hữu sang tài khoản hiện tại.
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

    // Xử lý migration an toàn từ legacy v1 (nếu có)
    final legacyPrefix = 'sec_${appId}_${domain}_';
    final legacyEntries =
        all.entries.where((e) => e.key.startsWith(legacyPrefix)).toList();

    for (final e in legacyEntries) {
      final legacyOwner = _extractLegacyOwner(e.value);
      final rawKey = e.key.substring(legacyPrefix.length);
      final itemVal = _extractPayloadValue(e.value);

      if (userId != null && userId.isNotEmpty && legacyOwner == userId) {
        // Xác minh đúng chủ sở hữu: Migrate sang v2 cho user này
        await setItem(
          appId: appId,
          key: rawKey,
          value: itemVal,
          domain: domain,
          userId: userId,
        );
        await _secureStorage.delete(key: e.key);
        if (result.length < maxLimit && !result.containsKey(rawKey)) {
          result[rawKey] = itemVal;
        }
      } else if (legacyOwner != null && legacyOwner.isNotEmpty) {
        // Thuộc người dùng khác: Chuyển về namespace của người đó
        await setItem(
          appId: appId,
          key: rawKey,
          value: itemVal,
          domain: domain,
          userId: legacyOwner,
        );
        await _secureStorage.delete(key: e.key);
        // Tuyệt đối không đưa vào result của user hiện tại
      } else {
        // Không xác định được chủ sở hữu: Cách ly hoặc xóa theo chính sách
        await _handleUnverifiedLegacyData(
          legacyKey: e.key,
          rawContent: e.value,
          appId: appId,
          domain: domain,
        );
        // Tuyệt đối không đưa vào result của user hiện tại
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

  /// Lấy Credentials cho một domain cụ thể.
  ///
  /// Bảo mật P0: Chỉ migrate credentials khi xác minh đúng chủ sở hữu.
  /// Tuyệt đối không trả về credentials của tài khoản khác hoặc không rõ chủ sở hữu.
  Future<Map<String, dynamic>> getCredentials({
    required String appId,
    required String domain,
    String? userId,
  }) async {
    final v2Key = _v2Cred(userId: userId, appId: appId, domain: domain);
    var raw = await _secureStorage.read(key: v2Key);

    // Xử lý migration an toàn từ legacy v1 (nếu v2 chưa có)
    if (raw == null) {
      final legacyKey = _legacyCred(appId, domain);
      final legacyRaw = await _secureStorage.read(key: legacyKey);
      if (legacyRaw != null) {
        final legacyOwner = _extractLegacyOwner(legacyRaw);

        if (userId != null && userId.isNotEmpty && legacyOwner == userId) {
          // Xác minh đúng chủ sở hữu: Migrate sang v2 cho user này
          await _secureStorage.write(key: v2Key, value: legacyRaw);
          await _secureStorage.delete(key: legacyKey);
          raw = legacyRaw;
        } else if (legacyOwner != null && legacyOwner.isNotEmpty) {
          // Thuộc người dùng khác: Di chuyển sang v2 key của người đó
          final ownerV2Key = _v2Cred(userId: legacyOwner, appId: appId, domain: domain);
          await _secureStorage.write(key: ownerV2Key, value: legacyRaw);
          await _secureStorage.delete(key: legacyKey);
          raw = null;
        } else {
          // Không xác định được chủ sở hữu: Cách ly hoặc xóa, không chuyển cho user đang đăng nhập
          await _handleUnverifiedLegacyData(
            legacyKey: legacyKey,
            rawContent: legacyRaw,
            appId: appId,
            domain: domain,
          );
          raw = null;
        }
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
    var removedLegacy = false;
    final legacyRaw = await _secureStorage.read(key: legacyKey);
    if (legacyRaw != null) {
      final legacyOwner = _extractLegacyOwner(legacyRaw);
      if (userId != null && userId.isNotEmpty && legacyOwner == userId) {
        await _secureStorage.delete(key: legacyKey);
        removedLegacy = true;
      } else if (legacyOwner == null) {
        await _handleUnverifiedLegacyData(
          legacyKey: legacyKey,
          rawContent: legacyRaw,
          appId: appId,
          domain: domain,
        );
        removedLegacy = true;
      }
      // Dữ liệu thuộc user khác -> Không xóa credentials của họ
    }

    return {'domain': domain, 'deleted': existsV2 || removedLegacy};
  }

  /// Lấy danh sách các khóa legacy đã bị cách ly do không xác định được chủ sở hữu
  Future<List<String>> getQuarantinedKeys({String? appId}) async {
    final all = await _secureStorage.readAll();
    final prefix = '$prefixQuarantine:';
    final keys = all.keys.where((k) => k.startsWith(prefix)).toList();
    if (appId == null) return keys;

    final filtered = <String>[];
    for (final k in keys) {
      final raw = all[k];
      if (raw != null) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic> && decoded['appId'] == appId) {
            filtered.add(k);
          }
        } catch (_) {}
      }
    }
    return filtered;
  }

  /// Xóa sạch các mục dữ liệu đã bị cách ly
  Future<int> purgeQuarantine({String? appId}) async {
    final keys = await getQuarantinedKeys(appId: appId);
    for (final k in keys) {
      await _secureStorage.delete(key: k);
    }
    return keys.length;
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

    // Xóa cả quarantined entries của app này (nếu có)
    await purgeQuarantine(appId: appId);

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
