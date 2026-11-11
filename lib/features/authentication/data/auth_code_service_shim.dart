// Lớp tương thích ngược (Compatibility Shim) cho AuthCodeService.
//
// Mã xác thực (Authorization Code) hiện tại bắt buộc phải sinh và xác thực
// từ máy chủ Backend thông qua quy chuẩn PKCE, không tạo cục bộ trên client.
import '../../../../core/errors/bridge_error.dart';
import '../domain/models/auth_code.dart';

/// Lớp Shim chuyển tiếp yêu cầu mã xác thực sang máy chủ backend
class AuthCodeServiceShim {
  /// Không hỗ trợ sinh mã cục bộ - phải gọi qua API Backend PKCE
  String generateCode({required String userId, required String appId}) =>
      throw BridgeError.unsupported('Use backend PKCE authorization');

  /// Không hỗ trợ thẩm định mã cục bộ - mã được kiểm tra bởi backend
  AuthCode validateAndBurn(String code, String appId) =>
      throw BridgeError.unsupported('Codes are validated by the backend');

  /// Xóa bộ nhớ đệm
  void reset() {}
}
