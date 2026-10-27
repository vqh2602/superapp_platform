/// Global configuration for the Super App platform.
class AppConfig {
  static const String appName = 'SuperApp';
  static const String appVersion = '1.0.0';
  static const String bridgeChannelName = 'FlutterBridge';

  /// Default Backend Base URL
  static const String defaultBaseUrl = 'http://localhost:3000';

  /// Catalog REST API URL for Dynamic Mini App Registry
  static const String catalogApiUrl = 'http://localhost:3000/api/v1/catalog';

  /// Auth code expiration in seconds (spec: 60s)
  static const int authCodeTtlSeconds = 60;

  /// Mini App simulated access token TTL in seconds
  static const int miniAppTokenTtlSeconds = 300; // 5 minutes

  /// Allowed origins for Mini Apps
  static const List<String> allowedOrigins = [
    'miniapp://',
    'http://localhost',
    'http://127.0.0.1',
    'https://localhost',
  ];
}
