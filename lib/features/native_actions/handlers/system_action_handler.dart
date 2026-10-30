import 'dart:io';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../../core/errors/bridge_error.dart';
import '../../permissions/data/permission_repository_impl.dart';
import '../domain/action_definition.dart';
import '../domain/action_context.dart';

class GetNetworkInfoHandler implements NativeActionHandler {
  final Future<List<ConnectivityResult>> Function() checkConnectivity;
  final Future<String?> Function() wifiName;
  final Future<String?> Function() wifiIP;
  final Future<String?> Function() wifiBSSID;
  GetNetworkInfoHandler({
    Future<List<ConnectivityResult>> Function()? checkConnectivity,
    Future<String?> Function()? wifiName,
    Future<String?> Function()? wifiIP,
    Future<String?> Function()? wifiBSSID,
  }) : checkConnectivity =
           checkConnectivity ?? Connectivity().checkConnectivity,
       wifiName = wifiName ?? NetworkInfo().getWifiName,
       wifiIP = wifiIP ?? NetworkInfo().getWifiIP,
       wifiBSSID = wifiBSSID ?? NetworkInfo().getWifiBSSID;
  @override
  String get actionName => 'device.getNetworkInfo';
  @override
  String? get requiredCapability => null;
  @override
  bool get requiresAuth => false;
  Future<String?> _optional(Future<String?> Function() read) async {
    try {
      return await read();
    } catch (_) {
      return null;
    }
  }

  String? _cleanSsid(String? raw) {
    if (raw == null) return null;
    var cleaned = raw.replaceAll(RegExp(r'^\"|\"$'), '').trim();
    if (cleaned.isEmpty ||
        cleaned == '<unknown ssid>' ||
        cleaned.startsWith('<') ||
        cleaned == 'null') {
      return null;
    }
    return cleaned;
  }

  String? _cleanBssid(String? raw) {
    if (raw == null) return null;
    var cleaned = raw.replaceAll(RegExp(r'^\"|\"$'), '').trim();
    if (cleaned.isEmpty || cleaned == '02:00:00:00:00:00' || cleaned == 'null') {
      return null;
    }
    return cleaned;
  }

  @override
  Future<dynamic> handle(
    Map<String, dynamic> payload,
    ActionContext context,
  ) async {
    final results = await checkConnectivity();
    final active = results.where((r) => r != ConnectivityResult.none).toList();
    final wifi = active.contains(ConnectivityResult.wifi);
    final mobile = active.contains(ConnectivityResult.mobile);
    final String type = wifi
        ? 'wifi'
        : mobile
        ? 'cellular'
        : active.firstOrNull?.name ?? 'none';
    final ssid = wifi ? await _optional(wifiName) : null;
    return {
      'networkType': type, 'isConnected': active.isNotEmpty,
      'isWifi': wifi, 'isMobile': mobile,
      'ssid': _cleanSsid(ssid),
      'bssid': _cleanBssid(wifi ? await _optional(wifiBSSID) : null),
      'ipAddress': wifi ? await _optional(wifiIP) : null,
      'signalStrength': null, // Not exposed by the platform plugin.
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
  Future<dynamic> handle(
    Map<String, dynamic> payload,
    ActionContext context,
  ) async {
    final locale = PlatformDispatcher.instance.locale;
    return {
      'language': locale.toLanguageTag(),
      'languageCode': locale.languageCode,
      'countryCode': locale.countryCode,
      'locale': locale.toString(),
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
  Future<dynamic> handle(
    Map<String, dynamic> payload,
    ActionContext context,
  ) async {
    final info = await PackageInfo.fromPlatform();
    final now = DateTime.now();
    final brightness = context.buildContext != null
        ? Theme.of(context.buildContext!).brightness
        : PlatformDispatcher.instance.platformBrightness;
    final offset = now.timeZoneOffset;
    return {
      'theme': brightness.name,
      'language': PlatformDispatcher.instance.locale.toLanguageTag(),
      'timezone': now.timeZoneName,
      'gmtOffset':
          '${offset.isNegative ? '-' : '+'}${offset.inHours.abs().toString().padLeft(2, '0')}:${(offset.inMinutes.abs() % 60).toString().padLeft(2, '0')}',
      'appName': info.appName,
      'shellVersion': info.version,
      'buildNumber': info.buildNumber,
      'env': kReleaseMode
          ? 'production'
          : kProfileMode
          ? 'profile'
          : 'debug',
      'timestamp': now.millisecondsSinceEpoch,
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
  Future<dynamic> handle(
    Map<String, dynamic> payload,
    ActionContext context,
  ) async {
    String? model, brand;
    String? osVersion = kIsWeb ? null : Platform.operatingSystemVersion;
    if (!kIsWeb && Platform.isAndroid) {
      final info = await _deviceInfo.androidInfo;
      model = info.model;
      brand = info.brand;
      osVersion = info.version.release;
    } else if (!kIsWeb && Platform.isIOS) {
      final info = await _deviceInfo.iosInfo;
      model = info.utsname.machine;
      brand = 'Apple';
      osVersion = info.systemVersion;
    } else if (!kIsWeb && Platform.isMacOS) {
      final info = await _deviceInfo.macOsInfo;
      model = info.model;
      brand = 'Apple';
      osVersion = info.osRelease;
    } else if (!kIsWeb && Platform.isWindows) {
      final info = await _deviceInfo.windowsInfo;
      model = info.computerName;
      osVersion = info.productName;
    } else if (!kIsWeb && Platform.isLinux) {
      final info = await _deviceInfo.linuxInfo;
      model = info.name;
      osVersion = info.version;
    }
    final view = PlatformDispatcher.instance.views.firstOrNull;
    final media = context.buildContext == null
        ? null
        : MediaQuery.maybeOf(context.buildContext!);
    final ratio = media?.devicePixelRatio ?? view?.devicePixelRatio;
    final size =
        media?.size ??
        (view == null ? null : view.physicalSize / view.devicePixelRatio);
    return {
      'platform': kIsWeb ? 'web' : Platform.operatingSystem,
      'osVersion': osVersion,
      'deviceModel': model,
      'brand': brand,
      'screenWidth': size?.width.round(),
      'screenHeight': size?.height.round(),
      'pixelRatio': ratio,
      'statusBarHeight': media?.padding.top.round(),
      'safeAreaBottom': media?.padding.bottom.round(),
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
  Future<dynamic> handle(
    Map<String, dynamic> payload,
    ActionContext context,
  ) async {
    final m = context.manifest;
    if (m == null) {
      throw BridgeError.invalidParams('Mini App manifest is unavailable');
    }
    return {
      'appId': context.appId,
      'name': m.name,
      'version': m.version,
      'category': m.category,
      'runtimeType': m.appRuntimeType,
      'description': m.description,
      'isAsset': m.isAsset,
      'status': m.status,
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
  Future<dynamic> handle(
    Map<String, dynamic> payload,
    ActionContext context,
  ) async {
    final level = await _battery.batteryLevel;
    final state = await _battery.batteryState;
    return {
      'level': level,
      'isCharging':
          state == BatteryState.charging || state == BatteryState.full,
      'status': state.name,
      'temperature': null,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }
}

class GetContactsHandler implements NativeActionHandler {
  final PermissionRepositoryImpl permissionRepo;
  final Future<bool> Function() requestAccess;
  final Future<List<Contact>> Function() readContacts;
  GetContactsHandler({
    required this.permissionRepo,
    Future<bool> Function()? requestAccess,
    Future<List<Contact>> Function()? readContacts,
  }) : requestAccess =
           requestAccess ??
           (() => FlutterContacts.requestPermission(readonly: true)),
       readContacts =
           readContacts ??
           (() => FlutterContacts.getContacts(withProperties: true));
  @override
  String get actionName => 'contact.getContacts';
  @override
  String? get requiredCapability => 'contacts';
  @override
  bool get requiresAuth => false;
  @override
  Future<dynamic> handle(
    Map<String, dynamic> payload,
    ActionContext context,
  ) async {
    if (!permissionRepo.isGranted(context.appId, 'contacts')) {
      throw BridgeError.permissionDenied('contacts');
    }
    if (!await requestAccess()) {
      throw BridgeError.permissionDenied('contacts');
    }
    final query = payload['query']?.toString().toLowerCase() ?? '';
    final entries = await readContacts();
    final contacts = entries
        .where(
          (c) =>
              query.isEmpty ||
              c.displayName.toLowerCase().contains(query) ||
              c.phones.any((p) => p.number.contains(query)) ||
              c.emails.any((e) => e.address.toLowerCase().contains(query)),
        )
        .map(
          (c) => {
            'id': c.id,
            'displayName': c.displayName,
            'phoneNumber': c.phones.firstOrNull?.number,
            'email': c.emails.firstOrNull?.address,
            'phoneNumbers': c.phones.map((p) => p.number).toList(),
            'emails': c.emails.map((e) => e.address).toList(),
            'department': c.organizations.firstOrNull?.department,
          },
        )
        .toList();
    return {'contacts': contacts, 'total': contacts.length};
  }
}
