// Dịch vụ nghiệp vụ phân quyền người dùng và Mini App (Permission Application Service).
//
// Quản lý vòng đời cấp quyền, kiểm tra manifest, khử trùng lặp hộp thoại (deduplication)
// và tuần tự hóa hiển thị prompt qua hàng đợi UserInteractionQueue.
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/bridge_error.dart';
import '../../native_actions/domain/action_context.dart';
import '../data/permission_repository_impl.dart';
import '../presentation/permission_prompt_dialog.dart';

/// Dịch vụ trung tâm duy nhất quản lý toàn bộ vòng đời quyền truy cập (Permissions):
/// 1. Xác minh khai báo quyền trong Manifest & SecurityContext
/// 2. Kiểm tra trạng thái phiên làm việc và huỷ bỏ tác vụ (Cancellation)
/// 3. Khôi phục quyền đã lưu từ máy chủ (Persistence)
/// 4. Khử trùng lặp hộp thoại xin quyền (Prompt Deduplication)
/// 5. Tuần tự hoá tương tác người dùng qua hàng đợi (UserInteractionQueue)
/// 6. Đồng bộ nguyên tử lên Backend và tự động Rollback khi lỗi
class PermissionService {
  final PermissionRepositoryImpl permissionRepo;
  final Map<String, Future<bool>> _inFlightPrompts = {};

  PermissionService({required this.permissionRepo});

  /// Xác minh quyền được yêu cầu có nằm trong Manifest hoặc SecurityContext của Mini App hay không.
  /// Mini App không được phép xin hoặc thực thi quyền mà nó chưa khai báo trong Manifest.
  void verifyCapabilityInManifest(ActionContext context, String capability) {
    if (context.securityContext != null) {
      if (!context.securityContext!.isCapabilityAllowed(capability)) {
        throw BridgeError.permissionDenied(
          'Capability "$capability" is not declared in Mini App manifest',
        );
      }
    } else if (context.manifest != null) {
      if (!context.manifest!.capabilities.contains(capability)) {
        throw BridgeError.permissionDenied(
          'Capability "$capability" is not declared in Mini App manifest',
        );
      }
    }
  }

  /// Kiểm tra xem quyền đã được cấp hay chưa
  bool isGranted(String appId, String capability) {
    return permissionRepo.isGranted(appId, capability);
  }

  /// Kiểm tra xem quyền có bị từ chối rõ ràng hay không
  bool isExplicitlyDenied(String appId, String capability) {
    return permissionRepo.isExplicitlyDenied(appId, capability);
  }

  /// Đảm bảo quyền đã được tải từ máy chủ trước khi xử lý
  Future<Map<String, bool>> ensurePermissionsLoaded(String appId) {
    return permissionRepo.ensurePermissionsLoaded(appId);
  }

  /// Lấy toàn bộ quyền đã cấp của Mini App
  Map<String, bool> getPermissionsForApp(String appId) {
    return permissionRepo.getPermissionsForApp(appId);
  }

  /// Thu hồi tất cả quyền của một Mini App
  void revokeAll(String appId) {
    permissionRepo.revokeAll(appId);
  }

  /// Yêu cầu cấp quyền cho Mini App qua quy trình thống nhất:
  /// - Kiểm tra phiên làm việc (Session active)
  /// - Xác minh khai báo quyền trong Manifest
  /// - Tải quyền đã lưu từ Backend
  /// - Kiểm tra nếu quyền đã được cấp trước đó
  /// - Khử trùng lặp (Deduplication) nếu có nhiều request cùng xin 1 quyền đồng thời
  /// - Mở modal giao diện thông qua UserInteractionQueue
  /// - Đồng bộ nguyên tử lên Backend và rollback nếu thất bại
  Future<bool> requestPermission({
    required ActionContext context,
    required String capability,
  }) async {
    // 1. Kiểm tra trạng thái phiên làm việc
    context.checkCancelled();

    if (context.appId.isEmpty) {
      throw BridgeError.invalidParams('Mini App identifier (appId) is missing');
    }

    if (capability.trim().isEmpty) {
      throw BridgeError.invalidParams('capability is required');
    }

    final trimmedCap = capability.trim();

    // 2. Xác minh quyền trong Manifest / SecurityContext
    verifyCapabilityInManifest(context, trimmedCap);

    // 3. Khôi phục quyền đã lưu từ máy chủ trước khi quyết định
    context.checkCancelled();
    await permissionRepo.ensurePermissionsLoaded(context.appId);
    context.checkCancelled();

    // 4. Nếu đã được cấp quyền, trả về true ngay lập tức
    if (permissionRepo.isGranted(context.appId, trimmedCap)) {
      return true;
    }

    // 5. Nếu không có BuildContext (môi trường không UI hoặc headless), từ chối
    if (context.buildContext == null) {
      throw BridgeError.permissionDenied(trimmedCap);
    }

    // 6. Khử trùng lặp (Deduplication): chia sẻ chung 1 Future nếu đang có dialog chờ
    final key = '${context.appId}:$trimmedCap';
    final inFlight = _inFlightPrompts[key];
    if (inFlight != null) {
      return inFlight;
    }

    // 7. Tuần tự hoá mở Dialog qua UserInteractionQueue
    final promptFuture = context.runInteractive<bool>(() async {
      context.checkCancelled();

      // Kiểm tra lại lần nữa khi đến lượt thực thi trong hàng đợi
      if (permissionRepo.isGranted(context.appId, trimmedCap)) {
        return true;
      }

      final appName = context.manifest?.name ?? context.appId;
      final granted = await PermissionPromptDialog.show(
        context.buildContext!,
        appName: appName,
        capabilityKey: trimmedCap,
      );

      context.checkCancelled();

      // 8. Cập nhật và đồng bộ nguyên tử lên máy chủ (ném lỗi và rollback nếu thất bại)
      await permissionRepo.updatePermission(context.appId, trimmedCap, granted);

      context.checkCancelled();
      return granted;
    });

    _inFlightPrompts[key] = promptFuture;
    promptFuture.whenComplete(() {
      _inFlightPrompts.remove(key);
    });

    return promptFuture;
  }

  void dispose() {
    _inFlightPrompts.clear();
  }
}

final permissionServiceProvider = Provider<PermissionService>((ref) {
  final repo = ref.watch(permissionRepositoryProvider);
  final service = PermissionService(permissionRepo: repo);
  ref.onDispose(service.dispose);
  return service;
});
