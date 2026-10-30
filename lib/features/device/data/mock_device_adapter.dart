import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/errors/bridge_error.dart';
import '../domain/device_adapter.dart';

// The legacy class name is kept for API compatibility; no simulated results.
class DeviceAdapterImpl implements DeviceAdapter {
  @override
  Future<Map<String, dynamic>> scanQRCode() async =>
      throw BridgeError.unsupported('QR scanning requires native UI');
  @override
  Future<Map<String, dynamic>> pickImage() async =>
      throw BridgeError.unsupported('Image picking requires native UI');
  @override
  Future<Map<String, dynamic>> getLocation() async {
    if (!await Geolocator.isLocationServiceEnabled())
      throw BridgeError.unsupported('Location services are disabled');
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied)
      permission = await Geolocator.requestPermission();
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

final deviceAdapterProvider = Provider<DeviceAdapterImpl>(
  (ref) => DeviceAdapterImpl(),
);

typedef MockDeviceAdapter = DeviceAdapterImpl;
