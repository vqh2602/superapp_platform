import 'dart:io';
import 'dart:ui';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../core/errors/bridge_error.dart';
import '../../permissions/data/mock_permission_repository.dart';
import '../../permissions/presentation/permission_prompt_dialog.dart';
import '../domain/action_definition.dart';
import '../domain/action_context.dart';

class GetNetworkInfoHandler implements NativeActionHandler {
  final Connectivity _connectivity = Connectivity();

  @override
  String get actionName => 'device.getNetworkInfo';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    String networkType = 'wifi';
    bool isConnected = true;

    try {
      final List<ConnectivityResult> results = await _connectivity.checkConnectivity();
      if (results.contains(ConnectivityResult.none)) {
        networkType = 'none';
        isConnected = false;
      } else if (results.contains(ConnectivityResult.wifi)) {
        networkType = 'wifi';
        isConnected = true;
      } else if (results.contains(ConnectivityResult.mobile)) {
        networkType = 'cellular';
        isConnected = true;
      } else if (results.contains(ConnectivityResult.ethernet)) {
        networkType = 'ethernet';
        isConnected = true;
      } else if (results.contains(ConnectivityResult.vpn)) {
        networkType = 'vpn';
        isConnected = true;
      } else if (results.isNotEmpty) {
        networkType = results.first.name;
        isConnected = true;
      }
    } catch (_) {}

    return {
      'networkType': networkType,
      'isConnected': isConnected,
      'signalStrength': isConnected ? 'good' : 'none',
      'ssid': networkType == 'wifi' ? 'SuperApp_WiFi' : null,
      'ipAddress': isConnected ? '192.168.1.105' : null,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }
}

class GetDeviceLanguageHandler implements NativeActionHandler {
  @override
  String get actionName => 'device.getDeviceLanguage';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    final locale = PlatformDispatcher.instance.locale;
    final langCode = locale.languageCode.isNotEmpty ? locale.languageCode : 'vi';
    final country = locale.countryCode ?? 'VN';

    return {
      'language': '$langCode-$country',
      'languageCode': langCode,
      'countryCode': country,
      'locale': '${langCode}_$country',
    };
  }
}

class GetSuperAppSettingsHandler implements NativeActionHandler {
  @override
  String get actionName => 'app.getSuperAppSettings';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    return {
      'theme': 'light',
      'language': 'vi',
      'timezone': 'Asia/Ho_Chi_Minh',
      'gmtOffset': '+07:00',
      'appName': 'SuperApp',
      'shellVersion': '2.4.0',
      'env': 'production',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }
}

class GetSystemInfoHandler implements NativeActionHandler {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  @override
  String get actionName => 'device.getSystemInfo';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    final size = context.buildContext != null
        ? MediaQuery.of(context.buildContext!).size
        : const Size(390, 844);
    final pixelRatio = context.buildContext != null
        ? MediaQuery.of(context.buildContext!).devicePixelRatio
        : 3.0;

    String platformName = 'web';
    String osVersion = '17.5';
    String deviceModel = 'iPhone 15 Pro';
    String brand = 'Apple';

    try {
      if (!kIsWeb) {
        if (Platform.isAndroid) {
          platformName = 'android';
          final info = await _deviceInfo.androidInfo;
          deviceModel = info.model;
          brand = info.brand;
          osVersion = 'Android ${info.version.release} (SDK ${info.version.sdkInt})';
        } else if (Platform.isIOS) {
          platformName = 'ios';
          final info = await _deviceInfo.iosInfo;
          deviceModel = '${info.name} (${info.utsname.machine})';
          brand = 'Apple';
          osVersion = 'iOS ${info.systemVersion}';
        } else if (Platform.isMacOS) {
          platformName = 'macos';
          final info = await _deviceInfo.macOsInfo;
          deviceModel = info.model;
          brand = 'Apple';
          osVersion = 'macOS ${info.osRelease}';
        } else if (Platform.isWindows) {
          platformName = 'windows';
          final info = await _deviceInfo.windowsInfo;
          deviceModel = info.computerName;
          brand = 'Microsoft';
          osVersion = 'Windows ${info.productName}';
        } else if (Platform.isLinux) {
          platformName = 'linux';
          final info = await _deviceInfo.linuxInfo;
          deviceModel = info.name;
          brand = 'Linux';
          osVersion = info.version ?? 'Linux';
        }
      }
    } catch (_) {}

    return {
      'platform': platformName,
      'osVersion': osVersion,
      'deviceModel': deviceModel,
      'brand': brand,
      'screenWidth': size.width.round(),
      'screenHeight': size.height.round(),
      'pixelRatio': pixelRatio,
      'statusBarHeight': context.buildContext != null
          ? MediaQuery.of(context.buildContext!).padding.top.round()
          : 47,
      'safeAreaBottom': context.buildContext != null
          ? MediaQuery.of(context.buildContext!).padding.bottom.round()
          : 34,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }
}

class GetAppInfoHandler implements NativeActionHandler {
  @override
  String get actionName => 'app.getAppInfo';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    final m = context.manifest;
    return {
      'appId': context.appId,
      'name': m?.name ?? context.appId,
      'version': m?.version ?? '1.0.0',
      'category': m?.category ?? 'Utilities',
      'runtimeType': m?.appRuntimeType ?? 'web',
      'description': m?.description ?? '',
      'isAsset': m?.isAsset ?? true,
      'status': m?.status ?? 'PUBLISHED',
    };
  }
}

class GetBatteryInfoHandler implements NativeActionHandler {
  final Battery _battery = Battery();

  @override
  String get actionName => 'device.getBatteryInfo';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    int level = 88;
    bool isCharging = false;
    String status = 'discharging';

    try {
      level = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      isCharging = (state == BatteryState.charging || state == BatteryState.full);
      status = switch (state) {
        BatteryState.charging => 'charging',
        BatteryState.discharging => 'discharging',
        BatteryState.full => 'full',
        _ => 'unknown',
      };
    } catch (_) {}

    return {
      'level': level,
      'isCharging': isCharging,
      'status': status,
      'temperature': 28.5,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }
}

class GetContactsHandler implements NativeActionHandler {
  final MockPermissionRepository permissionRepo;

  GetContactsHandler({required this.permissionRepo});

  @override
  String get actionName => 'contact.getContacts';

  @override
  String? get requiredCapability => 'contacts';

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    final isGranted = permissionRepo.isGranted(context.appId, 'contacts');
    if (!isGranted) {
      if (context.buildContext != null) {
        final granted = await PermissionPromptDialog.show(
          context.buildContext!,
          appName: context.manifest?.name ?? context.appId,
          capabilityKey: 'contacts',
        );
        permissionRepo.setPermission(context.appId, 'contacts', granted);
        if (!granted) {
          throw BridgeError.permissionDenied('contacts');
        }
      } else {
        throw BridgeError.permissionDenied('contacts');
      }
    }

    final query = payload['query']?.toString().toLowerCase();
    final allContacts = [
      {
        'id': 'contact_01',
        'displayName': 'Nguyễn Văn An',
        'phoneNumber': '0988123456',
        'email': 'an.nguyen@superapp.com',
        'department': 'Product Development',
        'avatar': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100',
      },
      {
        'id': 'contact_02',
        'displayName': 'Trần Thị Bình',
        'phoneNumber': '0912345678',
        'email': 'binh.tran@superapp.com',
        'department': 'Operations & Logistics',
        'avatar': 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=100',
      },
      {
        'id': 'contact_03',
        'displayName': 'Lê Hoàng Cường',
        'phoneNumber': '0977888999',
        'email': 'cuong.le@superapp.com',
        'department': 'Finance & Accounting',
        'avatar': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100',
      },
    ];

    final filtered = query == null || query.isEmpty
        ? allContacts
        : allContacts.where((c) {
            final name = c['displayName']!.toLowerCase();
            final phone = c['phoneNumber']!;
            return name.contains(query) || phone.contains(query);
          }).toList();

    return {
      'contacts': filtered,
      'total': filtered.length,
    };
  }
}
