// Flutter web plugin registrant file.
//
// Generated file. Do not edit.
//

// @dart = 2.13
// ignore_for_file: type=lint

import 'package:battery_plus/src/battery_plus_web.dart';
import 'package:connectivity_plus/src/connectivity_plus_web.dart';
import 'package:device_info_plus/src/device_info_plus_web.dart';
import 'package:file_picker_web/file_picker_web.dart';
import 'package:flutter_secure_storage_web/flutter_secure_storage_web.dart';
import 'package:image_picker_for_web/image_picker_for_web.dart';
import 'package:mobile_scanner/src/web/mobile_scanner_web.dart';
import 'package:pointer_interceptor_web/pointer_interceptor_web.dart';
import 'package:speech_to_text/speech_to_text_web.dart';
import 'package:url_launcher_web/url_launcher_web.dart';
import 'package:webview_all_web/src/webview_all_web_plugin.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

void registerPlugins([final Registrar? pluginRegistrar]) {
  final Registrar registrar = pluginRegistrar ?? webPluginRegistrar;
  BatteryPlusWebPlugin.registerWith(registrar);
  ConnectivityPlusWebPlugin.registerWith(registrar);
  DeviceInfoPlusWebPlugin.registerWith(registrar);
  FilePickerWeb.registerWith(registrar);
  FlutterSecureStorageWeb.registerWith(registrar);
  ImagePickerPlugin.registerWith(registrar);
  MobileScannerWeb.registerWith(registrar);
  PointerInterceptorWeb.registerWith(registrar);
  SpeechToTextPlugin.registerWith(registrar);
  UrlLauncherPlugin.registerWith(registrar);
  WebviewAllWebPlugin.registerWith(registrar);
  registrar.registerMessageHandler();
}
