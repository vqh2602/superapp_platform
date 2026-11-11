// Giao diện bộ điều hợp phần cứng thiết bị (Device Adapter Interface).
//
// Định nghĩa các phương thức trừu tượng tương tác với phần cứng thiết bị:
// quét mã QR, truy vấn vị trí GPS và chọn ảnh từ thư viện.

/// Hợp đồng Adapter phần cứng thiết bị
abstract class DeviceAdapter {
  /// Kích hoạt quét mã QR từ camera
  Future<Map<String, dynamic>> scanQRCode();

  /// Truy vấn tọa độ vị trí địa lý GPS hiện tại của thiết bị
  Future<Map<String, dynamic>> getLocation();

  /// Mở giao diện chọn ảnh từ thư viện thiết bị
  Future<Map<String, dynamic>> pickImage();
}
