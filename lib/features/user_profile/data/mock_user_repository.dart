import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../../core/config/endpoint_config.dart';
import '../../authentication/data/mock_auth_repository.dart';
import '../../authentication/domain/models/mock_user.dart';
import '../../authentication/presentation/controllers/auth_controller.dart';
import '../../../../core/errors/bridge_error.dart';
import '../domain/user_profile_model.dart';

class MockUserRepository {
  final MockAuthRepository authRepository;
  final http.Client? httpClient;
  final String? authUrl;

  MockUserRepository({
    required this.authRepository,
    this.httpClient,
    this.authUrl,
  });

  UserProfileModel getProfile() {
    final user = authRepository.currentUser;
    if (user == null || !authRepository.isAuthenticated) {
      throw BridgeError.authRequired();
    }

    return UserProfileModel(
      id: user.id,
      name: user.name,
      phone: user.phone,
      role: user.role,
      email: user.email,
      avatarUrl: user.avatarUrl,
    );
  }

  Map<String, dynamic> getBasicInfo() {
    final user = authRepository.currentUser;
    if (user == null || !authRepository.isAuthenticated) {
      throw BridgeError.authRequired();
    }

    return {
      'id': user.id,
      'name': user.name,
      'avatarUrl': user.avatarUrl,
    };
  }

  /// Fetch fresh profile from Backend API (GET /api/v1/auth/me)
  Future<UserProfileModel> fetchRemoteProfile() async {
    final session = authRepository.currentSession;
    if (authUrl != null &&
        session != null &&
        session.accessToken.isNotEmpty &&
        !session.accessToken.startsWith('master_mock_')) {
      try {
        final client = httpClient ?? http.Client();
        final url = Uri.parse('$authUrl/me');
        final response = await client.get(
          url,
          headers: {
            'Authorization': 'Bearer ${session.accessToken}',
          },
        ).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final updatedUser = MockUser.fromBackendJson(data);
          // Return synchronized profile
          return UserProfileModel(
            id: updatedUser.id,
            name: updatedUser.name,
            phone: updatedUser.phone,
            role: updatedUser.role,
            email: updatedUser.email,
            avatarUrl: updatedUser.avatarUrl,
          );
        }
      } catch (e) {
        debugPrint('[MockUserRepository] Remote profile fetch failed: $e');
      }
    }

    return getProfile();
  }

  /// Update display name / avatar URL on Backend API (PATCH /api/v1/auth/me)
  Future<bool> updateProfile({String? displayName, String? avatarUrl}) async {
    final session = authRepository.currentSession;
    if (authUrl != null &&
        session != null &&
        session.accessToken.isNotEmpty &&
        !session.accessToken.startsWith('master_mock_')) {
      try {
        final client = httpClient ?? http.Client();
        final url = Uri.parse('$authUrl/me');
        final body = <String, dynamic>{};
        if (displayName != null) body['displayName'] = displayName.trim();
        if (avatarUrl != null) body['avatarUrl'] = avatarUrl.trim();

        final response = await client
            .patch(
              url,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ${session.accessToken}',
              },
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 4));

        return response.statusCode == 200;
      } catch (e) {
        debugPrint('[MockUserRepository] Remote updateProfile failed: $e');
        return false;
      }
    }

    return true;
  }
}

final mockUserRepositoryProvider = Provider<MockUserRepository>((ref) {
  final authRepo = ref.watch(mockAuthRepositoryProvider);
  final endpoint = ref.watch(backendEndpointProvider);
  return MockUserRepository(
    authRepository: authRepo,
    authUrl: endpoint.authUrl,
  );
});
