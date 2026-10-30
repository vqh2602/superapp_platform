import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Configuration for backend API endpoints.
class EndpointConfig {
  final String baseUrl;

  const EndpointConfig({required this.baseUrl});

  static const String localhostEndpoint = 'http://localhost:3000';
  static const String alwaysdataEndpoint = 'https://superappplatfrom.alwaysdata.net';

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

  bool get isLocalhost =>
      baseUrl.contains('localhost') || baseUrl.contains('127.0.0.1');

  bool get isAlwaysdata =>
      baseUrl.contains('superappplatfrom.alwaysdata.net');

  String get shortLabel {
    if (isAlwaysdata) return 'Alwaysdata';
    if (isLocalhost) return 'Localhost';
    final uri = Uri.tryParse(baseUrl);
    return uri?.host.isNotEmpty == true ? uri!.host : baseUrl;
  }

  String get apiBaseUrl => '$baseUrl/api/v1';
  String get catalogUrl => '$apiBaseUrl/catalog';
  String get authUrl => '$apiBaseUrl/auth';
  String get miniappUrl => '$apiBaseUrl/miniapp';
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

  Future<void> setEndpoint(String url) async {
    final normalized = EndpointConfig.normalize(url);
    state = EndpointConfig(baseUrl: normalized);
    try {
      await _storage.write(key: storageKey, value: normalized);
    } catch (_) {}
  }
}

final backendEndpointProvider =
    NotifierProvider<BackendEndpointNotifier, EndpointConfig>(
  BackendEndpointNotifier.new,
);
