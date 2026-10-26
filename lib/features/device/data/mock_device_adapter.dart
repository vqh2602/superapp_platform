import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/bridge_error.dart';
import '../domain/device_adapter.dart';

class MockDeviceAdapter implements DeviceAdapter {
  bool useRealDeviceMode = false;

  @override
  Future<Map<String, dynamic>> scanQRCode() async {
    if (useRealDeviceMode) {
      // Real plugin not linked in mock demo
      throw BridgeError.unsupported('camera_qr_scanner_plugin');
    }

    // Mock response
    await Future.delayed(const Duration(milliseconds: 300));
    final randomId = Random().nextInt(89999) + 10000;
    return {
      'content': 'https://superapp.mock/pay?qr_token=QR_MOCK_$randomId',
      'format': 'QR_CODE',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'isMock': true,
    };
  }

  @override
  Future<Map<String, dynamic>> getLocation() async {
    if (useRealDeviceMode) {
      throw BridgeError.unsupported('geolocator_plugin');
    }

    await Future.delayed(const Duration(milliseconds: 250));
    // Sample coordinates: Ho Chi Minh City Center (District 1)
    return {
      'latitude': 10.776889,
      'longitude': 106.700806,
      'accuracy': 5.0,
      'city': 'Hồ Chí Minh',
      'country': 'Việt Nam',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'isMock': true,
    };
  }

  @override
  Future<Map<String, dynamic>> pickImage() async {
    if (useRealDeviceMode) {
      throw BridgeError.unsupported('image_picker_plugin');
    }

    await Future.delayed(const Duration(milliseconds: 300));
    return {
      'uri': 'content://mock/photos/photo_demo_01.jpg',
      'mimeType': 'image/jpeg',
      'width': 1080,
      'height': 1920,
      'sizeBytes': 245120,
      'fileName': 'photo_demo_01.jpg',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'isMock': true,
    };
  }
}

final deviceAdapterProvider = Provider<MockDeviceAdapter>((ref) {
  return MockDeviceAdapter();
});
