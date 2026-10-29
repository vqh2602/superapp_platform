import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../../core/errors/bridge_error.dart';
import '../../permissions/data/mock_permission_repository.dart';
import '../../permissions/presentation/permission_prompt_dialog.dart';
import '../domain/action_definition.dart';
import '../domain/action_context.dart';

Color? _tryParseHex(String? hexString) {
  if (hexString == null || hexString.isEmpty) return null;
  try {
    final hex = hexString.replaceAll('#', '').trim();
    if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    } else if (hex.length == 8) {
      return Color(int.parse(hex, radix: 16));
    } else if (hex.length == 3) {
      return Color(int.parse('FF${hex[0]}${hex[0]}${hex[1]}${hex[1]}${hex[2]}${hex[2]}', radix: 16));
    }
  } catch (_) {}
  return null;
}

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
    // Dynamically update runtime Top Navigation Bar title
    context.uiDelegate?.setTitle(title);

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
    final colorHex = payload['color']?.toString() ?? '#FFFFFF';
    final textColor = payload['textColor']?.toString().toLowerCase(); // 'white' | 'black'
    final statusBarColorHex = payload['statusBarColor']?.toString();

    final navColor = _tryParseHex(colorHex) ?? Colors.white;
    final statusBarColor = _tryParseHex(statusBarColorHex);

    // 1. Update runtime top header UI & status bar in MiniAppRuntimeScreen
    context.uiDelegate?.setNavigationBarColor(
      color: navColor,
      textColor: textColor,
      statusBarColor: statusBarColor,
    );

    // 2. Update System UI overlay style
    final isWhiteText = textColor == 'white';
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        systemNavigationBarColor: navColor,
        statusBarColor: statusBarColor ?? Colors.transparent,
        statusBarIconBrightness: isWhiteText ? Brightness.light : Brightness.dark,
        statusBarBrightness: isWhiteText ? Brightness.dark : Brightness.light,
      ),
    );

    return {
      'success': true,
      'color': colorHex,
      'textColor': textColor ?? 'black',
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
    // 1. Parse flat and nested configuration parameters
    final headerColorHex = payload['headerColor']?.toString() ??
        (payload['header'] is Map ? payload['header']['color']?.toString() : null);
    final headerTitle = payload['headerTitle']?.toString() ??
        (payload['header'] is Map ? payload['header']['title']?.toString() : null);
    final textColor = payload['textColor']?.toString().toLowerCase() ??
        (payload['header'] is Map ? payload['header']['textColor']?.toString().toLowerCase() : null);

    final statusBarRaw = payload['statusBar'];
    final statusBarMode = statusBarRaw is String
        ? statusBarRaw
        : (statusBarRaw is Map ? statusBarRaw['style']?.toString() : null);

    final actionBarHidden = payload['actionBarHidden'] == true ||
        (payload['header'] is Map &&
            (payload['header']['hidden'] == true || payload['header']['hide'] == true));

    final hideBottomNav = payload['hideAndroidBottomNavigationBar'] == true ||
        payload['hideNavigationBar'] == true ||
        (payload['bottomNav'] is Map &&
            (payload['bottomNav']['hidden'] == true || payload['bottomNav']['hide'] == true));

    final hasPadding = payload['hasPadding'] != false;

    final bottomNavColorHex = payload['bottomNavColor']?.toString() ??
        (payload['bottomNav'] is Map ? payload['bottomNav']['color']?.toString() : null);

    final isStatusBarHidden = statusBarMode == 'hidden' || payload['hideStatusBar'] == true;

    final headerColor = _tryParseHex(headerColorHex);
    final bottomNavColor = _tryParseHex(bottomNavColorHex);

    // 2. Inform runtime UI delegate
    context.uiDelegate?.configAppView(
      headerColor: headerColor,
      headerTitle: headerTitle,
      textColor: textColor,
      statusBar: statusBarMode,
      actionBarHidden: actionBarHidden,
      hideAndroidBottomNavigationBar: hideBottomNav,
      hasPadding: hasPadding,
      bottomNavColor: bottomNavColor,
    );

    // 3. SystemChrome overlay handling
    final overlays = <SystemUiOverlay>[];
    if (!isStatusBarHidden) overlays.add(SystemUiOverlay.top);
    if (!hideBottomNav) overlays.add(SystemUiOverlay.bottom);

    await SystemChrome.setEnabledSystemUIMode(
      overlays.isEmpty ? SystemUiMode.immersiveSticky : SystemUiMode.manual,
      overlays: overlays,
    );

    final isWhiteText = textColor == 'white';
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: statusBarMode == 'transparent'
            ? Colors.transparent
            : (headerColor ?? Colors.transparent),
        statusBarIconBrightness: isWhiteText ? Brightness.light : Brightness.dark,
        statusBarBrightness: isWhiteText ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: bottomNavColor,
      ),
    );

    return {
      'success': true,
      'actionBarHidden': actionBarHidden,
      'statusBar': statusBarMode ?? (isStatusBarHidden ? 'hidden' : 'transparent'),
      'hideAndroidBottomNavigationBar': hideBottomNav,
      'hasPadding': hasPadding,
      if (headerColorHex != null) 'headerColor': headerColorHex,
      if (headerTitle != null) 'headerTitle': headerTitle,
      if (textColor != null) 'textColor': textColor,
    };
  }
}

class KeepScreenHandler implements NativeActionHandler {
  @override
  String get actionName => 'device.keepScreen';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    bool keepScreenOn = true;
    if (payload.containsKey('keepScreenOn')) {
      keepScreenOn = payload['keepScreenOn'] == true;
    } else if (payload.containsKey('keepScreen')) {
      keepScreenOn = payload['keepScreen'] == true;
    } else if (payload.containsKey('on')) {
      keepScreenOn = payload['on'] == true;
    }

    try {
      if (keepScreenOn) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (e) {
      debugPrint('[KeepScreenHandler] WakelockPlatform notice: $e');
    }

    context.uiDelegate?.keepScreen(keepScreenOn: keepScreenOn);

    return {
      'success': true,
      'keepScreenOn': keepScreenOn,
    };
  }
}

class RequestSendNotificationHandler implements NativeActionHandler {
  final MockPermissionRepository permissionRepo;

  RequestSendNotificationHandler({required this.permissionRepo});

  @override
  String get actionName => 'ui.requestSendNotification';

  @override
  String? get requiredCapability => null; // Self-prompts with user dialog

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    final templateId = payload['templateId']?.toString();
    final reason = payload['reason']?.toString();

    // 1. Check if already granted
    final isAlreadyGranted = permissionRepo.isGranted(context.appId, 'notification');
    if (isAlreadyGranted) {
      final subId = 'sub_${context.appId}_${DateTime.now().millisecondsSinceEpoch}';
      final token = 'notif_tok_${context.appId}_${DateTime.now().microsecondsSinceEpoch}';
      return {
        'success': true,
        'granted': true,
        'subscriptionId': subId,
        'token': token,
        if (templateId != null) 'templateId': templateId,
      };
    }

    // 2. Prompt user via UI
    var granted = false;
    if (context.buildContext != null) {
      granted = await PermissionPromptDialog.show(
        context.buildContext!,
        appName: context.manifest?.name ?? context.appId,
        capabilityKey: 'notification',
      );
    } else {
      // In headless unit-test mode or when auto-approved
      granted = true;
    }

    permissionRepo.setPermission(context.appId, 'notification', granted);

    if (granted) {
      final subId = 'sub_${context.appId}_${DateTime.now().millisecondsSinceEpoch}';
      final token = 'notif_tok_${context.appId}_${DateTime.now().microsecondsSinceEpoch}';
      return {
        'success': true,
        'granted': true,
        'subscriptionId': subId,
        'token': token,
        if (templateId != null) 'templateId': templateId,
        if (reason != null) 'reason': reason,
      };
    } else {
      return {
        'success': false,
        'granted': false,
        'error': 'USER_REJECTED',
        'message': 'Người dùng từ chối cấp quyền gửi thông báo',
      };
    }
  }
}

class MinimizeAppHandler implements NativeActionHandler {
  final VoidCallback? onMinimizeApp;

  MinimizeAppHandler({this.onMinimizeApp});

  @override
  String get actionName => 'navigation.minimizeApp';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    // 1. Inform MiniAppUiDelegate
    context.uiDelegate?.minimizeApp();

    // 2. Trigger fallback callback or Navigator pop
    onMinimizeApp?.call();
    if (context.buildContext != null && Navigator.canPop(context.buildContext!)) {
      Navigator.pop(context.buildContext!);
    }

    return {
      'success': true,
      'status': 'minimized',
      'appId': context.appId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
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
