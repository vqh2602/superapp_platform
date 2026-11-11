/// Cấu hình toàn cục cho nền tảng SuperApp Platform.
///
/// Chứa các hằng số về tên ứng dụng, phiên bản, tên kênh Javascript Bridge,
/// các URL backend mặc định, thời gian sống của token và danh sách origin được phép.
class AppConfig {
  /// Tên định danh của ứng dụng SuperApp
  static const String appName = 'SuperApp';

  /// Phiên bản ứng dụng hiện tại
  static const String appVersion = '1.0.0';

  /// Tên đối tượng Javascript Channel được inject vào WebView Mini App
  static const String bridgeChannelName = 'FlutterBridge';

  /// URL máy chủ Backend mặc định (môi trường Localhost)
  static const String defaultBaseUrl = 'http://localhost:3000';

  /// URL máy chủ Backend Cloud triển khai trên Alwaysdata
  static const String alwaysdataBaseUrl = 'https://superappplatfrom.alwaysdata.net';

  /// URL REST API truy vấn Dynamic Catalog Mini App
  static const String catalogApiUrl = 'http://localhost:3000/api/v1/catalog';

  /// Thời hạn hiệu lực của mã ủy quyền OAuth2/PKCE (auth code) tính bằng giây
  static const int authCodeTtlSeconds = 60;

  /// Thời hạn hiệu lực của Access Token cấp cho Mini App tính bằng giây (5 phút)
  static const int miniAppTokenTtlSeconds = 300; // 5 minutes

  /// Danh sách các Origin/Domain được phép khởi chạy Mini App trong WebView
  static const List<String> allowedOrigins = [
    'miniapp://',
    'http://localhost',
    'http://127.0.0.1',
    'https://localhost',
  ];
}
