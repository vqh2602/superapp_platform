abstract class DeviceAdapter {
  Future<Map<String, dynamic>> scanQRCode();
  Future<Map<String, dynamic>> getLocation();
  Future<Map<String, dynamic>> pickImage();
}
