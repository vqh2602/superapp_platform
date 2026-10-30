import 'media_file_action_handler.dart';
import '../../device/domain/device_adapter.dart';
import '../domain/action_definition.dart';
import '../domain/action_context.dart';

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
