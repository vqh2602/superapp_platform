import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/mini_app_manifest.dart';

class MiniAppRepository {
  final List<MiniAppManifest> _apps = [
    const MiniAppManifest(
      id: 'sdk_playground',
      name: 'SDK Playground',
      description: 'React + TypeScript Mini App test bed with interactive SDK runner',
      version: '1.0.0',
      icon: 'code',
      entryUrl: 'assets/mini_apps/sdk_playground/index.html',
      isAsset: true,
      capabilities: [
        'auth.requestCode',
        'user.getProfile',
        'user.getBasicInfo',
        'navigation.openNativePage',
        'navigation.close',
        'navigation.openMiniApp',
        'device.scanQRCode',
        'device.getLocation',
        'device.pickImage',
        'payment.createOrder',
        'payment.openCheckout',
        'permission.request',
        'debug.echo',
        'debug.simulateFailure',
      ],
    ),
    const MiniAppManifest(
      id: 'sample_store',
      name: 'Sample Mini App 2 (Store)',
      description: 'Secondary Mini App to demonstrate cross-mini-app native switching',
      version: '1.0.0',
      icon: 'storefront',
      entryUrl: 'assets/mini_apps/sample_store/index.html',
      isAsset: true,
      capabilities: [
        'user.getBasicInfo',
        'navigation.close',
        'payment.createOrder',
        'payment.openCheckout',
      ],
    ),
  ];

  List<MiniAppManifest> getAllApps() => List.unmodifiable(_apps);

  MiniAppManifest? getAppById(String id) {
    try {
      return _apps.firstWhere((app) => app.id == id);
    } catch (_) {
      return null;
    }
  }
}

final miniAppRepositoryProvider = Provider<MiniAppRepository>((ref) {
  return MiniAppRepository();
});
