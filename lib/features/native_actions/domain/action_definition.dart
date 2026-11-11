// Định nghĩa trừu tượng cho bộ xử lý hành động Native (Native Action Handler).
//
// Mỗi hành động cụ thể (vd: Auth, Storage, Device, Media) sẽ kế thừa lớp này
// để xác định tên action, capability yêu cầu, điều kiện xác thực và logic thực thi.
import 'action_context.dart';

/// Hợp đồng cơ sở cho mọi Native Action Handler
abstract class NativeActionHandler {
  /// Tên định danh của hành động (vd: 'device.getLocation', 'auth.requestCode')
  String get actionName;

  /// Khóa capability bắt buộc khai báo trong manifest, hoặc null nếu không yêu cầu quyền đặc biệt
  String? get requiredCapability;

  /// Hành động có bắt buộc người dùng đã đăng nhập tài khoản SuperApp hay không
  bool get requiresAuth => true;

  /// Thực thi hành động với tham số [payload] và ngữ cảnh [context], trả về dữ liệu hoặc ném BridgeError
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context);
}
