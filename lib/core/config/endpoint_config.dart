import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Configuration for backend API endpoints.
class EndpointConfig {
  final String baseUrl;

  const EndpointConfig({required this.baseUrl});

  static String normalize(String url) {
    var trimmed = url.trim();
    if (trimmed.isEmpty) {
      trimmed = 'http://localhost:3000';
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

class BackendEndpointNotifier extends StateNotifier<EndpointConfig> {
  final FlutterSecureStorage _storage;
  static const String storageKey = 'config_backend_endpoint';
  static const String defaultEndpoint = 'http://localhost:3000';

  BackendEndpointNotifier([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage(),
        super(EndpointConfig(baseUrl: EndpointConfig.normalize(defaultEndpoint))) {
    _loadStoredEndpoint();
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
    StateNotifierProvider<BackendEndpointNotifier, EndpointConfig>((ref) {
  return BackendEndpointNotifier();
});
