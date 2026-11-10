import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/endpoint_config.dart';
import '../../features/mini_app_catalog/domain/mini_app_manifest.dart';

/// Kết quả kiểm tra an toàn URL khởi chạy Mini App.
class UrlValidationResult {
  final bool isValid;
  final String? errorMessage;
  final Uri? uri;

  const UrlValidationResult({
    required this.isValid,
    this.errorMessage,
    this.uri,
  });

  factory UrlValidationResult.valid(Uri uri) =>
      UrlValidationResult(isValid: true, uri: uri);

  factory UrlValidationResult.invalid(String message) =>
      UrlValidationResult(isValid: false, errorMessage: message);
}

/// Chính sách bảo mật và cô lập môi trường WebView cho Mini App (Security Isolation Policy).
/// Đảm bảo Mini App chỉ chạy trên nguồn đáng tin cậy, không bị tấn công điều hướng
/// và không rò rỉ quyền Bridge cho các trang bên ngoài.
class MiniAppSecurityPolicy {
  /// Các domain phân phối Mini App chính thức và đáng tin cậy.
  static const List<String> defaultTrustedDomains = [
    'superappplatfrom.alwaysdata.net',
    'alwaysdata.net',
    'apps.example.com',
    'example.com',
  ];

  /// Các scheme nguy hiểm bị cấm tuyệt đối bên trong WebView.
  static const Set<String> blockedSchemes = {
    'javascript',
    'data',
    'file',
    'blob',
    'content',
    'about',
  };

  /// Kiểm tra scheme có thuộc nhóm bị cấm hay không.
  static bool isBlockedScheme(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme.isEmpty) return false;
    return blockedSchemes.contains(scheme);
  }

  /// Kiểm tra địa chỉ có phải là loopback / mạng cục bộ (chỉ cho phép trong dev / debug).
  static bool isLocalAddress(Uri uri) {
    final host = uri.host.toLowerCase();
    if (host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2') {
      return true;
    }
    // Dải IP Private: 192.168.x.x, 10.x.x.x, 172.16-31.x.x
    if (RegExp(r'^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)')
        .hasMatch(host)) {
      return true;
    }
    return false;
  }

  /// Kiểm tra scheme hợp lệ (Production bắt buộc HTTPS; Debug/Dev cho phép thêm HTTP cục bộ).
  static bool isValidScheme(Uri uri, {bool isReleaseMode = kReleaseMode}) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'https') return true;
    if (!isReleaseMode && scheme == 'http' && isLocalAddress(uri)) {
      return true;
    }
    return false;
  }

  /// Trích xuất danh sách các host/domain tin cậy cho một Mini App cụ thể.
  static Set<String> getTrustedHosts({
    required MiniAppManifest manifest,
    required String backendBaseUrl,
    bool isReleaseMode = kReleaseMode,
  }) {
    final hosts = <String>{};

    // 1. Host từ backend endpoint đang cấu hình
    final backendUri = Uri.tryParse(backendBaseUrl);
    if (backendUri != null && backendUri.host.isNotEmpty) {
      hosts.add(backendUri.host.toLowerCase());
    }

    // 2. Các domain phân phối tin cậy mặc định & subdomain cô lập theo appId
    for (final domain in defaultTrustedDomains) {
      hosts.add(domain.toLowerCase());
      // Hỗ trợ subdomain cô lập riêng từng Mini App: vd app-123.apps.example.com
      hosts.add('${manifest.id.toLowerCase()}.$domain');
      hosts.add('${manifest.id.toLowerCase().replaceAll('_', '-')}.$domain');
    }

    // 3. Cho phép địa chỉ mạng cục bộ trong môi trường dev / test
    if (!isReleaseMode) {
      hosts.addAll({'localhost', '127.0.0.1', '10.0.2.2'});
      if (backendUri != null && isLocalAddress(backendUri)) {
        hosts.add(backendUri.host.toLowerCase());
      }
      // Hỗ trợ host từ chính entryUrl trong môi trường dev / mock test
      final entryUri = Uri.tryParse(manifest.entryUrl);
      if (entryUri != null && entryUri.host.isNotEmpty) {
        hosts.add(entryUri.host.toLowerCase());
      }
    }

    // 4. Các domain được khai báo tường minh trong schema/manifest (allowedOrigins / trustedDomains)
    final rawOrigins = manifest.schema?['trustedDomains'] ??
        manifest.schema?['allowedOrigins'];
    if (rawOrigins is List) {
      for (final item in rawOrigins) {
        if (item is String && item.isNotEmpty) {
          final parsed = Uri.tryParse(item);
          final host = parsed?.host.isNotEmpty == true ? parsed!.host : item;
          hosts.add(host.toLowerCase());
        }
      }
    }

    return hosts;
  }

  /// Kiểm tra URL có thuộc phạm vi phân phối an toàn của Mini App hay không.
  static bool isTrustedMiniAppUrl(
    Uri uri, {
    required MiniAppManifest manifest,
    required String backendBaseUrl,
    bool isReleaseMode = kReleaseMode,
  }) {
    // 1. Kiểm tra scheme
    if (!isValidScheme(uri, isReleaseMode: isReleaseMode)) {
      return false;
    }

    // 2. Kiểm tra host
    final targetHost = uri.host.toLowerCase();
    if (targetHost.isEmpty) return false;

    final trustedHosts = getTrustedHosts(
      manifest: manifest,
      backendBaseUrl: backendBaseUrl,
      isReleaseMode: isReleaseMode,
    );

    bool hostMatches = false;
    for (final trusted in trustedHosts) {
      if (targetHost == trusted || targetHost.endsWith('.$trusted')) {
        hostMatches = true;
        break;
      }
    }

    if (!hostMatches) {
      return false;
    }

    // 3. Ràng buộc đường dẫn khi dùng chung origin backend (/api/v1/miniapps/{appId}/...)
    final backendUri = Uri.tryParse(backendBaseUrl);
    final isSharedBackend =
        backendUri != null && targetHost == backendUri.host.toLowerCase();

    if (isSharedBackend && uri.path.startsWith('/api/v1/miniapps/')) {
      final segments = uri.pathSegments;
      // Format: /api/v1/miniapps/<targetAppId>/<version>/dist/...
      if (segments.length >= 4) {
        final pathAppId = segments[3].toLowerCase();
        final ownId = manifest.id.toLowerCase();
        final isOwnApp = pathAppId == ownId;
        final isSharedSchema =
            manifest.isSchemaApp && pathAppId == 'schema_runtime';
        if (!isOwnApp && !isSharedSchema) {
          return false; // Cố gắng truy cập tài nguyên của Mini App khác trên cùng origin
        }
      }
    }

    return true;
  }

  /// Xác thực URL khởi chạy (Entry URL) trước khi tải vào WebView.
  static UrlValidationResult validateEntryUrl(
    String rawUrl, {
    required MiniAppManifest manifest,
    required String backendBaseUrl,
    bool isReleaseMode = kReleaseMode,
  }) {
    // Tài nguyên đóng gói cục bộ trong Flutter Assets
    if (manifest.isAsset && rawUrl.startsWith('assets/')) {
      return UrlValidationResult.valid(Uri.parse(rawUrl));
    }

    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !uri.hasScheme) {
      return UrlValidationResult.invalid('URL khởi chạy không đúng định dạng: $rawUrl');
    }

    if (isBlockedScheme(uri)) {
      return UrlValidationResult.invalid(
        'Giao thức "${uri.scheme}" bị cấm tuyệt đối vì lý do an toàn bảo mật',
      );
    }

    if (!isValidScheme(uri, isReleaseMode: isReleaseMode)) {
      return UrlValidationResult.invalid(
        isReleaseMode
            ? 'Chỉ chấp nhận giao thức HTTPS trên môi trường Production'
            : 'Giao thức "${uri.scheme}" không hợp lệ. Chỉ chấp nhận HTTPS (hoặc HTTP cục bộ khi debug)',
      );
    }

    if (!isTrustedMiniAppUrl(
      uri,
      manifest: manifest,
      backendBaseUrl: backendBaseUrl,
      isReleaseMode: isReleaseMode,
    )) {
      return UrlValidationResult.invalid(
        'Tên miền "${uri.host}" hoặc đường dẫn không nằm trong danh sách phân phối Mini App đáng tin cậy',
      );
    }

    return UrlValidationResult.valid(uri);
  }

  /// Kiểm tra xem điều hướng có phải là liên kết ngoài cần mở bằng trình duyệt hệ thống không.
  static bool isExternalNavigation(
    Uri targetUri, {
    required MiniAppManifest manifest,
    required String backendBaseUrl,
    bool isReleaseMode = kReleaseMode,
  }) {
    return !isTrustedMiniAppUrl(
      targetUri,
      manifest: manifest,
      backendBaseUrl: backendBaseUrl,
      isReleaseMode: isReleaseMode,
    );
  }

  /// Mở liên kết ngoài an toàn bằng trình duyệt mặc định của hệ thống.
  static Future<bool> openExternalUrl(Uri uri) async {
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[MiniAppSecurityPolicy] Lỗi khi mở URL ngoài $uri: $e');
    }
    return false;
  }

  /// Xác thực nguồn gốc (Origin) của trang WebView đang gọi Bridge Action.
  static bool validateCallerOrigin({
    required String? currentUrl,
    required MiniAppManifest manifest,
    required String backendBaseUrl,
    bool isReleaseMode = kReleaseMode,
  }) {
    if (currentUrl == null || currentUrl.isEmpty) {
      // Trường hợp asset cục bộ hoặc mock test không có WebViewController thật
      if (manifest.isAsset || !isReleaseMode) return true;
      return false;
    }

    final uri = Uri.tryParse(currentUrl);
    if (uri == null) return false;

    // Cho phép asset file:/// trong ứng dụng đóng gói
    if (manifest.isAsset &&
        (uri.scheme == 'file' || currentUrl.contains('flutter_assets'))) {
      return true;
    }

    return isTrustedMiniAppUrl(
      uri,
      manifest: manifest,
      backendBaseUrl: backendBaseUrl,
      isReleaseMode: isReleaseMode,
    );
  }
}
