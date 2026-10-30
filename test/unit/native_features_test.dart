import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:superapp_platform/core/errors/bridge_error.dart';
import 'package:superapp_platform/features/native_actions/domain/action_context.dart';
import 'package:superapp_platform/features/native_actions/handlers/system_action_handler.dart';
import 'package:superapp_platform/features/native_actions/handlers/media_file_action_handler.dart';
import 'package:superapp_platform/features/permissions/data/permission_repository_impl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final context = ActionContext(appId: 'sdk_playground');
  test('Wi-Fi returns plugin SSID/IP and never the former constant values', () async {
    final handler = GetNetworkInfoHandler(checkConnectivity: () async => [ConnectivityResult.wifi],
      wifiName: () async => '"Office network"', wifiIP: () async => '10.2.0.12', wifiBSSID: () async => 'aa:bb:cc:dd:ee:ff');
    final result = await handler.handle({}, context);
    expect(result['ssid'], 'Office network'); expect(result['ipAddress'], '10.2.0.12');
    expect(result['isWifi'], true); expect(result['isMobile'], false);
    expect(result['signalStrength'], isNull);
  });
  test('restricted SSID and IP stay null; offline does not query Wi-Fi', () async {
    final restricted = GetNetworkInfoHandler(checkConnectivity: () async => [ConnectivityResult.wifi],
      wifiName: () async => null, wifiIP: () async => throw PlatformException(code: 'denied'), wifiBSSID: () async => null);
    final r = await restricted.handle({}, context);
    expect(r['ssid'], isNull); expect(r['ipAddress'], isNull);
    final offline = GetNetworkInfoHandler(checkConnectivity: () async => [ConnectivityResult.none],
      wifiName: () async => throw StateError('Must not read Wi-Fi when offline'));
    final o = await offline.handle({}, context);
    expect(o['isConnected'], false); expect(o['networkType'], 'none');
  });
  test('connectivity plugin failures surface instead of claiming a Wi-Fi connection', () async {
    final handler = GetNetworkInfoHandler(checkConnectivity: () async => throw MissingPluginException());
    await expectLater(handler.handle({}, context), throwsA(isA<MissingPluginException>()));
  });
  test('contacts return actual fields and all phone numbers from the device adapter', () async {
    final permissions = PermissionRepositoryImpl()..setPermission(context.appId, 'contacts', true);
    final c = Contact(id: 'native-id', displayName: 'Device Contact', phones: [Phone('+84111'), Phone('+84222')], emails: [Email('contact@example.test')]);
    final handler = GetContactsHandler(permissionRepo: permissions, requestAccess: () async => true, readContacts: () async => [c]);
    final result = await handler.handle({}, context);
    expect(result['total'], 1);
    expect(result['contacts'][0], {'id': 'native-id', 'displayName': 'Device Contact', 'phoneNumber': '+84111',
      'phoneNumbers': ['+84111', '+84222'], 'email': 'contact@example.test', 'emails': ['contact@example.test'], 'department': null});
    expect((await handler.handle({'query': 'missing'}, context))['contacts'], isEmpty);
  });
  test('empty device address book stays empty', () async {
    final handler = GetContactsHandler(permissionRepo: PermissionRepositoryImpl()..setPermission(context.appId, 'contacts', true),
      requestAccess: () async => true, readContacts: () async => []);
    expect(await handler.handle({}, context), {'contacts': [], 'total': 0});
  });
  test('OS permission denial does not return sample contacts or read the address book', () async {
    var reads = 0;
    final handler = GetContactsHandler(permissionRepo: PermissionRepositoryImpl()..setPermission(context.appId, 'contacts', true),
      requestAccess: () async => false, readContacts: () async { reads++; return []; });
    await expectLater(handler.handle({}, context), throwsA(isA<BridgeError>().having((e) => e.code, 'code', BridgeErrorCode.permissionDenied)));
    expect(reads, 0);
  });
  test('app consent is required even if OS access was previously granted', () async {
    var prompts = 0;
    final handler = GetContactsHandler(permissionRepo: PermissionRepositoryImpl(),
      requestAccess: () async { prompts++; return true; }, readContacts: () async => []);
    await expectLater(handler.handle({}, context), throwsA(isA<BridgeError>())); expect(prompts, 0);
  });
  test('contacts plugin errors are not replaced by fixtures', () async {
    final handler = GetContactsHandler(permissionRepo: PermissionRepositoryImpl()..setPermission(context.appId, 'contacts', true),
      requestAccess: () async => true, readContacts: () async => throw PlatformException(code: 'native_failure'));
    await expectLater(handler.handle({}, context), throwsA(isA<PlatformException>()));
  });
  test('headless media calls fail instead of inventing file paths or successful scans', () async {
    for (final handler in [ScanQrHandler(), GetPhotoHandler(), PickImagesHandler(), PickVideoHandler(), PickFileHandler(), SaveFileHandler()]) {
      await expectLater(handler.handle({}, context), throwsA(isA<BridgeError>().having((e) => e.code, 'code', BridgeErrorCode.unsupported)));
    }
  });
}
