import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superapp_platform/core/errors/bridge_error.dart';
import 'package:superapp_platform/features/native_actions/application/native_action_dispatcher.dart';
import 'package:superapp_platform/features/native_actions/domain/action_context.dart';
import 'package:superapp_platform/features/native_actions/domain/mini_app_ui_delegate.dart';
import 'package:superapp_platform/features/mini_app_catalog/domain/mini_app_manifest.dart';
import 'package:superapp_platform/features/authentication/data/mock_auth_repository.dart';
import 'package:superapp_platform/features/authentication/data/mock_auth_code_service.dart';
import 'package:superapp_platform/features/authentication/data/mock_token_service.dart';
import 'package:superapp_platform/features/user_profile/data/mock_user_repository.dart';
import 'package:superapp_platform/features/device/data/mock_device_adapter.dart';
import 'package:superapp_platform/features/permissions/data/mock_permission_repository.dart';
import 'package:superapp_platform/features/debug_center/data/debug_log_repository.dart';
import 'package:superapp_platform/features/storage/data/mock_secure_storage_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Comprehensive Native Features Tests (2.1 - 2.9)', () {
    late NativeActionDispatcher dispatcher;
    late MockPermissionRepository permissionRepo;
    late MockSecureStorageRepository storageRepo;

    final testManifest = const MiniAppManifest(
      id: 'sdk_playground',
      name: 'SDK Playground',
      description: 'Test Manifest',
      version: '1.2.0',
      icon: 'code',
      entryUrl: 'assets/mini_apps/sdk_playground/index.html',
      capabilities: [
        'contacts',
        'device.scanQRCode',
        'device.pickImage',
        'microphone',
      ],
    );

    setUp(() {
      final authRepo = MockAuthRepository();
      final authCodeService = MockAuthCodeService();
      final tokenService = MockTokenService(authCodeService: authCodeService);
      final userRepo = MockUserRepository(authRepository: authRepo);
      final deviceAdapter = MockDeviceAdapter();
      permissionRepo = MockPermissionRepository();
      final debugLogRepo = DebugLogRepository();
      storageRepo = MockSecureStorageRepository();

      permissionRepo.setPermission('sdk_playground', 'device.scanQRCode', true);
      permissionRepo.setPermission('sdk_playground', 'device.pickImage', true);

      dispatcher = NativeActionDispatcher(
        authRepo: authRepo,
        authCodeService: authCodeService,
        tokenService: tokenService,
        userRepo: userRepo,
        deviceAdapter: deviceAdapter,
        permissionRepo: permissionRepo,
        debugLogRepo: debugLogRepo,
        secureStorageRepo: storageRepo,
      );
    });

    test('2.1 System & Device Info: getNetworkInfo, getDeviceLanguage, getSuperAppSettings, getSystemInfo, getAppInfo, getBatteryInfo', () async {
      final context = ActionContext(appId: 'sdk_playground', manifest: testManifest);

      final net = await dispatcher.dispatch('getNetworkInfo', {}, context);
      expect(net['isConnected'], true);
      expect(net['networkType'], 'wifi');

      final lang = await dispatcher.dispatch('getDeviceLanguage', {}, context);
      expect(lang['languageCode'], isNotEmpty);

      final settings = await dispatcher.dispatch('getSuperAppSettings', {}, context);
      expect(settings['appName'], 'SuperApp');
      expect(settings['timezone'], 'Asia/Ho_Chi_Minh');

      final sys = await dispatcher.dispatch('getSystemInfo', {}, context);
      expect(sys['screenWidth'], isPositive);
      expect(sys['screenHeight'], isPositive);

      final appInfo = await dispatcher.dispatch('getAppInfo', {}, context);
      expect(appInfo['appId'], 'sdk_playground');
      expect(appInfo['name'], 'SDK Playground');

      final battery = await dispatcher.dispatch('getBatteryInfo', {}, context);
      expect(battery['level'], 88);
      expect(battery['isCharging'], false);
    });

    test('2.2 UI & Controls: showToast, vibrate, copyToClipboard, setBrightness, status/nav bar configs', () async {
      final context = ActionContext(appId: 'sdk_playground', manifest: testManifest);

      final toast = await dispatcher.dispatch('showToast', {'message': 'Hello SuperApp!'}, context);
      expect(toast['success'], true);
      expect(toast['message'], 'Hello SuperApp!');

      final vib = await dispatcher.dispatch('vibrate', {'style': 'light'}, context);
      expect(vib['success'], true);

      final clip = await dispatcher.dispatch('copyToClipboard', {'text': 'SuperApp Platform'}, context);
      expect(clip['success'], true);
      expect(clip['length'], 17);

      final bright = await dispatcher.dispatch('setBrightness', {'brightness': 0.8}, context);
      expect(bright['success'], true);
      expect(bright['brightness'], 0.8);

      final statusStyle = await dispatcher.dispatch('setStatusBarStyle', {'style': 'dark'}, context);
      expect(statusStyle['success'], true);

      final statusColor = await dispatcher.dispatch('setStatusBarColor', {'color': '#1E293B'}, context);
      expect(statusColor['success'], true);

      final navColor = await dispatcher.dispatch('setNavigationBarColor', {'color': '#0F172A'}, context);
      expect(navColor['success'], true);

      final appView = await dispatcher.dispatch('configAppView', {'hideStatusBar': false, 'hideNavigationBar': false}, context);
      expect(appView['success'], true);

      final close = await dispatcher.dispatch('closeApp', {}, context);
      expect(close['success'], true);
    });

    test('2.4 Camera, Media & QR/Barcode: scanQr, getPhoto, pickImages, saveImageToGallery, pickVideo, saveVideoToGallery', () async {
      final context = ActionContext(appId: 'sdk_playground', manifest: testManifest);

      // scanQr (QR & barcode scanner)
      final scanRes = await dispatcher.dispatch('scanQr', {}, context);
      expect(scanRes['content'], isNotEmpty);
      expect(scanRes['format'], 'QR_CODE');

      final photo = await dispatcher.dispatch('getPhoto', {'source': 'camera'}, context);
      expect(photo['uri'], contains('photo_'));

      final images = await dispatcher.dispatch('pickImages', {'maxCount': 2}, context);
      expect((images['images'] as List).length, 2);

      final saveImg = await dispatcher.dispatch('saveImageToGallery', {'uri': 'content://img1'}, context);
      expect(saveImg['success'], true);

      final video = await dispatcher.dispatch('pickVideo', {}, context);
      expect(video['uri'], contains('video_demo'));

      final saveVid = await dispatcher.dispatch('saveVideoToGallery', {'uri': 'content://vid1'}, context);
      expect(saveVid['success'], true);
    });

    test('2.5 File: saveFile, pickFile, filePreview', () async {
      final context = ActionContext(appId: 'sdk_playground', manifest: testManifest);

      final saveF = await dispatcher.dispatch('saveFile', {'fileName': 'contract.pdf'}, context);
      expect(saveF['success'], true);
      expect(saveF['fileName'], 'contract.pdf');

      final pickF = await dispatcher.dispatch('pickFile', {'allowMultiple': true}, context);
      expect((pickF['files'] as List).length, 2);

      final prev = await dispatcher.dispatch('filePreview', {'fileUrl': 'https://superapp.com/file.pdf'}, context);
      expect(prev['success'], true);
    });

    test('2.8 Secret Data (Keychain/Keystore): setSecretData, getSecretData, removeSecretData', () async {
      final context = ActionContext(appId: 'sdk_playground', manifest: testManifest);

      final setSec = await dispatcher.dispatch(
        'setSecretData',
        {'key': 'user_pin', 'value': '987654', 'domain': 'superapp.auth'},
        context,
      );
      expect(setSec['success'], true);
      expect(setSec['key'], 'user_pin');

      final getSec = await dispatcher.dispatch(
        'getSecretData',
        {'key': 'user_pin', 'domain': 'superapp.auth'},
        context,
      );
      expect(getSec['exists'], true);
      expect(getSec['value'], '987654');

      final remSec = await dispatcher.dispatch(
        'removeSecretData',
        {'key': 'user_pin', 'domain': 'superapp.auth'},
        context,
      );
      expect(remSec['removed'], true);
    });

    test('2.9 Contacts: getContacts enforces contacts permission', () async {
      final context = ActionContext(appId: 'sdk_playground', manifest: testManifest);

      // Denied / ungranted initially without UI context -> throws permissionDenied
      expect(
        () => dispatcher.dispatch('getContacts', {}, context),
        throwsA(isA<BridgeError>().having((e) => e.code, 'code', BridgeErrorCode.permissionDenied)),
      );

      // Granted
      permissionRepo.setPermission('sdk_playground', 'contacts', true);
      final contacts = await dispatcher.dispatch('getContacts', {}, context);
      expect((contacts['contacts'] as List).isNotEmpty, true);
      expect(contacts['total'], 3);
    });

    test('2.11 Phone & External links: openPhone, openSMS, openExternalBrowser, openDeepLink', () async {
      final context = ActionContext(appId: 'sdk_playground', manifest: testManifest);

      final phone = await dispatcher.dispatch('openPhone', {'phoneNumber': '0988123456'}, context);
      expect(phone['success'], true);
      expect(phone['phoneNumber'], '0988123456');

      final sms = await dispatcher.dispatch('openSMS', {'phoneNumber': '0988123456', 'body': 'Xin chao SuperApp'}, context);
      expect(sms['success'], true);
      expect(sms['body'], 'Xin chao SuperApp');

      final ext = await dispatcher.dispatch('openExternalBrowser', {'url': 'https://google.com'}, context);
      expect(ext['success'], true);
      expect(ext['mode'], 'EXTERNAL_BROWSER');

      final deep = await dispatcher.dispatch('openDeepLink', {'url': 'superapp://profile/settings'}, context);
      expect(deep['success'], true);
      expect(deep['mode'], 'IN_APP_BROWSER');
    });

    test('2.12 Input & Utilities: speechToText (enforces microphone) and hideKeyboard', () async {
      final context = ActionContext(appId: 'sdk_playground', manifest: testManifest);

      // speechToText ungranted initially without UI context -> throws permissionDenied
      expect(
        () => dispatcher.dispatch('speechToText', {}, context),
        throwsA(isA<BridgeError>().having((e) => e.code, 'code', BridgeErrorCode.permissionDenied)),
      );

      // Granted
      permissionRepo.setPermission('sdk_playground', 'microphone', true);
      final stt = await dispatcher.dispatch('speechToText', {'lang': 'vi-VN'}, context);
      expect(stt['text'], isNotEmpty);
      expect(stt['confidence'], isPositive);

      final hideKbd = await dispatcher.dispatch('hideKeyboard', {}, context);
      expect(hideKbd['success'], true);
      expect(hideKbd['hidden'], true);
    });

    test('2.13 Mini App SDK Compatibility: showAlert, showConfirm, setNavigationBarTitle, media.chooseImage, storage.getAll, media.scanQRCode', () async {
      final context = ActionContext(appId: 'sdk_playground', manifest: testManifest);

      // UI Dialogs & Title
      final alert = await dispatcher.dispatch('ui.showAlert', {'title': 'Chú ý', 'message': 'Nội dung thông báo'}, context);
      expect(alert['success'], true);

      final confirm = await dispatcher.dispatch('ui.showConfirm', {'title': 'Xác nhận', 'message': 'Bạn có chắc?'}, context);
      expect(confirm['confirmed'], false); // headless returns false fallback

      final navTitle = await dispatcher.dispatch('ui.setNavigationBarTitle', {'title': 'Trang chủ Mini App'}, context);
      expect(navTitle['success'], true);
      expect(navTitle['title'], 'Trang chủ Mini App');

      // Media SDK calls
      final scanRes = await dispatcher.dispatch('media.scanQRCode', {}, context);
      expect(scanRes['content'], isNotEmpty);
      expect(scanRes['format'], 'QR_CODE');

      final chooseImg = await dispatcher.dispatch('media.chooseImage', {'count': 2}, context);
      expect((chooseImg['tempFilePaths'] as List).length, 2);
      expect(chooseImg['count'], 2);

      // Device Info alias
      final devInfo = await dispatcher.dispatch('device.getDeviceInfo', {}, context);
      expect(devInfo['screenWidth'], isPositive);

      // Storage getAll
      await dispatcher.dispatch('storage.setItem', {'key': 'k1', 'value': 'v1'}, context);
      await dispatcher.dispatch('storage.setItem', {'key': 'k2', 'value': 'v2'}, context);
      final allStorage = await dispatcher.dispatch('storage.getAll', {}, context);
      expect(allStorage['k1'], 'v1');
      expect(allStorage['k2'], 'v2');
    });

    test('2.14 Zalo-style App View & Screen APIs: configAppView, setNavigationBarTitle, setNavigationBarColor, keepScreen, requestSendNotification, minimizeApp', () async {
      final uiDelegate = _TestUiDelegate();
      final context = ActionContext(
        appId: 'sdk_playground',
        manifest: testManifest,
        uiDelegate: uiDelegate,
      );

      // 1. setNavigationBarTitle
      final titleRes = await dispatcher.dispatch('setNavigationBarTitle', {'title': 'Chi tiết sản phẩm'}, context);
      expect(titleRes['success'], true);
      expect(titleRes['title'], 'Chi tiết sản phẩm');
      expect(uiDelegate.title, 'Chi tiết sản phẩm');

      // 2. setNavigationBarColor
      final colorRes = await dispatcher.dispatch('setNavigationBarColor', {
        'color': '#0068FF',
        'textColor': 'white',
      }, context);
      expect(colorRes['success'], true);
      expect(colorRes['color'], '#0068FF');
      expect(colorRes['textColor'], 'white');
      expect(uiDelegate.navColor, const Color(0xFF0068FF));
      expect(uiDelegate.textColor, 'white');

      // 3. configAppView (flat + nested)
      final configRes = await dispatcher.dispatch('configAppView', {
        'headerTitle': 'Trang Checkout',
        'actionBarHidden': true,
        'statusBar': 'transparent',
        'textColor': 'black',
        'hideAndroidBottomNavigationBar': true,
        'hasPadding': false,
      }, context);
      expect(configRes['success'], true);
      expect(configRes['actionBarHidden'], true);
      expect(configRes['statusBar'], 'transparent');
      expect(uiDelegate.actionBarHidden, true);
      expect(uiDelegate.title, 'Trang Checkout');
      expect(uiDelegate.textColor, 'black');

      // 4. keepScreen
      final keepRes = await dispatcher.dispatch('keepScreen', {'keepScreenOn': true}, context);
      expect(keepRes['success'], true);
      expect(keepRes['keepScreenOn'], true);
      expect(uiDelegate.keepScreenOn, true);

      final keepOffRes = await dispatcher.dispatch('device.keepScreen', {'keepScreenOn': false}, context);
      expect(keepOffRes['keepScreenOn'], false);
      expect(uiDelegate.keepScreenOn, false);

      // 5. requestSendNotification
      final notifRes = await dispatcher.dispatch('requestSendNotification', {
        'templateId': 'order_update_v1',
        'reason': 'Cập nhật trạng thái giao hàng',
      }, context);
      expect(notifRes['success'], true);
      expect(notifRes['granted'], true);
      expect(notifRes['subscriptionId'], isNotEmpty);
      expect(notifRes['token'], isNotEmpty);
      expect(permissionRepo.isGranted('sdk_playground', 'notification'), true);

      // 6. minimizeApp
      final minRes = await dispatcher.dispatch('minimizeApp', {}, context);
      expect(minRes['success'], true);
      expect(minRes['status'], 'minimized');
      expect(uiDelegate.minimized, true);
    });
  });
}

class _TestUiDelegate implements MiniAppUiDelegate {
  String? title;
  Color? navColor;
  String? textColor;
  bool? actionBarHidden;
  bool? keepScreenOn;
  bool minimized = false;

  @override
  void setTitle(String title) {
    this.title = title;
  }

  @override
  void setNavigationBarColor({
    required Color color,
    String? textColor,
    Color? statusBarColor,
  }) {
    navColor = color;
    this.textColor = textColor;
  }

  @override
  void configAppView({
    Color? headerColor,
    String? headerTitle,
    String? textColor,
    String? statusBar,
    bool? actionBarHidden,
    bool? hideAndroidBottomNavigationBar,
    bool? hasPadding,
    Color? bottomNavColor,
  }) {
    this.actionBarHidden = actionBarHidden;
    this.textColor = textColor;
    if (headerTitle != null) title = headerTitle;
  }

  @override
  void keepScreen({required bool keepScreenOn}) {
    this.keepScreenOn = keepScreenOn;
  }

  @override
  void minimizeApp() {
    minimized = true;
  }
}
