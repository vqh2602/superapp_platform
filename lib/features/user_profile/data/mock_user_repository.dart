import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../authentication/data/mock_auth_repository.dart';
import '../../authentication/presentation/controllers/auth_controller.dart';
import '../../../../core/errors/bridge_error.dart';
import '../domain/user_profile_model.dart';

class MockUserRepository {
  final MockAuthRepository authRepository;

  MockUserRepository({required this.authRepository});

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
}

final mockUserRepositoryProvider = Provider<MockUserRepository>((ref) {
  final authRepo = ref.watch(mockAuthRepositoryProvider);
  return MockUserRepository(authRepository: authRepo);
});
