// Xử lý các hành động phần cứng thiết bị (Device Action Handlers).
//
// Bao gồm quét mã QR (`device.scanQRCode`), lấy tọa độ GPS (`device.getLocation`)
// và chọn ảnh từ thư viện (`device.pickImage`).
import 'media_file_action_handler.dart';
import '../../device/domain/device_adapter.dart';
import '../domain/action_definition.dart';
import '../domain/action_context.dart';

/// Xử lý action `device.scanQRCode`: Mở camera quét mã QR
class DeviceScanQrHandler implements NativeActionHandler {
  final DeviceAdapter deviceAdapter;

  DeviceScanQrHandler({required this.deviceAdapter});

  @override
  String get actionName => 'device.scanQRCode';

  @override
  String? get requiredCapability => 'device.scanQRCode';

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    return ScanQrHandler().handle(payload, context);
  }
}

/// Xử lý action `device.getLocation`: Lấy tọa độ GPS thiết bị
class DeviceGetLocationHandler implements NativeActionHandler {
  final DeviceAdapter deviceAdapter;

  DeviceGetLocationHandler({required this.deviceAdapter});

  @override
  String get actionName => 'device.getLocation';

  @override
  String? get requiredCapability => 'device.getLocation';

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    return deviceAdapter.getLocation();
  }
}

/// Xử lý action `device.pickImage`: Chọn ảnh từ thư viện thiết bị
class DevicePickImageHandler implements NativeActionHandler {
  final DeviceAdapter deviceAdapter;

  DevicePickImageHandler({required this.deviceAdapter});

  @override
  String get actionName => 'device.pickImage';

  @override
  String? get requiredCapability => 'device.pickImage';

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    return GetPhotoHandler().handle({...payload, 'source': payload['source'] ?? 'gallery'}, context);
  }
}
