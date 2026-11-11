// Triển khai bộ điều hợp thiết bị thực tế (Device Adapter Implementation).
//
// Tích hợp thư viện `geolocator` để kiểm tra quyền và lấy tọa độ GPS chính xác của thiết bị.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/errors/bridge_error.dart';
import '../domain/device_adapter.dart';

/// Lớp cài đặt [DeviceAdapter] xử lý vị trí GPS và phần cứng
class DeviceAdapterImpl implements DeviceAdapter {
  @override
  Future<Map<String, dynamic>> scanQRCode() async =>
      throw BridgeError.unsupported('QR scanning requires native UI');

  @override
  Future<Map<String, dynamic>> pickImage() async =>
      throw BridgeError.unsupported('Image picking requires native UI');

  /// Truy vấn tọa độ GPS hiện tại thông qua Geolocator (kiểm tra quyền truy cập hệ điều hành)
  @override
  Future<Map<String, dynamic>> getLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw BridgeError.unsupported('Location services are disabled');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw BridgeError.permissionDenied('location');
    }
    final p = await Geolocator.getCurrentPosition();
    return {
      'latitude': p.latitude,
      'longitude': p.longitude,
      'accuracy': p.accuracy,
      'altitude': p.altitude,
      'heading': p.heading,
      'speed': p.speed,
      'timestamp': p.timestamp.millisecondsSinceEpoch,
    };
  }
}

/// Provider cung cấp DeviceAdapterImpl
final deviceAdapterProvider = Provider<DeviceAdapterImpl>(
  (ref) => DeviceAdapterImpl(),
);
