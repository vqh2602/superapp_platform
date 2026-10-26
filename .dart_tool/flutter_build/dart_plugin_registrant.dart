//
// Generated file. Do not edit.
// This file is generated from template in file `flutter_tools/lib/src/flutter_plugins.dart`.
//

// @dart = 3.11

import 'dart:io'; // flutter_ignore: dart_io_import.
import 'package:webview_all_android/webview_all_android.dart' as webview_all_android;
import 'package:webview_all_wkwebview/webview_all_wkwebview.dart' as webview_all_wkwebview;
import 'package:webview_all_linux/webview_all_linux.dart' as webview_all_linux;
import 'package:webview_all_wkwebview/webview_all_wkwebview.dart' as webview_all_wkwebview;
import 'package:webview_all_windows/webview_all_windows.dart' as webview_all_windows;

@pragma('vm:entry-point')
class _PluginRegistrant {

  @pragma('vm:entry-point')
  static void register() {
    if (Platform.isAndroid) {
      try {
        webview_all_android.AndroidWebViewPlatform.registerWith();
      } catch (err) {
        print(
          '`webview_all_android` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

    } else if (Platform.isIOS) {
      try {
        webview_all_wkwebview.WebKitWebViewPlatform.registerWith();
      } catch (err) {
        print(
          '`webview_all_wkwebview` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

    } else if (Platform.isLinux) {
      try {
        webview_all_linux.LinuxWebViewPlatform.registerWith();
      } catch (err) {
        print(
          '`webview_all_linux` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

    } else if (Platform.isMacOS) {
      try {
        webview_all_wkwebview.WebKitWebViewPlatform.registerWith();
      } catch (err) {
        print(
          '`webview_all_wkwebview` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

    } else if (Platform.isWindows) {
      try {
        webview_all_windows.WindowsWebViewPlatform.registerWith();
      } catch (err) {
        print(
          '`webview_all_windows` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

    }
  }
}
