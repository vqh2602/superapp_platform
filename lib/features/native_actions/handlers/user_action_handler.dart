// Xử lý các hành động truy xuất thông tin người dùng qua Bridge (User Action Handlers).
//
// Bao gồm lấy thông tin chi tiết (`user.getProfile`) và thông tin cơ bản (`user.getBasicInfo`).
import '../../user_profile/data/user_repository_impl.dart';
import '../domain/action_definition.dart';
import '../domain/action_context.dart';

/// Xử lý action `user.getProfile`: Lấy thông tin tài khoản người dùng đầy đủ (yêu cầu capability `user.getProfile`)
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

/// Xử lý action `user.getBasicInfo`: Lấy thông tin người dùng cơ bản công khai (tên, avatar)
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
