/// Kết quả thực thi hành động Native (Action Result).
///
/// Chứa trạng thái thành công hoặc thất bại, dữ liệu kết quả hoặc thông tin mã lỗi.
class ActionResult {
  /// Trạng thái thành công
  final bool success;
  /// Dữ liệu trả về khi thành công
  final dynamic data;
  /// Mã lỗi khi thất bại
  final String? errorCode;
  /// Thông điệp lỗi khi thất bại
  final String? errorMessage;

  /// Tạo kết quả thành công kèm dữ liệu
  const ActionResult.ok(this.data)
      : success = true,
        errorCode = null,
        errorMessage = null;

  /// Tạo kết quả thất bại kèm mã lỗi và thông báo
  const ActionResult.fail(this.errorCode, this.errorMessage)
      : success = false,
        data = null;
}
