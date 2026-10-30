import '../../user_profile/data/user_repository_impl.dart';
import '../domain/action_definition.dart';
import '../domain/action_context.dart';

class UserGetProfileHandler implements NativeActionHandler {
  final UserRepositoryImpl userRepo;

  UserGetProfileHandler({required this.userRepo});

  @override
  String get actionName => 'user.getProfile';

  @override
  String? get requiredCapability => 'user.getProfile';

  @override
  bool get requiresAuth => true;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    final profile = userRepo.getProfile();
    return profile.toJson();
  }
}

class UserGetBasicInfoHandler implements NativeActionHandler {
  final UserRepositoryImpl userRepo;

  UserGetBasicInfoHandler({required this.userRepo});

  @override
  String get actionName => 'user.getBasicInfo';

  @override
  String? get requiredCapability => 'user.getBasicInfo';

  @override
  bool get requiresAuth => true;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    return userRepo.getBasicInfo();
  }
}
