// Cấu hình và quản lý điểm cuối máy chủ Backend (Backend Endpoint).
//
// Hỗ trợ chuẩn hóa URL máy chủ, chuyển đổi linh hoạt giữa Localhost, Alwaysdata
// hoặc URL máy chủ tùy chỉnh và lưu trữ cấu hình vào Secure Storage.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Lớp đại diện cấu hình endpoint máy chủ backend của SuperApp.
class EndpointConfig {
  /// Địa chỉ URL gốc của máy chủ backend (vd: http://localhost:3000)
  final String baseUrl;

  const EndpointConfig({required this.baseUrl});

  /// Endpoint Localhost mặc định khi phát triển cục bộ
  static const String localhostEndpoint = 'http://localhost:3000';

  /// Endpoint máy chủ đám mây Alwaysdata
  static const String alwaysdataEndpoint = 'https://superappplatfrom.alwaysdata.net';

  /// Chuẩn hóa chuỗi URL (xóa khoảng trắng thừa, xóa dấu `/` và `/api/v1` ở cuối)
  static String normalize(String url) {
    var trimmed = url.trim();
    if (trimmed.isEmpty) {
      trimmed = localhostEndpoint;
    }
    // Remove trailing slashes
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    // Remove trailing /api/v1 if typed
    if (trimmed.endsWith('/api/v1')) {
      trimmed = trimmed.substring(0, trimmed.length - '/api/v1'.length);
    }
    return trimmed;
  }

  /// Kiểm tra xem endpoint hiện tại có phải là máy chủ cục bộ hay không
  bool get isLocalhost =>
      baseUrl.contains('localhost') || baseUrl.contains('127.0.0.1');

  /// Kiểm tra xem endpoint hiện tại có phải là máy chủ Alwaysdata hay không
  bool get isAlwaysdata =>
      baseUrl.contains('superappplatfrom.alwaysdata.net');

  /// Trả về nhãn ngắn gọn hiển thị trên thanh công cụ giao diện
  String get shortLabel {
    if (isAlwaysdata) return 'Alwaysdata';
    if (isLocalhost) return 'Localhost';
    final uri = Uri.tryParse(baseUrl);
    return uri?.host.isNotEmpty == true ? uri!.host : baseUrl;
  }

  /// Đường dẫn cơ sở của API phiên bản 1 (/api/v1)
  String get apiBaseUrl => '$baseUrl/api/v1';

  /// URL API truy vấn danh mục Mini App
  String get catalogUrl => '$apiBaseUrl/catalog';

  /// URL API xác thực người dùng
  String get authUrl => '$apiBaseUrl/auth';

  /// URL API tài nguyên tĩnh của Mini App
  String get miniappUrl => '$apiBaseUrl/miniapp';

  /// URL API quản lý hồ sơ người dùng
  String get usersUrl => '$apiBaseUrl/users';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EndpointConfig &&
          runtimeType == other.runtimeType &&
          baseUrl == other.baseUrl;

  @override
  int get hashCode => baseUrl.hashCode;
}

/// Notifier quản lý cấu hình điểm cuối Backend và đồng bộ vào Secure Storage.
class BackendEndpointNotifier extends Notifier<EndpointConfig> {
  final FlutterSecureStorage _storage;
  static const String storageKey = 'config_backend_endpoint';
  static const String defaultEndpoint = 'http://localhost:3000';

  BackendEndpointNotifier([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  EndpointConfig build() {
    _loadStoredEndpoint();
    return EndpointConfig(baseUrl: EndpointConfig.normalize(defaultEndpoint));
  }

  /// Tải endpoint đã lưu từ secure storage (nếu có)
  Future<void> _loadStoredEndpoint() async {
    try {
      final saved = await _storage.read(key: storageKey);
      if (saved != null && saved.trim().isNotEmpty) {
        state = EndpointConfig(baseUrl: EndpointConfig.normalize(saved));
      }
    } catch (_) {
      // Fallback to default in case storage is unavailable (e.g. headless tests)
    }
  }

  /// Cập nhật endpoint mới và lưu trữ vào secure storage
  Future<void> setEndpoint(String url) async {
    final normalized = EndpointConfig.normalize(url);
    state = EndpointConfig(baseUrl: normalized);
    try {
      await _storage.write(key: storageKey, value: normalized);
    } catch (_) {}
  }
}

/// Provider cung cấp trạng thái cấu hình Backend Endpoint hiện tại của SuperApp
final backendEndpointProvider =
    NotifierProvider<BackendEndpointNotifier, EndpointConfig>(
  BackendEndpointNotifier.new,
);
