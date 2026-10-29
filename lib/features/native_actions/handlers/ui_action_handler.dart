import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';
import '../../../../core/errors/bridge_error.dart';
import '../domain/action_definition.dart';
import '../domain/action_context.dart';

class ShowToastHandler implements NativeActionHandler {
  @override
  String get actionName => 'ui.showToast';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    final message = payload['message']?.toString();
    if (message == null || message.isEmpty) {
      throw BridgeError.invalidParams('Toast message is required');
    }

    final durationMs = (payload['duration'] as num?)?.toInt() ?? 2000;

    if (context.buildContext != null) {
      ScaffoldMessenger.of(context.buildContext!).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: Duration(milliseconds: durationMs),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: const Color(0xFF1E293B),
        ),
      );
    }

    return {
      'success': true,
      'message': message,
      'durationMs': durationMs,
    };
  }
}

class ShowAlertHandler implements NativeActionHandler {
  @override
  String get actionName => 'ui.showAlert';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    final title = payload['title']?.toString() ?? 'Thông báo';
    final message = payload['message']?.toString() ?? '';
    final buttonText = payload['buttonText']?.toString() ?? 'Đóng';

    if (context.buildContext != null) {
      await showDialog(
        context: context.buildContext!,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(buttonText),
            ),
          ],
        ),
      );
    }

    return {'success': true};
  }
}

class ShowConfirmHandler implements NativeActionHandler {
  @override
  String get actionName => 'ui.showConfirm';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    final title = payload['title']?.toString() ?? 'Xác nhận';
    final message = payload['message']?.toString() ?? '';
    final confirmText = payload['confirmText']?.toString() ?? 'Xác nhận';
    final cancelText = payload['cancelText']?.toString() ?? 'Huỷ';

    var confirmed = false;
    if (context.buildContext != null) {
      confirmed = await showDialog<bool>(
            context: context.buildContext!,
            builder: (ctx) => AlertDialog(
              title: Text(title),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(cancelText),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(confirmText),
                ),
              ],
            ),
          ) ??
          false;
    }

    return {'confirmed': confirmed};
  }
}

class SetNavigationBarTitleHandler implements NativeActionHandler {
  @override
  String get actionName => 'ui.setNavigationBarTitle';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    final title = payload['title']?.toString() ?? '';
    return {
      'success': true,
      'title': title,
    };
  }
}

class VibrateHandler implements NativeActionHandler {
  @override
  String get actionName => 'device.vibrate';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    final style = payload['style']?.toString() ?? 'medium';
    if (style == 'heavy') {
      await HapticFeedback.heavyImpact();
    } else if (style == 'light') {
      await HapticFeedback.lightImpact();
    } else {
      await HapticFeedback.mediumImpact();
    }

    return {
      'success': true,
      'style': style,
    };
  }
}

class CopyToClipboardHandler implements NativeActionHandler {
  @override
  String get actionName => 'device.copyToClipboard';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    final text = payload['text']?.toString();
    if (text == null) {
      throw BridgeError.invalidParams('Text is required to copy to clipboard');
    }

    await Clipboard.setData(ClipboardData(text: text));

    return {
      'success': true,
      'length': text.length,
    };
  }
}

class SetBrightnessHandler implements NativeActionHandler {
  @override
  String get actionName => 'device.setBrightness';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    final rawBrightness = payload['brightness'];
    if (rawBrightness == null) {
      throw BridgeError.invalidParams('brightness (0.0 to 1.0) is required');
    }

    final brightness = (rawBrightness as num).toDouble().clamp(0.0, 1.0);

    try {
      await ScreenBrightness.instance.setApplicationScreenBrightness(brightness);
    } catch (_) {
      try {
        await ScreenBrightness.instance.setSystemScreenBrightness(brightness);
      } catch (_) {}
    }

    return {
      'success': true,
      'brightness': brightness,
    };
  }
}

class SetStatusBarStyleHandler implements NativeActionHandler {
  @override
  String get actionName => 'ui.setStatusBarStyle';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    final style = payload['style']?.toString().toLowerCase() ?? 'light';
    final isDarkIcon = style == 'dark';

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarIconBrightness: isDarkIcon ? Brightness.dark : Brightness.light,
        statusBarBrightness: isDarkIcon ? Brightness.light : Brightness.dark,
      ),
    );

    return {
      'success': true,
      'style': style,
    };
  }
}

class SetStatusBarColorHandler implements NativeActionHandler {
  @override
  String get actionName => 'ui.setStatusBarColor';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    final colorHex = payload['color']?.toString() ?? '#FFFFFF';
    Color color = Colors.white;

    try {
      final hex = colorHex.replaceFirst('#', '');
      color = Color(int.parse(hex.length == 6 ? 'FF$hex' : hex, radix: 16));
    } catch (_) {}

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: color,
      ),
    );

    return {
      'success': true,
      'color': colorHex,
    };
  }
}

class SetNavigationBarColorHandler implements NativeActionHandler {
  @override
  String get actionName => 'ui.setNavigationBarColor';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    final colorHex = payload['color']?.toString() ?? '#000000';
    Color color = Colors.black;

    try {
      final hex = colorHex.replaceFirst('#', '');
      color = Color(int.parse(hex.length == 6 ? 'FF$hex' : hex, radix: 16));
    } catch (_) {}

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        systemNavigationBarColor: color,
      ),
    );

    return {
      'success': true,
      'color': colorHex,
    };
  }
}

class ConfigAppViewHandler implements NativeActionHandler {
  @override
  String get actionName => 'ui.configAppView';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    final hideStatusBar = payload['hideStatusBar'] == true;
    final hideNavBar = payload['hideNavigationBar'] == true;

    final overlays = <SystemUiOverlay>[];
    if (!hideStatusBar) overlays.add(SystemUiOverlay.top);
    if (!hideNavBar) overlays.add(SystemUiOverlay.bottom);

    await SystemChrome.setEnabledSystemUIMode(
      overlays.isEmpty ? SystemUiMode.immersiveSticky : SystemUiMode.manual,
      overlays: overlays,
    );

    return {
      'success': true,
      'hideStatusBar': hideStatusBar,
      'hideNavigationBar': hideNavBar,
    };
  }
}

class ShowMiniappMenuHandler implements NativeActionHandler {
  final VoidCallback? onCloseApp;

  ShowMiniappMenuHandler({this.onCloseApp});

  @override
  String get actionName => 'ui.showMiniappMenu';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    if (context.buildContext != null) {
      showModalBottomSheet(
        context: context.buildContext!,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.manifest?.name ?? 'SuperApp Mini App',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.refresh, color: Colors.blue),
                    title: const Text('Khởi động lại Mini App'),
                    onTap: () => Navigator.pop(ctx),
                  ),
                  ListTile(
                    leading: const Icon(Icons.security, color: Colors.green),
                    title: const Text('Cài đặt quyền riêng tư'),
                    onTap: () => Navigator.pop(ctx),
                  ),
                  ListTile(
                    leading: const Icon(Icons.share, color: Colors.amber),
                    title: const Text('Chia sẻ Mini App'),
                    onTap: () => Navigator.pop(ctx),
                  ),
                  ListTile(
                    leading: const Icon(Icons.exit_to_app, color: Colors.red),
                    title: const Text('Đóng ứng dụng'),
                    onTap: () {
                      Navigator.pop(ctx);
                      onCloseApp?.call();
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return {
      'success': true,
      'action': 'MENU_DISPLAYED',
    };
  }
}

class CloseAppHandler implements NativeActionHandler {
  final VoidCallback? onCloseApp;

  CloseAppHandler({this.onCloseApp});

  @override
  String get actionName => 'navigation.closeApp';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    if (context.buildContext != null) {
      if (Navigator.of(context.buildContext!).canPop()) {
        Navigator.of(context.buildContext!).pop();
      }
    }
    onCloseApp?.call();
    return {
      'success': true,
      'message': 'Đã đóng Mini App',
    };
  }
}
